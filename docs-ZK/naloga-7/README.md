# Naloga 7 – Model kakovosti in specifikacija merjenja

**Projekt:** HealthTrackMe-ZK  
**Predmet:** Zagotavljanje kakovosti programske opreme  
**Status:** Priprava presoje kakovosti – meritve še niso izvedene.

## 1. Namen naloge

Namen naloge je pripraviti model kakovosti programske rešitve HealthTrackMe-ZK po standardu **ISO/IEC 25010:2023** in specifikacijo prihodnjega merjenja po postopku **ISO/IEC 25040**.

HealthTrackMe-ZK je aplikacija za spremljanje zdravstvenih podatkov, zdravil in odmerkov ter upravljanje uporabniških računov in prijateljstev. Razvita je s Flutterjem, Kotlin/Spring Boot in PostgreSQL.

V nalogi določimo:

- ključne karakteristike in podkarakteristike kakovosti;
- merljive metrike in postopke merjenja;
- številčne mejne vrednosti in njihovo utemeljitev;
- ustreznost, izvedljivost in omejitve posamezne metrike.

**Meritev še ne izvajamo in ne ocenjujemo dejanske kakovosti aplikacije.**

## 2. Postopek presoje po ISO/IEC 25040

Pri nalogi upoštevamo prve tri pripravljalne faze postopka presoje kakovosti, predstavljenega na predavanjih.

| Faza                  | Aktivnosti                                         |
| --------------------- | -------------------------------------------------- |
| 1. Določitev zahtev   | Opredelitev namena, obsega in zahtev kakovosti.    |
| 2. Določitev ocene    | Izbira metrik, formul in mejnih vrednosti.         |
| 3. Oblikovanje ocene  | Načrtovanje postopkov, podatkov, orodij in okolja. |
| 4. Izvedba merjenja   | Ni predmet Naloge 7.                               |
| 5. Zaključek merjenja | Ni predmet Naloge 7.                               |

Pri prihodnji izvedbi bomo uporabili izolirano testno okolje, sintetične podatke in dokumentirane različice programske opreme.

## 3. Model kakovosti ISO/IEC 25010:2023

Za HealthTrackMe-ZK smo izbrali štiri najpomembnejše karakteristike in pet podkarakteristik.

| Karakteristika         | Podkarakteristika      | Utemeljitev izbire                                                                                  |
| ---------------------- | ---------------------- | --------------------------------------------------------------------------------------------------- |
| Functional suitability | Functional correctness | Pravilno beleženje zdravil, odmerkov in uporabniških podatkov je ključna funkcionalnost aplikacije. |
| Reliability            | Recoverability         | Po odpovedi sistema morajo ostati potrjeni zdravstveni podatki ohranjeni in dostopni.               |
| Security               | Confidentiality        | Osebni in zdravstveni podatki morajo biti zaščiteni pred nepooblaščenim dostopom.                   |
| Security               | Authenticity           | Sistem mora pravilno preverjati identiteto uporabnikov pri prijavi in dostopu do API-ja.            |
| Performance efficiency | Time behaviour         | Aplikacija mora uporabniku omogočati dovolj hitro pridobivanje podatkov o zdravilih.                |

Za vsako podkarakteristiko smo določili najmanj eno merljivo metriko.

### 3.1 Metoda GQM (Goal–Question–Metric)

Pri izbiri metrik smo upoštevali metodo GQM, ki povezuje cilj kakovosti, vprašanje in merljivo metriko.

| Cilj (Goal)                                     | Vprašanje (Question)                                                | Metrika (Metric)             |
| ----------------------------------------------- | ------------------------------------------------------------------- | ---------------------------- |
| Zagotoviti pravilnost ključnih funkcionalnosti. | Ali vseh šest izbranih funkcionalnih scenarijev deluje pravilno?    | M1 – Funkcionalna pravilnost |
| Zagotoviti obnovljivost sistema.                | Ali se sistem po odpovedi obnovi brez izgube potrjenih podatkov?    | M2 – Obnovljivost            |
| Zaščititi zdravstvene podatke.                  | Ali sistem preprečuje nedovoljeno razkritje podatkov?               | M3 – Zaupnost                |
| Zagotoviti pravilno preverjanje identitete.     | Ali sistem sprejme veljavne in zavrne neveljavne identitete?        | M4 – Pristnost               |
| Zagotoviti ustrezno odzivnost API-ja.           | Ali odzivni čas pridobivanja zdravil izpolnjuje določene kriterije? | M5 – Časovna odzivnost       |

