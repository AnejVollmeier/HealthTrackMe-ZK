package com.healthwithme.api.service

import com.healthwithme.api.model.DoseLog
import com.healthwithme.api.model.DoseStatus
import com.healthwithme.api.model.Medicine
import com.healthwithme.api.repository.DoseLogRepository
import com.healthwithme.api.repository.MedicineRepository
import com.healthwithme.api.repository.UserRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertAll
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.EnumSource
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.CALLS_REAL_METHODS
import org.mockito.Mockito.never
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.mockito.Mockito.verifyNoMoreInteractions
import org.mockito.Mockito.`when`
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.Optional

class MedicineServiceTest {
    private val medicineRepository = mock(MedicineRepository::class.java)
    private val doseLogRepository = mock(DoseLogRepository::class.java)
    private val userRepository = mock(UserRepository::class.java)
    private val service = MedicineService(medicineRepository, userRepository, doseLogRepository)
    private val now = LocalDateTime.of(2026, 10, 18, 12, 0)
    private val medicine = Medicine(id = 10L, name = "Test medicine", createdAt = now, updatedAt = now)

    @Test
    fun `getAdherence with all taken doses returns one hundred percent`() {
        assertAdherence(listOf(dose(DoseStatus.TAKEN), dose(DoseStatus.TAKEN)), 100.0, 2, 0)
    }

    @Test
    fun `getAdherence with all missed doses returns zero percent`() {
        assertAdherence(listOf(dose(DoseStatus.MISSED), dose(DoseStatus.MISSED)), 0.0, 0, 2)
    }

    @Test
    fun `getAdherence with one taken and one missed returns fifty percent`() {
        assertAdherence(listOf(dose(DoseStatus.TAKEN), dose(DoseStatus.MISSED)), 50.0, 1, 1)
    }

    @Test
    fun `getAdherence with skipped dose excludes it from the denominator`() {
        assertAdherence(
            listOf(dose(DoseStatus.TAKEN), dose(DoseStatus.MISSED), dose(DoseStatus.SKIPPED)),
            50.0, 1, 1
        )
    }

    @Test
    fun `getAdherence with scheduled dose excludes it from the denominator`() {
        assertAdherence(
            listOf(dose(DoseStatus.TAKEN), dose(DoseStatus.MISSED), dose(DoseStatus.SCHEDULED)),
            50.0, 1, 1
        )
    }

    @Test
    fun `getAdherence without logs returns zero counts and empty breakdown`() {
        val result = assertAdherence(emptyList(), 0.0, 0, 0)
        assertThat(result["dailyBreakdown"]).isEqualTo(emptyList<Map<String, String>>())
    }

    @Test
    fun `getAdherence without relevant doses returns zero instead of dividing by zero`() {
        assertAdherence(listOf(dose(DoseStatus.SKIPPED), dose(DoseStatus.SCHEDULED)), 0.0, 0, 0)
    }

    @Test
    fun `getAdherence with period excludes older logs and exact cutoff but includes newer logs`() {
        existingMedicine()
        val cutoff = now.minusDays(7)
        `when`(doseLogRepository.findByMedicineIdOrderByScheduledTimeDesc(10L)).thenReturn(
            listOf(
                dose(DoseStatus.MISSED, cutoff.minusSeconds(1)),
                dose(DoseStatus.MISSED, cutoff),
                dose(DoseStatus.TAKEN, cutoff.plusSeconds(1))
            )
        )

        val result = withFixedTime { service.getAdherence(10L, 7) }

        assertTotals(result, 100.0, 1, 0)
        assertThat(result["dailyBreakdown"]).isEqualTo(
            listOf(mapOf("date" to "2026-10-11", "status" to "TAKEN"))
        )
    }

    @Test
    fun `getAdherence without period includes historical logs`() {
        assertAdherence(
            listOf(dose(DoseStatus.TAKEN), dose(DoseStatus.MISSED, now.minusYears(2))),
            50.0, 1, 1
        )
    }

