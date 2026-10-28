# Naloga 3 – Priprava testnih scenarijev

V okviru naloge sem pripravil in ročno izvedel tri funkcionalne testne scenarije aplikacije HealthTrackMe. Za vsak scenarij sem pripravil pozitiven in negativen testni primer. Dokumentacija sledi dobrim praksam standarda ISO/IEC/IEEE 29119-3:2021.

## 1. Pregled dokumentacije in izbor scenarijev

Pred pripravo scenarijev sem pregledal obstoječo [projektno dokumentacijo](../../README.md) ter dokumentacijo [Naloge 1](../naloga-1/README.md) in [Naloge 2](../naloga-2/README.md). Na podlagi pregleda ključnih funkcionalnosti aplikacije sem izbral registracijo in prijavo uporabnika, upravljanje zdravil ter dodajanje prijateljev.

| ID    | Testni scenarij                                | Odgovorna oseba |
| ----- | ---------------------------------------------- | --------------- |
| FS-01 | Registracija, odjava in ponovna prijava        | Anej Vollmeier  |
| FS-02 | Dodajanje zdravila in beleženje zaužitja       | Anej Vollmeier  |
| FS-03 | Pošiljanje in sprejem prošnje za prijateljstvo | Anej Vollmeier  |

**Testno okolje:** Flutter Web aplikacija, lokalni Spring Boot backend in PostgreSQL podatkovna baza.

**Testni podatki:** Dva različna testna uporabnika (A in B), datum rojstva uporabnika A `15. 5. 2000` in zdravilo `ZK-Test-01` z odmerkom `1 tableta` ter pogostostjo enkrat dnevno. Gesla in e-poštni naslovi niso vključeni v dokumentacijo.

## 2. Specifikacije testnih primerov

### FS-01 – Registracija, odjava in ponovna prijava

#### FS-01-TP01 – Uspešna registracija in prijava (pozitivni test)

**Predpogoji:** Aplikacija deluje, uporabnik A še ni registriran.

| Korak | Testno dejanje                                 | Pričakovani rezultat                                       |
| ----- | ---------------------------------------------- | ---------------------------------------------------------- |
| 1     | Registriram novega uporabnika A.               | Registracija je uspešna.                                   |
| 2     | Odprem profil in preverim uporabniške podatke. | Ime, e-pošta in datum rojstva so pravilni.                 |
| 3     | Odjavim se iz aplikacije.                      | Dostop do uporabniškega profila brez prijave je preprečen. |
| 4     | Ponovno se prijavim z istimi podatki.          | Prijava uspe, podatki profila ostanejo nespremenjeni.      |

#### FS-01-TP02 – Prijava z napačnim geslom (negativni test)

**Predpogoji:** Uporabnik A je registriran in odjavljen.

| Korak | Testno dejanje                                    | Pričakovani rezultat                                                          |
| ----- | ------------------------------------------------- | ----------------------------------------------------------------------------- |
| 1     | Vnesem pravilen e-poštni naslov in napačno geslo. | Aplikacija zavrne prijavo in prikaže sporočilo o napačnih prijavnih podatkih. |

### FS-02 – Dodajanje zdravila in beleženje zaužitja

#### FS-02-TP01 – Dodajanje zdravila in beleženje odmerka (pozitivni test)

**Predpogoji:** Uporabnik A je prijavljen.

| Korak | Testno dejanje                                                   | Pričakovani rezultat                                |
| ----- | ---------------------------------------------------------------- | --------------------------------------------------- |
| 1     | Dodam zdravilo `ZK-Test-01`, odmerek `1 tableta`, enkrat dnevno. | Zdravilo je uspešno dodano in prikazano na seznamu. |
| 2     | Označim današnji odmerek kot zaužit.                             | Odmerek dobi oznako zaužito (`TAKEN`).              |
| 3     | Osvežim stran v brskalniku.                                      | Zdravilo in oznaka zaužitja ostaneta prikazana.     |

#### FS-02-TP02 – Dodajanje zdravila brez naziva (negativni test)