Metoda GQM omogoča, da je vsaka izbrana metrika neposredno povezana s ciljem presoje kakovosti.

## 4. Specifikacija merjenja

### M1 – Funkcionalna pravilnost

**Karakteristika:** Functional suitability  
**Podkarakteristika:** Functional correctness

**Metrika:** Delež uspešno zaključenih funkcionalnih testov.

**Formula:**

`M1 = (P / 6) × 100 %`

P pomeni število uspešno zaključenih testov.

**Kriterij:** M1 = 100 %, torej vseh šest testov mora uspešno prestati preverjanje.

**Način merjenja:** Izvedemo šest obstoječih funkcionalnih testov z ogrodjem Flutter `integration_test`:

| Test       | Funkcionalnost                          |
| ---------- | --------------------------------------- |
| FS-01-TP01 | Registracija, odjava in prijava         |
| FS-01-TP02 | Zavrnitev napačnega gesla               |
| FS-02-TP01 | Dodajanje zdravila in beleženje odmerka |
| FS-02-TP02 | Zavrnitev zdravila brez imena           |
| FS-03-TP01 | Pošiljanje in sprejem prijateljstva     |
| FS-03-TP02 | Zavrnitev dodajanja samega sebe         |

**Orodja:** Flutter, ChromeDriver, PostgreSQL, Spring Boot API in GitHub Actions.

**Utemeljitev meje:** Vseh šest izbranih obveznih scenarijev mora vrniti pričakovan rezultat. Gre za projektni kriterij, ne zahtevo standarda.

**Kritična presoja:** Metrika neposredno preverja pravilnost izbranih funkcionalnosti in je že izvedljiva z obstoječimi testi. Ne zagotavlja pa pravilnosti celotne aplikacije, ker šest testov ne pokriva vseh funkcionalnosti.

### M2 – Obnovljivost sistema

**Karakteristika:** Reliability  
**Podkarakteristika:** Recoverability

**Metrika:** Čas obnove sistema in delež ohranjenih podatkov po odpovedi.

**Formuli:**

`T = t_uspešne_obnove − t_začetka_obnove`

`D = (K / N) × 100 %`

K pomeni število pravilno ohranjenih zapisov, N pa število potrjenih zapisov pred odpovedjo.

**Kriteriji:**

- Čas obnove T ≤ 120 sekund.
- Delež ohranjenih podatkov D = 100 %.
- Število nepričakovanih podvojenih zapisov = 0.

**Način merjenja:** V izoliranem okolju pripravimo testnega uporabnika, zdravilo in odmerke. Nato ločeno simuliramo odpoved Spring Boot API-ja in PostgreSQL ter po ponovnem zagonu preverimo delovanje in podatke.

**Orodja:** Docker, PostgreSQL, Spring Boot, HTTP odjemalec in merjenje časa.

**Utemeljitev meje:** Popolna ohranitev potrjenih podatkov je predlagana projektna zahteva. Meja 120 sekund je začasen projektni predlog za lokalno okolje, ki potrebuje potrditev. Ne gre za zahtevo ISO ali dogovorjeni SLA.

**Kritična presoja:** Metrika ustrezno meri obnovljivost, če preverimo tako delovanje kot pravilnost podatkov. Meritvi odpovedi API-ja in baze sta izvedljivi, vendar zahtevata pripravo dodatnega postopka. Običajna osvežitev brskalnika ne dokazuje obnovljivosti sistema. Obnova po izgubi celotnega podatkovnega volumna zahteva ločen načrt varnostnega kopiranja.

