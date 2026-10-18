package com.healthwithme.api.service

import com.healthwithme.api.dto.HealthShieldResponseDto
import com.healthwithme.api.model.Friendship
import com.healthwithme.api.model.FriendshipStatus
import com.healthwithme.api.model.HealthEntry
import com.healthwithme.api.model.User
import com.healthwithme.api.repository.FriendshipRepository
import com.healthwithme.api.repository.HealthEntryRepository
import com.healthwithme.api.repository.UserRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowable
import org.junit.jupiter.api.Assertions.assertAll
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource
import org.junit.jupiter.params.provider.ValueSource
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.CALLS_REAL_METHODS
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.mockito.Mockito.`when`
import java.time.LocalDate
import java.util.Optional

class FriendshipServiceTest {
    private val friendshipRepository = mock(FriendshipRepository::class.java)
    private val userRepository = mock(UserRepository::class.java)
    private val healthEntryRepository = mock(HealthEntryRepository::class.java)
    private val healthShieldService = mock(HealthShieldService::class.java)
    private val service = FriendshipService(
        friendshipRepository, userRepository, healthEntryRepository, healthShieldService
    )
    private val today = LocalDate.of(2026, 10, 18)
    private val timestamp = today.atTime(12, 0)
    private val ana = User(id = 1L, email = "ana@example.com", firstName = "Ana", lastName = "Novak")
    private val bor = User(id = 2L, email = "bor@example.com", firstName = "Bor", lastName = "Kovac")

    @Test
    fun `sendRequest to another user saves pending request and returns outgoing friend`() {
        prepareRequestUsers()
        saveReturnsFriendship(newId = 20L)

        val result = service.sendRequest(ana.id, bor.email)

        val saved = capturedSave()
        assertThat(saved.requester).isEqualTo(ana)
        assertThat(saved.addressee).isEqualTo(bor)
        assertThat(saved.status).isEqualTo(FriendshipStatus.PENDING)
        assertThat(result.friendshipId).isEqualTo(20L)
        assertThat(result.userId).isEqualTo(bor.id)
        assertThat(result.email).isEqualTo(bor.email)
        assertThat(result.name).isEqualTo("Bor Kovac")
        assertThat(result.status).isEqualTo("PENDING")
        assertThat(result.direction).isEqualTo("OUTGOING")
    }

    @Test
    fun `sendRequest with mixed case and whitespace normalizes email before lookup`() {
        prepareRequestUsers()
        saveReturnsFriendship(newId = 20L)

        val result = service.sendRequest(ana.id, "  BOR@EXAMPLE.COM  ")

        verify(userRepository).findByEmail("bor@example.com")
        assertThat(capturedSave().addressee).isEqualTo(bor)
        assertThat(result.email).isEqualTo("bor@example.com")
    }

    @ParameterizedTest
    @ValueSource(strings = ["", "   ", "\t\n"])
    fun `sendRequest with blank email throws without changing data`(email: String) {
        val error = catchThrowable { service.sendRequest(ana.id, email) }
        assertAll(
            { assertThat(error).isInstanceOf(IllegalArgumentException::class.java).hasMessage("Email is required") },
            { verifyNoInteractions(userRepository, friendshipRepository, healthEntryRepository, healthShieldService) }
        )
    }

    @Test
    fun `sendRequest with unknown email throws without saving`() {
        `when`(userRepository.findById(ana.id)).thenReturn(Optional.of(ana))
        `when`(userRepository.findByEmail(bor.email)).thenReturn(Optional.empty())

        assertRejectedWithoutChanges("No user with that email") { service.sendRequest(ana.id, bor.email) }
    }

    @Test
    fun `sendRequest with nonexistent requester throws without saving`() {
        `when`(userRepository.findById(ana.id)).thenReturn(Optional.empty())

        assertRejectedWithoutChanges("User not found") { service.sendRequest(ana.id, bor.email) }
    }

    @Test
    fun `sendRequest to self throws without saving`() {
        `when`(userRepository.findById(ana.id)).thenReturn(Optional.of(ana))
        `when`(userRepository.findByEmail(ana.email)).thenReturn(Optional.of(ana))

        assertRejectedWithoutChanges("You can't add yourself") { service.sendRequest(ana.id, ana.email) }
    }

    @ParameterizedTest
    @CsvSource(
        "PENDING, false, A request is already pending",
        "PENDING, true, A request is already pending",
        "ACCEPTED, false, You're already friends",
        "ACCEPTED, true, You're already friends"
    )
    fun `sendRequest with existing active relationship in either direction rejects duplicate`(
        status: FriendshipStatus, reversed: Boolean, message: String
    ) {
        prepareRequestUsers()
        stubExistingRequest(friendship(status, reversed))

        assertRejectedWithoutChanges(message) { service.sendRequest(ana.id, bor.email) }
    }