    @Test
    fun `getAdherence with multiple statuses per day returns one daily status by priority`() {
        existingMedicine()
        `when`(doseLogRepository.findByMedicineIdOrderByScheduledTimeDesc(10L)).thenReturn(
            listOf(
                dose(DoseStatus.SCHEDULED), dose(DoseStatus.SKIPPED),
                dose(DoseStatus.MISSED), dose(DoseStatus.TAKEN),
                dose(DoseStatus.SKIPPED, now.minusDays(1)),
                dose(DoseStatus.MISSED, now.minusDays(1)),
                dose(DoseStatus.SCHEDULED, now.minusDays(2)),
                dose(DoseStatus.SKIPPED, now.minusDays(2)),
                dose(DoseStatus.SCHEDULED, now.minusDays(3))
            )
        )
        val result = service.getAdherence(10L, null)
        assertAll(
            { assertTotals(result, 100.0 / 3.0, 1, 2) },
            {
                assertThat(result["dailyBreakdown"]).isEqualTo(
                    listOf(
                        mapOf("date" to "2026-10-18", "status" to "TAKEN"),
                        mapOf("date" to "2026-10-17", "status" to "MISSED"),
                        mapOf("date" to "2026-10-16", "status" to "SKIPPED"),
                        mapOf("date" to "2026-10-15", "status" to "SCHEDULED")
                    )
                )
            }
        )
    }

    @Test
    fun `getAdherence for nonexistent medicine throws without changing data`() {
        missingMedicine()
        assertThatThrownBy { service.getAdherence(10L, null) }
            .isInstanceOf(IllegalArgumentException::class.java).hasMessage("Medicine not found")
        assertOnlyMedicineLookup()
    }

    @Test
    fun `logDose with taken status saves the supplied time as taken time`() {
        assertLoggedDose("TAKEN", DoseStatus.TAKEN, now)
    }

    @Test
    fun `logDose with missed status saves no taken time`() {
        assertLoggedDose("MISSED", DoseStatus.MISSED, null)
    }

    @Test
    fun `logDose with skipped status preserves status and saves no taken time`() {
        assertLoggedDose("SKIPPED", DoseStatus.SKIPPED, null)
    }

    @Test
    fun `logDose with scheduled status preserves status and saves no taken time`() {
        assertLoggedDose("SCHEDULED", DoseStatus.SCHEDULED, null)
    }

    @Test
    fun `logDose with invalid status falls back to scheduled without taken time`() {
        assertLoggedDose("INVALID", DoseStatus.SCHEDULED, null)
    }

    @Test
    fun `logDose for nonexistent medicine throws without changing data`() {
        missingMedicine()
        assertThatThrownBy { service.logDose(10L, now.toLocalDate(), now.toLocalTime(), "TAKEN") }
            .isInstanceOf(IllegalArgumentException::class.java).hasMessage("Medicine not found")
        assertOnlyMedicineLookup()
    }

    @Test
    fun `logDose returns updated adherence and daily priority after saving`() {
        existingMedicine()
        val logs = mutableListOf(dose(DoseStatus.MISSED))
        `when`(doseLogRepository.save(org.mockito.ArgumentMatchers.any(DoseLog::class.java)))
            .thenAnswer { invocation -> invocation.getArgument<DoseLog>(0).also { logs.add(it) } }
        `when`(doseLogRepository.findByMedicineId(10L)).thenAnswer { logs.toList() }

        val result = service.logDose(10L, now.toLocalDate(), now.toLocalTime(), "TAKEN")

        assertTotals(result, 50.0, 1, 1)
        assertThat(result["dailyBreakdown"]).isEqualTo(
            listOf(mapOf("date" to "2026-10-18", "status" to "TAKEN"))
        )
    }