### M3 – Zaupnost podatkov

**Karakteristika:** Security  
**Podkarakteristika:** Confidentiality

**Metrika:** Delež pravilno zavrnjenih nedovoljenih zahtev.

**Formula:**

`M3 = (Z / N) × 100 %`

Z pomeni število pravilno zavrnjenih nedovoljenih zahtev, N pa skupno število vnaprej določenih nedovoljenih zahtev.

**Kriterij:** M3 = 100 % in 0 nedovoljenih razkritij.

**Način merjenja:** Ustvarimo dva testna uporabnika z različnimi zdravstvenimi podatki. Nato z uporabnikovim žetonom poskusimo dostopati do podatkov drugega uporabnika prek API-ja. Preverimo status in vsebino odgovora. Izvedemo tudi pozitivne kontrole dostopa do lastnih podatkov.

**Orodja:** Postman ali Python HTTP-skripta, Spring Boot API in PostgreSQL.

**Utemeljitev meje:** Nobena načrtovana nedovoljena zahteva ne sme razkriti zaščitenih podatkov. To je predlagan projektni varnostni kriterij.

**Kritična presoja:** Metrika neposredno preverja zaupnost izbranih podatkov in je izvedljiva na obstoječem API-ju. Ne pokriva vseh možnih varnostnih tveganj.

Pri statičnem pregledu kode je bila zaznana **možna pomanjkljivost preverjanja lastništva zdravil pri dostopu po ID-ju**. To še ni potrjena ranljivost in jo bo treba preveriti z dejanskim testiranjem.

### M4 – Pristnost uporabnikov

**Karakteristika:** Security  
**Podkarakteristika:** Authenticity

**Metrika:** Delež pravilno sprejetih veljavnih in zavrnjenih neveljavnih prijav oziroma žetonov.

**Formule:**

`A+ = (S / V) × 100 %`

`A− = (R / I) × 100 %`

`M4 = min(A+, A−)`

S pomeni pravilno sprejete veljavne primere, V vse veljavne primere, R pravilno zavrnjene neveljavne primere in I vse neveljavne primere.

**Kriterij:** A+ = 100 % in A− = 100 %.

**Način merjenja:** Preverimo prijavo s pravilnim in napačnim geslom, neobstoječim oziroma neaktivnim računom ter veljavnimi, spremenjenimi, manjkajočimi in pretečenimi JWT-žetoni. Preverimo tudi pravilno identiteto prek `/auth/me`. Google prijavo obravnavamo posebej, če je vključena v merilni obseg.

**Orodja:** JUnit, Spring Boot API, JWT in HTTP odjemalec.

**Utemeljitev meje:** Vsi vnaprej določeni veljavni primeri morajo biti pravilno sprejeti, neveljavni pa zavrnjeni.

**Kritična presoja:** Metrika ustrezno preverja pristnost identitete. Osnovni testi že obstajajo, vendar bi bilo treba razširiti preverjanje dejanskega JWT-filtra in Google prijave. Samo zavračanje vseh zahtev ne bi predstavljalo uspešnega rezultata.

### M5 – Časovna odzivnost

**Karakteristika:** Performance efficiency  
**Podkarakteristika:** Time behaviour

**Metrika:** 95. percentil odzivnega časa API-ja za pridobivanje zdravil.

**Formula:**

`M5 = p95(časi API-zahtev)`

**Kriteriji:**

- M5 < 1000 ms.
- Delež neuspelih HTTP-zahtev < 1 %.
- Delež uspešnih preverjanj > 99 %.

**Način merjenja:** Uporabimo obstoječi obremenitveni test `tests/k6/medicines-load.js`, ki preverja API za pridobivanje zdravil.

Predviden petminutni profil:

| Časovni interval | Virtualni uporabniki |
| ---------------- | -------------------: |
| 0–1 min          |                    5 |
| 1–2 min          |                   10 |
| 2–3 min          |                   20 |
| 3–4 min          |                   20 |
| 4–5 min          |                    0 |