    @ParameterizedTest
    @ValueSource(booleans = [false, true])
    fun `sendRequest with declined relationship in either direction revives same request as pending`(reversed: Boolean) {
        prepareRequestUsers()
        val declined = friendship(FriendshipStatus.DECLINED, reversed).copy(id = 47L)
        stubExistingRequest(declined)
        saveReturnsFriendship()

        val result = service.sendRequest(ana.id, bor.email)

        val saved = capturedSave()
        assertThat(saved.id).isEqualTo(declined.id)
        assertThat(saved.createdAt).isEqualTo(declined.createdAt)
        assertThat(saved.requester).isEqualTo(ana)
        assertThat(saved.addressee).isEqualTo(bor)
        assertThat(saved.status).isEqualTo(FriendshipStatus.PENDING)
        assertThat(result.userId).isEqualTo(bor.id)
        assertThat(result.status).isEqualTo("PENDING")
        assertThat(result.direction).isEqualTo("OUTGOING")
        assertThat(result.friendshipId).isEqualTo(47L)
    }

    @Test
    fun `respond by addressee accepting pending request saves accepted friendship`() {
        assertResponse(true, FriendshipStatus.ACCEPTED, "FRIEND")
    }

    @Test
    fun `respond by addressee declining pending request saves declined request`() {
        assertResponse(false, FriendshipStatus.DECLINED, "INCOMING")
    }

    @ParameterizedTest
    @CsvSource("3, true", "3, false", "1, true", "1, false")
    fun `respond by third user or sender throws for either decision without saving`(userId: Long, accept: Boolean) {
        `when`(friendshipRepository.findById(20L)).thenReturn(Optional.of(friendship()))
        saveReturnsFriendship()

        assertRejectedWithoutChanges("You can only respond to requests sent to you") {
            service.respond(userId, 20L, accept)
        }
    }

    @Test
    fun `respond to nonexistent request throws without saving`() {
        `when`(friendshipRepository.findById(20L)).thenReturn(Optional.empty())

        assertRejectedWithoutChanges("Request not found") { service.respond(bor.id, 20L, true) }
    }

    @ParameterizedTest
    @CsvSource("ACCEPTED, true", "ACCEPTED, false", "DECLINED, true", "DECLINED, false")
    fun `respond to handled request rejects either decision without saving`(status: FriendshipStatus, accept: Boolean) {
        `when`(friendshipRepository.findById(20L)).thenReturn(Optional.of(friendship(status)))
        saveReturnsFriendship()

        assertRejectedWithoutChanges("This request has already been handled") { service.respond(bor.id, 20L, accept) }
    }

    @ParameterizedTest
    @ValueSource(longs = [1L, 2L])
    fun `removeFriend by either participant deletes the relationship`(userId: Long) {
        val accepted = friendship(FriendshipStatus.ACCEPTED)
        `when`(friendshipRepository.findById(20L)).thenReturn(Optional.of(accepted))

        service.removeFriend(userId, 20L)

        verify(friendshipRepository).delete(accepted)
        verify(friendshipRepository, never()).save(any(Friendship::class.java))
    }

    @Test
    fun `removeFriend by unrelated user throws without deleting`() {
        `when`(friendshipRepository.findById(20L)).thenReturn(Optional.of(friendship(FriendshipStatus.ACCEPTED)))

        assertRejectedWithoutChanges("Not your friendship") { service.removeFriend(3L, 20L) }
    }

    @Test
    fun `removeFriend for nonexistent relationship throws without deleting`() {
        `when`(friendshipRepository.findById(20L)).thenReturn(Optional.empty())

        assertRejectedWithoutChanges("Friendship not found") { service.removeFriend(ana.id, 20L) }
    }

    @Test
    fun `listFriends maps the other participant from either side as friend`() {
        val third = bor.copy(id = 3L, email = "third@example.com", firstName = "", lastName = "")
        `when`(friendshipRepository.findForUserWithStatus(ana.id, FriendshipStatus.ACCEPTED)).thenReturn(
            listOf(friendship(FriendshipStatus.ACCEPTED), friendship(FriendshipStatus.ACCEPTED).copy(requester = third, addressee = ana))
        )

        val result = service.listFriends(ana.id)

        assertThat(result.map { it.userId }).containsExactly(2L, 3L)
        assertThat(result.map { it.direction }).containsExactly("FRIEND", "FRIEND")
        assertThat(result.map { it.status }).containsExactly("ACCEPTED", "ACCEPTED")
        assertThat(result[1].name).isEqualTo("third@example.com")
        assertNoFriendshipChanges()
    }