    @ParameterizedTest
    @EnumSource(value = DoseStatus::class, names = ["SKIPPED", "SCHEDULED"])
    fun `logDose with irrelevant status preserves fifty percent adherence after saving`(status: DoseStatus) {
        existingMedicine()
        val logs = mutableListOf(dose(DoseStatus.TAKEN), dose(DoseStatus.MISSED))
        `when`(doseLogRepository.save(org.mockito.ArgumentMatchers.any(DoseLog::class.java)))
            .thenAnswer { invocation -> invocation.getArgument<DoseLog>(0).also { logs.add(it) } }
        `when`(doseLogRepository.findByMedicineId(10L)).thenAnswer { logs.toList() }

        val result = service.logDose(10L, now.toLocalDate(), now.toLocalTime(), status.name)

        assertAll(
            { assertTotals(result, 50.0, 1, 1) },
            { assertThat(result["dailyBreakdown"]).isEqualTo(
                listOf(mapOf("date" to "2026-10-18", "status" to "TAKEN"))
            ) }
        )
        val captor = ArgumentCaptor.forClass(DoseLog::class.java)
        verify(doseLogRepository).save(captor.capture())
        assertThat(captor.value.status).isEqualTo(status)
    }

    @Test
    fun `undoLatestDoseToday with taken doses deletes only newest and returns refreshed adherence`() {
        existingMedicine()
        val newest = dose(DoseStatus.TAKEN, now.minusHours(1), 2L)
        val older = dose(DoseStatus.TAKEN, now.minusHours(3), 1L)
        val remaining = mutableListOf(newest, older, dose(DoseStatus.MISSED, now.minusHours(4), 3L))
        `when`(doseLogRepository.findByMedicineIdAndStatusBetween(
            10L, DoseStatus.TAKEN, now.toLocalDate().atStartOfDay(), now.toLocalDate().plusDays(1).atStartOfDay()
        )).thenReturn(listOf(newest, older))
        org.mockito.Mockito.doAnswer { remaining.remove(newest); null }
            .`when`(doseLogRepository).delete(newest)
        `when`(doseLogRepository.findByMedicineIdOrderByScheduledTimeDesc(10L))
            .thenAnswer { remaining.toList() }

        val result = withFixedTime { service.undoLatestDoseToday(10L) }

        assertTotals(result, 50.0, 1, 1)
        assertThat(result["dailyBreakdown"]).isEqualTo(
            listOf(mapOf("date" to "2026-10-18", "status" to "TAKEN"))
        )
        verify(doseLogRepository).findByMedicineIdAndStatusBetween(
            10L, DoseStatus.TAKEN, now.toLocalDate().atStartOfDay(), now.toLocalDate().plusDays(1).atStartOfDay()
        )
        val deleted = ArgumentCaptor.forClass(DoseLog::class.java)
        verify(doseLogRepository).delete(deleted.capture())
        assertThat(deleted.value).isEqualTo(newest)
        verify(doseLogRepository, never()).save(org.mockito.ArgumentMatchers.any(DoseLog::class.java))
    }

    @Test
    fun `undoLatestDoseToday with only dose returns zero adherence and empty breakdown after deletion`() {
        existingMedicine()
        val onlyDose = dose(DoseStatus.TAKEN, now.minusHours(1), 1L)
        val remaining = mutableListOf(onlyDose)
        val start = now.toLocalDate().atStartOfDay()
        `when`(doseLogRepository.findByMedicineIdAndStatusBetween(10L, DoseStatus.TAKEN, start, start.plusDays(1)))
            .thenReturn(listOf(onlyDose))
        org.mockito.Mockito.doAnswer { remaining.remove(onlyDose); null }
            .`when`(doseLogRepository).delete(onlyDose)
        `when`(doseLogRepository.findByMedicineIdOrderByScheduledTimeDesc(10L))
            .thenAnswer { remaining.toList() }

        val result = withFixedTime { service.undoLatestDoseToday(10L) }

        assertAll(
            { assertTotals(result, 0.0, 0, 0) },
            { assertThat(result["dailyBreakdown"]).isEqualTo(emptyList<Map<String, String>>()) },
            { verify(doseLogRepository).delete(onlyDose) },
            { verify(doseLogRepository, never()).save(org.mockito.ArgumentMatchers.any(DoseLog::class.java)) }
        )
    }