Testni uporabnik ima tri aktivna zdravila. Pri vsaki iteraciji preverimo odgovor API-ja.

**Orodja:** k6, Spring Boot API in PostgreSQL.

**Utemeljitev meje:** Kriterij 1000 ms in spremljevalna pogoja izhajajo iz obstoječega obremenitvenega testa pri 4. nalogi. Niso predpisani s standardom ISO.

**Kritična presoja:** Metrika ustrezno meri odzivnost izbrane API-operacije. Meritev je izvedljiva z obstoječo skripto. Ne meri pa celotnega časa prikaza uporabniškega vmesnika ali delovanja vseh funkcionalnosti aplikacije.

## 5. Pregled metrik in kriterijev

| Metrika | Podkarakteristika      | Sprejemni kriterij                                |
| ------- | ---------------------- | ------------------------------------------------- |
| M1      | Functional correctness | 100 % uspešnost šestih testov                     |
| M2      | Recoverability         | T ≤ 120 s, D = 100 %, brez podvojitev             |
| M3      | Confidentiality        | 100 % zavrnjenih nedovoljenih zahtev, 0 razkritij |
| M4      | Authenticity           | 100 % pravilno sprejetih in zavrnjenih identitet  |
| M5      | Time behaviour         | p95 < 1000 ms, napake < 1 %, preverjanja > 99 %   |

Pri M2 je časovna meja 120 sekund začasen, še nepotrjen kriterij. Pri M5 uporabljamo obstoječe projektne kriterije, ostale mejne vrednosti pa so utemeljeni predlogi za izbrani obseg.

## 6. Pravila odločanja

Za vsako metriko določimo tri možne ocene:

| Ocena                 | Pomen                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| **Ustrezno**          | Veljavne meritve izpolnjujejo vse določene in potrjene kriterije.                                |
| **Neustrezno**        | Najmanj ena veljavno ugotovljena vrednost krši dogovorjeni kriterij.                             |
| **Ni mogoče oceniti** | Meritev ni izvedena, podatki so nepopolni, okolje je neveljavno ali ključni kriterij ni potrjen. |

Pri M1, M3 in M4 ni dovoljeno izločiti neizvedenih primerov ter na podlagi preostalih razglasiti uspeha.

Pri M2 ocenjujemo ohranitev podatkov in čas obnove. Dokler časovna meja ni potrjena, skupne časovne ustreznosti ni mogoče potrditi.

Pri M5 morajo biti izpolnjeni vsi trije kriteriji, ne samo hitrost odziva.

**V Nalogi 7 so vse metrike trenutno specificirane, vendar neizmerjene.**

## 7. Omejitve presoje

- Izbranih šest funkcionalnih testov ne preverja celotne aplikacije.
- Obnovljivost zahteva dodatne scenarije odpovedi in obnove.
- Varnostne meritve zahtevajo ustrezno konfigurirano avtentikacijo in testne uporabnike.
- Obremenitveni test meri izbrano API-operacijo, ne celotnega uporabniškega postopka.
- Projektne mejne vrednosti niso zahteve standarda ISO.
- Pred prihodnjimi meritvami je treba zabeležiti različice orodij, revizijo kode in testno okolje.

## 9. Viri

- ISO/IEC 25010:2023 – Product quality model: https://www.iso.org/standard/78176.html
- ISO/IEC 25040:2024 – Quality evaluation framework: https://www.iso.org/standard/83467.html
- Pavlič, L. (2026). _Standardni modeli kakovosti IT rešitev_. Gradivo predavanj, Univerza v Mariboru, FERI, str. 38–57.
- Pavlič, L. (2026). _Merjenje kakovosti – Metrike_. Gradivo predavanj, Univerza v Mariboru, FERI, str. 12–20, 57–61 in 71–81.
- [Naloga 4 – Sistemsko testiranje](../naloga-4/README.md)
- [Naloga 5 – Avtomatizirani funkcionalni testi](../naloga-5/README.md)
- Izvorna koda HealthTrackMe-ZK in analitični pogovor s Codexom.
