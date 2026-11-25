# Naloga 5 – Avtomatizirano funkcionalno testiranje

## 1. Izbira orodja

Za avtomatizacijo funkcionalnih testov sem uporabil **Flutter integration_test**, ChromeDriver(oz. EdgeDriver) in Chrome for Testing. Orodja omogočajo samodejno testiranje aplikacije tudi brez grafičnega vmesnika (headless).

## 2. Izvedba testov

Avtomatiziral sem vseh šest funkcionalnih testov iz Naloge 3.

| Test       | Opis                                | Rezultat |
| ---------- | ----------------------------------- | -------- |
| FS-01-TP01 | Registracija, odjava in prijava     | PASS     |
| FS-01-TP02 | Prijava z napačnim geslom           | PASS     |
| FS-02-TP01 | Dodajanje zdravila in odmerek TAKEN | PASS     |
| FS-02-TP02 | Zavrnitev praznega imena zdravila   | PASS     |
| FS-03-TP01 | Pošiljanje in sprejem prijateljstva | PASS     |
| FS-03-TP02 | Zavrnitev dodajanja samega sebe     | PASS     |

**Rezultat: 6/6 PASS.** Teste sem izvajal z ločeno podatkovno bazo `healthtrackme_e2e`.

## 3. Namerno vnesena napaka

V datoteki `medicines_screen.dart` sem namerno spremenil status odmerka iz `TAKEN` v `SKIPPED`.

Test FS-02-TP01 je zaznal napako:

    Expected: 1
    Actual: 0
    Result: FAIL

Po odpravi napake sem test ponovno izvedel in dobil **PASS**.

## 4. GitHub Actions

Pripravil sem workflow `.github/workflows/functional-e2e.yml`, ki samodejno pripravi testno okolje, izvede vseh šest testov in shrani rezultate.

Workflow je pripravljen, vendar še ni bil dejansko izveden na GitHub Actions.

## 5. Ročni zagon avtomatiziranih testov

Najprej v korenski mapi projekta zaženem PostgreSQL:

```powershell
docker compose up -d
```

V drugem terminalu zaženem ChromeDriver:

```powershell
& "C:\Tools\CromeTesting\chromedriver-win64\chromedriver.exe" --port=4444
```

Nato v tretjem terminalu nastavim povezavo Spring Boot API-ja z bazo `healthtrackme_e2e`, port `18080` in avtentikacijo ter zaženem backend:

```powershell
cd apps\api
.\mvnw.cmd spring-boot:run
```

Iz mape `apps/mobile_flutter` izvedem pet funkcionalnih testov:

```powershell
.\integration_test\run_remaining.ps1
```

Šesti test FS-01-TP02 zaženem posebej:

```powershell
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/fs_01_tp02_test.dart -d web-server --web-port=52145 --browser-name=chrome --driver-port=4444 --headless --chrome-binary="C:\Tools\CromeTesting\chrome-win64\chrome.exe" --dart-define-from-file=.env.e2e.json
```

Vseh šest testov lahko samodejno izvede tudi pripravljeni GitHub Actions workflow v Linux CI-okolju.

Rezultati lokalnih testov se shranijo v mapo `build/e2e/`.