    @Test
    fun `undoLatestDoseToday without taken dose today throws without changing data`() {
        existingMedicine()
        val start = now.toLocalDate().atStartOfDay()
        `when`(doseLogRepository.findByMedicineIdAndStatusBetween(10L, DoseStatus.TAKEN, start, start.plusDays(1)))
            .thenReturn(emptyList())

        assertThatThrownBy { withFixedTime { service.undoLatestDoseToday(10L) } }
            .isInstanceOf(IllegalStateException::class.java).hasMessage("No dose taken today to undo")

        verify(doseLogRepository).findByMedicineIdAndStatusBetween(10L, DoseStatus.TAKEN, start, start.plusDays(1))
        verifyNoMoreInteractions(doseLogRepository)
        verify(medicineRepository).findById(10L)
        verifyNoMoreInteractions(medicineRepository)
        verifyNoInteractions(userRepository)
    }

    @Test
    fun `undoLatestDoseToday for nonexistent medicine throws without changing data`() {
        missingMedicine()
        assertThatThrownBy { service.undoLatestDoseToday(10L) }
            .isInstanceOf(IllegalArgumentException::class.java).hasMessage("Medicine not found")
        assertOnlyMedicineLookup()
    }

    private fun existingMedicine() {
        `when`(medicineRepository.findById(10L)).thenReturn(Optional.of(medicine))
    }

    private fun missingMedicine() {
        `when`(medicineRepository.findById(10L)).thenReturn(Optional.empty())
    }

    private fun dose(status: DoseStatus, scheduled: LocalDateTime = now, id: Long = 0L) = DoseLog(
        id = id, medicine = medicine, scheduledTime = scheduled,
        takenTime = if (status == DoseStatus.TAKEN) scheduled else null, status = status
    )

    private fun assertAdherence(logs: List<DoseLog>, percentage: Double, taken: Int, missed: Int): Map<String, Any> {
        existingMedicine()
        `when`(doseLogRepository.findByMedicineIdOrderByScheduledTimeDesc(10L)).thenReturn(logs)
        val result = service.getAdherence(10L, null)
        assertTotals(result, percentage, taken, missed)
        return result
    }

    private fun assertTotals(result: Map<String, Any>, percentage: Double, taken: Int, missed: Int) {
        assertThat(result["percentage"] as Double).isCloseTo(percentage, org.assertj.core.data.Offset.offset(0.000001))
        assertThat(result["takenCount"]).isEqualTo(taken)
        assertThat(result["missedCount"]).isEqualTo(missed)
    }

    private fun assertLoggedDose(rawStatus: String, status: DoseStatus, takenTime: LocalDateTime?) {
        existingMedicine()
        `when`(doseLogRepository.findByMedicineId(10L)).thenReturn(emptyList())

        service.logDose(10L, now.toLocalDate(), now.toLocalTime(), rawStatus)

        val captor = ArgumentCaptor.forClass(DoseLog::class.java)
        verify(doseLogRepository).save(captor.capture())
        assertThat(captor.value.medicine).isEqualTo(medicine)
        assertThat(captor.value.scheduledTime).isEqualTo(now)
        assertThat(captor.value.status).isEqualTo(status)
        assertThat(captor.value.takenTime).isEqualTo(takenTime)
    }

    private fun assertOnlyMedicineLookup() {
        verify(medicineRepository).findById(10L)
        verifyNoMoreInteractions(medicineRepository)
        verifyNoInteractions(doseLogRepository, userRepository)
    }

    private fun <T> withFixedTime(action: () -> T): T {
        val today = now.toLocalDate()
        // Scoped static mocks freeze only now(); other date/time operations remain real.
        return mockStatic(LocalDateTime::class.java, CALLS_REAL_METHODS).use { dateTimeMock ->
            dateTimeMock.`when`<LocalDateTime> { LocalDateTime.now() }.thenReturn(now)
            mockStatic(LocalDate::class.java, CALLS_REAL_METHODS).use { dateMock ->
                dateMock.`when`<LocalDate> { LocalDate.now() }.thenReturn(today)
                action()
            }
        }
    }
}
