# Naloga 1 – Izbira projekta in popis stanja

## 1. Pregled dokumentacije

Pregledal sem [glavni README](../../README.md), [backend README](../../apps/api/README.md), [Flutter README](../../apps/mobile_flutter/README.md), zagonske skripte in konfiguracijske datoteke ter preveril vzpostavitev v Windows. Ugotovil sem, da navodila omogočajo orientacijo, ne pa varnega in ponovljivega celovitega zagona.

| Ugotovitev | Predlagana izboljšava |
| --- | --- |
| [FlywayConfig.kt](../../apps/api/src/main/kotlin/com/healthwithme/api/config/FlywayConfig.kt) kliče `repair()` in `migrate()`; [V100](../../apps/api/src/main/resources/db/migration/V100__reset_and_seed_demo_data.sql) vsebuje destruktivni `TRUNCATE ... CASCADE`. | Dokumentirati tveganje izgube podatkov in ločiti popravilo zgodovine od običajnega zagona. |
| [run-api-local.ps1](../../scripts/run-api-local.ps1) iz `.env` naloži samo Google nastavitve, ne pa nastavitev baze. | Uskladiti nalaganje konfiguracije s predlogo in navodili. |
| Skripti sta namenjeni PowerShellu; lokalni Linux/macOS zagon je slabše dokumentiran in nepreverjen. | Dodati postopke in predpogoje za posamezne operacijske sisteme. |
| Predpogoji in začetno stanje baze niso dovolj jasno opisani v [navodilih](../../README.md) in [Compose konfiguraciji](../../docker-compose.yml). | Navesti zahtevana orodja, prosta vrata, obstoječe volumne ter preverjanje zdravja baze. |
| [Backend CI](../../.github/workflows/backend-ci.yml) uporablja PostgreSQL 15, lokalno 16; [frontend CI](../../.github/workflows/frontend-ci.yml) ne izvaja zakomentirane APK gradnje. | Uskladiti okolji in jasno opredeliti obseg CI. |

## 2. Standardi kodiranja

**Kotlin:** opazil sem PascalCase za razrede, camelCase za člane in štiripresledkovne zamike.

**Dart:** opazil sem snake_case datoteke, PascalCase razrede in camelCase metode; [analysis_options.yaml](../../apps/mobile_flutter/analysis_options.yaml) vključuje `flutter_lints`, oblikovanje pa preverja `dart format`.

S pomočjo Codexa sem popravil eno datoteko: [apps/api/src/main/kotlin/com/healthwithme/api/service/UserService.kt](../../apps/api/src/main/kotlin/com/healthwithme/api/service/UserService.kt). Odstranil sem presledke na štirih praznih vrsticah in uredil uvoze; poslovne logike, podpisov metod in javnih imen nisem spremenil.

## 3. Testiranje in zagotavljanje kakovosti

| Aktivnost | Stanje | Pokriti del | Orodja | 
| --- | --- | --- | --- | 
| Backend unit testi | Uspešno: 17/17 | [Storitve](../../apps/api/src/test/kotlin/com/healthwithme/api/service): uporabniki, JWT, Health Shield. | JUnit 5, Mockito, JJWT 
| Backend controller testi | Uspešno: 6/6 | [Kontrolerji](../../apps/api/src/test/kotlin/com/healthwithme/api/controller): avtentikacija in Health Shield z nadomeščenimi storitvami. | MockMvc, `@WebMvcTest`, Mockito 
| Backend repository testi | Uspešno: 3/3 | [Repozitoriji](../../apps/api/src/test/kotlin/com/healthwithme/api/repository): uporabniki in zdravstveni vnosi. | `@DataJpaTest`, H2, JPA 
| Spring context test | Uspešno: 1/1 | [Nalaganje konteksta](../../apps/api/src/test/kotlin/com/healthwithme/api/HealthTrackMeApiApplicationTests.kt). | `@SpringBootTest`, JUnit 5, H2 
| Flutter unit testi | Uspešno: 38/38 | [Modeli](../../apps/mobile_flutter/test/models) in [haptična storitev](../../apps/mobile_flutter/test/services/haptics_service_test.dart); fizična vibracija ni preverjena. | `flutter_test` 
| Flutter widget test | Uspešno: 1/1 | [Router in AuthScreen](../../apps/mobile_flutter/test/widget_test.dart), brez celovite prijave. | WidgetTester, Provider 
| Flutter statična analiza in formatiranje | Uspešno: brez težav; 55 datotek, 0 razlik | Dart koda in njeno oblikovanje. | `flutter analyze`, `flutter_lints`, `dart format` 
| Backend CI | Obstaja; izvedba nepreverjena | [Testi, paket in Docker slika](../../.github/workflows/backend-ci.yml). | GitHub Actions, Maven, Docker 
| Frontend CI | Obstaja; izvedba nepreverjena | [Odvisnosti, format, analiza in testi](../../.github/workflows/frontend-ci.yml). | GitHub Actions, Flutter 
| Android distribucija | Obstaja; izvedba nepreverjena | [Release APK in distribucija](../../.github/workflows/android-distribute.yml), `develop` ali ročna sprožitev. | GitHub Actions, Firebase 
| Priprava Flutter odvisnosti | Neuspešen zaključek | Paketi preneseni; napaka Windows simbolnih povezav. | `flutter pub get` 
| Backend prevajanje | Uspešno z opozorili | Produkcijska in testna koda; nenadzorovane pretvorbe tipov in zastareli API-ji. | Maven, Kotlin compiler 
| Diagnostični zagon in zdravje baze | Omejeno uspešno | PostgreSQL zdrav, JDBC povezava, HTTP 401; spletni prijavni obrazec in HTTP 200. | Docker, SQL, Spring Boot, Edge 
| Pregled migracij | Pregled opravljen; izvajanje nepreverjeno | Flyway strategija in destruktivna V100. | Pregled Kotlin/SQL 

Potrdil sem **27/27 backend in 39/39 Flutter testov**. [Backend testni profil](../../apps/api/src/test/resources/application-test.yml) uporablja H2 in izključi Flyway, zato teh rezultatov ne štejem za potrditev PostgreSQL migracij. Pokritosti kode nisem meril in celovitih end-to-end preizkusov nisem izvedel.

## 4. Uporaba umetne inteligence
Pri nalogi sem si z umetno inteligenco pomagal predvsem pri pripravi in oblikovanju README.md datotek ter pri začetnem pregledu projektne dokumentacije.

<p align="right">Avtor: Anej Vollmeier</p>