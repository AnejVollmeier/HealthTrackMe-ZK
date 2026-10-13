# Zagotavljanje kakovosti (ZK)

## Kazalo nalog

| Naloga | Poročilo | Stanje |
| --- | --- | --- |
| 1 – Izbira projekta in popis stanja | [Naloga 1](naloga-1/README.md) | Končano |

## Cheat Sheet

### Backend

Iz korena repozitorija:

```powershell
.\scripts\run-api-local.ps1
```

Alternativni zagon iz `apps/api`:

```powershell
.\mvnw.cmd spring-boot:run
```

Backend testi iz `apps/api`:

```powershell
.\mvnw.cmd clean test
```

### Flutter frontend

Iz korena repozitorija:

```powershell
.\scripts\run-flutter-local.ps1
```

Alternativni spletni zagon iz `apps/mobile_flutter`:

```powershell
flutter pub get
flutter run -d edge --web-port=52145 --dart-define="GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com"
```

Za Google prijavo morata biti ustrezno nastavljena `GOOGLE_WEB_CLIENT_ID` in backend `GOOGLE_OAUTH_ALLOWED_CLIENT_IDS`.

Android debug iz `apps/mobile_flutter`:

```powershell
flutter run
```

Android release APK iz `apps/mobile_flutter`:

```powershell
flutter build apk --release --dart-define="GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com"
```

### Testiranje in kakovost Flutterja

Iz `apps/mobile_flutter`:

```powershell
flutter test
flutter analyze
dart format .
dart format --output=none --set-exit-if-changed .
```

<p align="right">Avtor: Anej Vollmeier</p>