**Predpogoji:** Uporabnik A je prijavljen.

| Korak | Testno dejanje                                    | Pričakovani rezultat                         |
| ----- | ------------------------------------------------- | -------------------------------------------- |
| 1     | Odprem dodajanje zdravila in pustim naziv prazen. | Obrazec omogoča preverjanje obveznega polja. |
| 2     | Poskusim shraniti zdravilo brez naziva.           | Aplikacija prepreči shranjevanje.            |

### FS-03 – Pošiljanje in sprejem prošnje za prijateljstvo

#### FS-03-TP01 – Pošiljanje in sprejem prošnje (pozitivni test)

**Predpogoji:** Registrirana sta uporabnika A in B, ki še nista prijatelja.

| Korak | Testno dejanje                                | Pričakovani rezultat                                      |
| ----- | --------------------------------------------- | --------------------------------------------------------- |
| 1     | Kot uporabnik A pošljem prošnjo uporabniku B. | Prošnja se pojavi med čakajočimi (`PENDING`).             |
| 2     | Odjavim se in prijavim kot uporabnik B.       | Prejeta prošnja je na voljo za sprejem.                   |
| 3     | Kot uporabnik B sprejmem prošnjo.             | Uporabnik A se prikaže med prijatelji.                    |
| 4     | Ponovno se prijavim kot uporabnik A.          | Prijateljstvo je potrjeno, prošnja ni več med čakajočimi. |

#### FS-03-TP02 – Dodajanje samega sebe (negativni test)

**Predpogoji:** Uporabnik A je prijavljen.

| Korak | Testno dejanje                                    | Pričakovani rezultat                                     |
| ----- | ------------------------------------------------- | -------------------------------------------------------- |
| 1     | Poskusim poslati prošnjo na svoj e-poštni naslov. | Aplikacija zavrne zahtevo in prikaže ustrezno sporočilo. |

## 3. Poročilo o izvedbi testiranja

Funkcionalne teste sem ročno izvedel **23. 10. 2026**. Dodatno sem **28. 10. 2026** preveril pravilnost podatkov profila po ponovni prijavi in preprečitev dostopa po odjavi.

| Testni primer | Datum               | Dejanski rezultat                                                                                                                                          | Status   |
| ------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| FS-01-TP01    | 23. in 28. 10. 2026 | Registracija, odjava in ponovna prijava so uspele. Podatki profila so bili pravilni tudi po ponovni prijavi. Dostop do profila po odjavi je bil preprečen. | **PASS** |
| FS-01-TP02    | 23. 10. 2026        | Prijava z napačnim geslom je bila zavrnjena s sporočilom `Invalid email or password`.                                                                      | **PASS** |
| FS-02-TP01    | 23. 10. 2026        | Zdravilo `ZK-Test-01` je bilo dodano. Odmerek sem označil kot `TAKEN`, oznaka pa je ostala tudi po osvežitvi brskalnika.                                   | **PASS** |
| FS-02-TP02    | 23. 10. 2026        | Aplikacija je pravilno preprečila shranjevanje zdravila brez naziva.                                                                                       | **PASS** |
| FS-03-TP01    | 23. 10. 2026        | Prošnja se je prikazala med čakajočimi, uporabnik B jo je sprejel in prijateljstvo je bilo uspešno potrjeno.                                               | **PASS** |
| FS-03-TP02    | 23. 10. 2026        | Poskus dodajanja samega sebe je bil zavrnjen s sporočilom `You can't add yourself`.                                                                        | **PASS** |

### Povzetek rezultatov

| Rezultat                | Število |
| ----------------------- | ------: |
| Funkcionalni scenariji  |       3 |
| Izvedeni testni primeri |       6 |
| Uspešni testi (PASS)    |       6 |
| Neuspešni testi (FAIL)  |       0 |

Vseh šest izvedenih funkcionalnih testnih primerov je bilo uspešnih. Pri preverjanih osnovnih funkcionalnostih nisem zaznal napak.

**Avtor:** Anej Vollmeier