    @Test
    fun `listIncoming maps pending requests to sender and incoming direction`() {
        `when`(friendshipRepository.findByAddresseeIdAndStatus(bor.id, FriendshipStatus.PENDING))
            .thenReturn(listOf(friendship()))

        val result = service.listIncoming(bor.id)

        assertThat(result).hasSize(1)
        assertThat(result.single().userId).isEqualTo(ana.id)
        assertThat(result.single().direction).isEqualTo("INCOMING")
        assertThat(result.single().status).isEqualTo("PENDING")
        assertNoFriendshipChanges()
    }

    @Test
    fun `listOutgoing maps pending requests to recipient and outgoing direction`() {
        `when`(friendshipRepository.findByRequesterIdAndStatus(ana.id, FriendshipStatus.PENDING))
            .thenReturn(listOf(friendship()))

        val result = service.listOutgoing(ana.id)

        assertThat(result).hasSize(1)
        assertThat(result.single().userId).isEqualTo(bor.id)
        assertThat(result.single().direction).isEqualTo("OUTGOING")
        assertThat(result.single().status).isEqualTo("PENDING")
        assertNoFriendshipChanges()
    }

    @Test
    fun `leaderboard ranks higher points first even when lower score has longer streak`() {
        prepareLeaderboard(100, 200)
        entries(ana.id, today, today.minusDays(1))

        val result = withFixedDate { service.leaderboard(ana.id) }

        assertThat(result.map { it.userId }).containsExactly(bor.id, ana.id)
        assertThat(result.map { it.points }).containsExactly(200, 100)
        assertThat(result.map { it.rank }).containsExactly(1, 2)
        assertThat(result.map { it.isMe }).containsExactly(false, true)
        assertNoFriendshipChanges()
    }

    @Test
    fun `leaderboard with equal points ranks longer streak first ignoring duplicate days`() {
        prepareLeaderboard(100, 100)
        entries(ana.id, today)
        entries(bor.id, today.minusDays(1), today.minusDays(1), today.minusDays(2), today.minusDays(4))

        val result = withFixedDate { service.leaderboard(ana.id) }

        assertThat(result.map { it.userId }).containsExactly(bor.id, ana.id)
        assertThat(result.map { it.streak }).containsExactly(2, 1)
        assertThat(result.map { it.rank }).containsExactly(1, 2)
    }

    @Test
    fun `leaderboard with old entries and no entries returns zero streaks`() {
        prepareLeaderboard(100, 100)
        entries(ana.id, today.minusDays(2), today.minusDays(3))

        val result = withFixedDate { service.leaderboard(ana.id) }

        assertThat(result).hasSize(2)
        assertThat(result.map { it.streak }).containsOnly(0)
    }

    @Test
    fun `leaderboard with repeated friend includes each user once`() {
        prepareLeaderboard(100, 200)
        val accepted = friendship(FriendshipStatus.ACCEPTED)
        `when`(friendshipRepository.findForUserWithStatus(ana.id, FriendshipStatus.ACCEPTED))
            .thenReturn(listOf(accepted, accepted.copy(id = 21L)))

        val result = withFixedDate { service.leaderboard(ana.id) }

        assertThat(result.map { it.userId }).containsExactly(bor.id, ana.id)
        verify(healthShieldService).getHealthShieldForUser(bor.id)
    }

    @Test
    fun `leaderboard without friends still includes current user`() {
        `when`(friendshipRepository.findForUserWithStatus(ana.id, FriendshipStatus.ACCEPTED)).thenReturn(emptyList())
        `when`(userRepository.findById(ana.id)).thenReturn(Optional.of(ana))
        `when`(healthShieldService.getHealthShieldForUser(ana.id)).thenReturn(shield(100))

        val result = service.leaderboard(ana.id)

        assertThat(result).hasSize(1)
        assertThat(result.single().userId).isEqualTo(ana.id)
        assertThat(result.single().rank).isEqualTo(1)
        assertThat(result.single().isMe).isTrue()
        assertThat(result.single().points).isEqualTo(100)
    }

    @Test
    fun `leaderboard when shield lookup fails retains user with default score and level`() {
        prepareLeaderboard(100, 200)
        `when`(healthShieldService.getHealthShieldForUser(bor.id)).thenThrow(IllegalStateException("Unavailable"))

        val result = service.leaderboard(ana.id)

        assertThat(result.map { it.userId }).containsExactly(ana.id, bor.id)
        assertThat(result[1].points).isZero()
        assertThat(result[1].level).isEqualTo(1)
        assertThat(result[1].levelName).isEqualTo("Basic Shield")
    }

