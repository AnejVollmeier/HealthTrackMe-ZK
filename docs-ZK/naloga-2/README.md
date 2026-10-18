
# Naloga 2 – Testiranje enot

## 1. NOVI TESTI

### UserService – Sprememba gesla

Testi preverjajo spremembo uporabniškega gesla. Geslo se mora uspešno spremeniti, če uporabnik vnese pravilno trenutno geslo, novo geslo vsebuje vsaj šest znakov in se ujema s potrditvijo.

Testi preverjajo tudi napačno trenutno geslo, prekratko geslo, neujemanje potrditve, neaktivnega uporabnika in neobstoječ račun. Ob neveljavnih podatkih mora metoda sprožiti izjemo in ne sme shraniti sprememb.

**Namerno vneseni napaki:**
- Minimalno dolžino gesla sem spremenil s 6 na 7 znakov. Test za šestmestno geslo je padel.
- Odstranil sem preverjanje potrditve gesla. Test je zaznal, da se sprememba nepravilno dovoli.

**Rezultat: 19/19 uspešnih testov po obnovitvi kode.**

### MedicineService – Beleženje zdravil

Testi preverjajo beleženje odmerkov zdravil in izračun doslednosti jemanja. Če uporabnik vzame vse odmerke, je doslednost 100 %, če jih vzame polovico, pa 50 %. Statusa `SKIPPED` in `SCHEDULED` ne vplivata na izračun odstotka.

Preveril sem tudi prazne podatke, časovno obdobje, pravilno shranjevanje statusov, razveljavitev odmerka in neobstoječe zdravilo.

**Namerno vneseni napaki:**
- V izračun doslednosti sem vključil še `SKIPPED`. Test je namesto pričakovanih 50 % dobil 33,33 % in padel.
- Pri odmerku `MISSED` sem nepravilno nastavil čas zaužitja. Test je zaznal, da bi morala biti vrednost `takenTime` prazna.

**Rezultat: 24/24 uspešnih testov po obnovitvi kode.**

### FriendshipService – Dodajanje prijateljev

Testi preverjajo pošiljanje, sprejemanje in zavračanje prošenj za prijateljstvo. Uporabnik ne sme dodati samega sebe ali ustvariti podvojene prošnje, na prošnjo pa lahko odgovori samo njen prejemnik.

Preveril sem tudi neobstoječe uporabnike, že obdelane prošnje, odstranjevanje prijateljev in razvrščanje na lestvici.

**Namerno vneseni napaki:**
- Odstranil sem preverjanje prejemnika prošnje. Test je zaznal, da lahko nepooblaščen uporabnik spremeni status prijateljstva.
- Pri zavrnitvi sem nastavil `ACCEPTED` namesto `DECLINED`. Test je zaznal napačen status.

**Rezultat: 39/39 uspešnih testov po obnovitvi kode.**

Vseh šest namernih napak so testi uspešno zaznali. Po vsaki napaki sem obnovil pravilno kodo. Teste sem tudi pregledal in izboljšal, predvsem preverjanje izjem, shranjevanja podatkov in uporabo mock objektov.

**Končni rezultat celotnega backenda: 101/101 uspešnih testov.**

## 2. JaCoCo

Za merjenje pokritosti kode s testi sem uporabil **JaCoCo 0.8.15**, ki sem ga vključil v Maven in GitHub Actions.

Rezultati pokritosti celotnega backenda:

| Vrsta pokritosti | Rezultat |
|---|---:|
| Pokritost instrukcij | 29 % |
| Pokritost vrstic kode | **35,24 %** |
| Pokritost vej (pogojev) | **15,57 %** |

Pokritost je izmerjena za celoten backend, ne samo za tri izbrane enote.

GitHub Actions ob vsakem pushu na `main` izvede backend teste. Če kateri test pade, se cevovod neuspešno zaključi.

Po izvajanju se shranita dva artifacta:
- `backend-jacoco-report` – poročilo o pokritosti kode.
- `backend-test-results` – rezultati izvedenih testov.

Uspešno izvajanje cevovoda in oba artifacta sem preveril na GitHubu.
