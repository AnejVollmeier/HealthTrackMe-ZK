# Naloga 4 – Sistemsko testiranje

## 1. Izbrano orodje in testni scenarij

Za sistemsko testiranje sem izbral **Grafana k6 (v2.3.0)**, ki omogoča simulacijo virtualnih uporabnikov, merjenje odzivnih časov in spremljanje napak med obremenitvijo.

Testiral sem naslednjo funkcionalnost:

- **API:** `GET /api/v1/medicines/users/{userId}`
- **Namen:** pridobivanje aktivnih zdravil posameznega uporabnika.
- **Testni podatki:** testni uporabnik z ID `16` in tremi aktivnimi zdravili (`K6-Test-01`, `K6-Test-02`, `K6-Test-03`).
- **Avtentikacija:** JWT žeton testnega uporabnika.

Testna skripta: [`tests/k6/medicines-load.js`](../../tests/k6/medicines-load.js).

## 2. Pogoji in kriteriji testiranja

Pred izvedbo sem določil petminutni profil obremenitve z največ 20 virtualnimi uporabniki.

| Čas     | Število virtualnih uporabnikov |
| ------- | -----------------------------: |
| 0–1 min |                  Postopno do 5 |
| 1–2 min |                 Postopno do 10 |
| 2–3 min |                 Postopno do 20 |
| 3–4 min |                             20 |
| 4–5 min |                  Postopno do 0 |

**Merjene metrike in kriteriji uspešnosti:**

| Metrika                            | Kriterij         |
| ---------------------------------- | ---------------- |
| 95. percentil odzivnega časa (p95) | Manj kot 1000 ms |
| Delež neuspešnih HTTP zahtev       | Manj kot 1 %     |
| Uspešnost funkcionalnih preverjanj | Več kot 99 %     |

Funkcionalni preverjanji sta zahtevali odgovor HTTP `200` ter uspešen JSON odgovor s seznamom treh zdravil.

## 3. Rezultati testiranja

Po petih minutah izvajanja sem zabeležil naslednje rezultate:

| Metrika                            | Izmerjena vrednost | Rezultat     |
| ---------------------------------- | -----------------: | ------------ |
| Skupno število HTTP zahtev         |               3230 | Informativno |
| Povprečna prepustnost              |     10,76 zahtev/s | Informativno |
| Povprečni odzivni čas              |           14,36 ms | Informativno |
| Najdaljši odzivni čas              |          100,55 ms | Informativno |
| 95. percentil odzivnega časa (p95) |           20,68 ms | PASS         |
| Neuspešne HTTP zahteve             |       0 % (0/3230) | PASS         |
| Uspešna funkcionalna preverjanja   |  100 % (6460/6460) | PASS         |

Vseh 3230 HTTP zahtev je bilo uspešnih, pri vseh pa sta bili izpolnjeni obe funkcionalni preverjanji. Med izvajanjem testiranja ni bilo zaznanih napak ali prekinjenih iteracij.

## 4. Zaključek

**Obremenitveni test je bil uspešen (PASS).** Sistem je pri največ 20 sočasnih virtualnih uporabnikih izpolnil vse vnaprej določene kriterije odzivnosti in uspešnosti.

Rezultati kažejo, da je testirani API v lokalnem okolju stabilno obdeloval izbrano obremenitev. Ker je bilo testiranje omejeno na en API endpoint in en testni uporabniški račun, rezultatov ni mogoče neposredno posplošiti na celotno aplikacijo ali produkcijsko okolje.

**Avtor:** Anej Vollmeier