    @Test
    fun `leaderboard for nonexistent current user throws without changing friendships`() {
        `when`(userRepository.findById(ana.id)).thenReturn(Optional.empty())

        assertRejectedWithoutChanges("User not found") { service.leaderboard(ana.id) }
        verifyNoInteractions(healthEntryRepository, healthShieldService)
    }

    private fun friendship(status: FriendshipStatus = FriendshipStatus.PENDING, reversed: Boolean = false) = Friendship(
        id = 20L, requester = if (reversed) bor else ana, addressee = if (reversed) ana else bor,
        status = status, createdAt = timestamp, updatedAt = timestamp
    )

    private fun prepareRequestUsers() {
        `when`(userRepository.findById(ana.id)).thenReturn(Optional.of(ana))
        `when`(userRepository.findByEmail(bor.email)).thenReturn(Optional.of(bor))
    }

    private fun stubExistingRequest(existing: Friendship) {
        `when`(friendshipRepository.findByRequesterIdAndAddresseeId(existing.requester!!.id, existing.addressee!!.id))
            .thenReturn(existing)
    }

    private fun saveReturnsFriendship(newId: Long? = null) {
        `when`(friendshipRepository.save(any(Friendship::class.java)))
            .thenAnswer {
                val saved = it.getArgument<Friendship>(0)
                if (newId != null && saved.id == 0L) saved.copy(id = newId) else saved
            }
    }

    private fun capturedSave(): Friendship {
        val captor = ArgumentCaptor.forClass(Friendship::class.java)
        verify(friendshipRepository).save(captor.capture())
        return captor.value
    }

    private fun assertNoFriendshipChanges() {
        assertAll(
            { verify(friendshipRepository, never()).save(any(Friendship::class.java)) },
            { verify(friendshipRepository, never()).delete(any(Friendship::class.java)) }
        )
    }

    private fun assertRejectedWithoutChanges(message: String, action: () -> Unit) {
        val error = catchThrowable { action() }
        assertAll(
            { assertThat(error).isInstanceOf(IllegalArgumentException::class.java).hasMessage(message) },
            { assertNoFriendshipChanges() }
        )
    }

    private fun assertResponse(accept: Boolean, expected: FriendshipStatus, direction: String) {
        val pending = friendship().copy(id = 63L)
        `when`(friendshipRepository.findById(63L)).thenReturn(Optional.of(pending))
        saveReturnsFriendship()

        val result = service.respond(bor.id, 63L, accept)

        val saved = capturedSave()
        assertThat(saved.status).isEqualTo(expected)
        assertThat(saved.copy(status = pending.status, updatedAt = pending.updatedAt)).isEqualTo(pending)
        assertThat(result.status).isEqualTo(expected.name)
        assertThat(result.direction).isEqualTo(direction)
        assertThat(result.userId).isEqualTo(ana.id)
        assertThat(result.friendshipId).isEqualTo(63L)
    }

    private fun prepareLeaderboard(myPoints: Int, friendPoints: Int) {
        `when`(friendshipRepository.findForUserWithStatus(ana.id, FriendshipStatus.ACCEPTED))
            .thenReturn(listOf(friendship(FriendshipStatus.ACCEPTED)))
        `when`(userRepository.findById(ana.id)).thenReturn(Optional.of(ana))
        `when`(healthShieldService.getHealthShieldForUser(ana.id)).thenReturn(shield(myPoints))
        `when`(healthShieldService.getHealthShieldForUser(bor.id)).thenReturn(shield(friendPoints))
    }

    private fun shield(points: Int) = HealthShieldResponseDto(
        level = 2, levelName = "Basic Shield", totalConsistencyPoints = points,
        currentLevelStartPoints = 100, nextLevelPoints = 300, pointsToNextLevel = 300 - points,
        progressPercent = 0, todayPoints = 0, penaltyPoints = 0, completedHabitsCount = 0,
        consecutiveFailedDays = 0, dailyBreakdown = null
    )

    private fun entries(userId: Long, vararg dates: LocalDate) {
        `when`(healthEntryRepository.findByUserIdOrderByEntryDateDesc(userId)).thenReturn(
            dates.map { HealthEntry(entryDate = it, createdAt = timestamp, updatedAt = timestamp) }
        )
    }

    private fun <T> withFixedDate(action: () -> T): T =
        mockStatic(LocalDate::class.java, CALLS_REAL_METHODS).use { dateMock ->
            dateMock.`when`<LocalDate> { LocalDate.now() }.thenReturn(today)
            action()
        }
}
