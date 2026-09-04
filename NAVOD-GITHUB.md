# Návod: jak dostat macOS apku na GitHub

Interní poznámka pro mě, ne dokumentace pro uživatele (ta je v [README.md](README.md)).
Postup, kterým se Chrono dostalo na GitHub – dá se zopakovat u jakékoli další Xcode aplikace.

---

## 0. Co je potřeba mít

- **Xcode** (tady 26.0.1)
- **GitHub CLI** – `brew install gh`
- Přihlášení: `gh auth login` (ověříš přes `gh auth status`)

---

## 1. Příprava repozitáře

### `.gitignore`

Do repa nesmí lézt build výstupy ani uživatelská nastavení Xcode:

```
.DS_Store
xcuserdata/
*.xcuserstate
*.moved-aside
DerivedData/
build/
dist/
.swiftpm/
.build/
```

Klíčové je hlavně `xcuserdata/` (osobní nastavení Xcode, breakpointy, poslední otevřená okna)
a `build/` s `DerivedData/` – to jsou stovky MB, které nikdo nepotřebuje.

### `README.md`

Musí odpovědět na tři věci: **co to je**, **jak si to stáhnout hotové** a **jak si to přeložit
ze zdrojáků**. U nepodepsané apky nesmí chybět sekce o Gatekeeperu (viz krok 4), jinak si kamarád
bude myslet, že je apka rozbitá.

### `LICENSE`

U veřejného repa se hodí. MIT je nejjednodušší – dělej si s tím co chceš, neručím za nic.

### Schéma (u Chrona nebylo potřeba řešit)

Xcode si schémata ukládá do `xcuserdata/`, což je v `.gitignore` – takže se necommitnou.
U jednoduchých projektů to nevadí: Xcode si schéma **automaticky vygeneruje z targetu**, takže
`xcodebuild -scheme Chrono` funguje i po čerstvém klonu. Ověřeno klonem do prázdné složky.

Řešit to musíš, jen když má projekt vypnutou autogeneraci schémat nebo vlastní upravené schéma
(jiné argumenty spuštění, proměnné prostředí, pre-actions). Pak:

**Product → Scheme → Manage Schemes… → zaškrtnout „Shared" → Close**

Vznikne `Chrono.xcodeproj/xcshareddata/xcschemes/Chrono.xcscheme`, který se commitne.
Zkontrolovat jde přes `xcodebuild -list -project Chrono.xcodeproj`.

---

## 2. Založení repa na GitHubu

```bash
cd /cesta/k/projektu
git init -b main
git add -A
git commit -m "Chrono 1.0 – macOS menu bar stopky"

gh repo create Chrono --public --source=. --push \
  --description "Menu bar stopky pro macOS s evidencí odpracovaného času"
```

`--source=.` řekne `gh`, ať použije tenhle lokální repozitář, `--push` rovnou nahraje `main`
a nastaví `origin`. Pro soukromé repo stačí `--private` místo `--public`
(a pak `gh repo add-collaborator` nebo pozvánka přes web).

Kontrola: `gh repo view --web`

---

## 3. Vydání hotové .app v Releases

Aby si ji mohl stáhnout i někdo bez Xcode.

```bash
# 1. Release build
xcodebuild -project Chrono.xcodeproj -scheme Chrono -configuration Release \
  -derivedDataPath build clean build

# 2. Zabalit
mkdir -p dist
ditto -c -k --keepParent \
  build/Build/Products/Release/Chrono.app \
  dist/Chrono-1.0-macOS.zip

# 3. Vydat
gh release create v1.0 dist/Chrono-1.0-macOS.zip \
  --title "Chrono 1.0" \
  --notes "První veřejná verze."
```

**Proč `ditto` a ne `zip`:** `zip` rozbije symlinky uvnitř `.app` bundlu a poškodí podpis –
apka pak na cizím Macu spadne hned při startu. `ditto -c -k --keepParent` je to, co používá
i Finder při „Comprimovat".

---

## 4. Gatekeeper – proč to kamarádovi hlásí chybu

Bez placeného **Apple Developer Programu** (99 USD/rok) nejde aplikaci notarizovat. Podepisuje se
jen lokálně (ad-hoc podpis), a takovou apku macOS při stažení z internetu zablokuje.

Není to nic rozbitého, jen Gatekeeper. Odblokování:

- **Nastavení systému → Soukromí a zabezpečení → Přesto otevřít** (objeví se až po prvním
  neúspěšném pokusu o spuštění), nebo
- `xattr -dr com.apple.quarantine /Applications/Chrono.app`

> **Pozor:** na macOS 15 Sequoia už **nefunguje** starý trik „pravý klik → Otevřít". Apple ho
> odstranil. Nabízej rovnou jednu ze dvou možností výše.

Jediná cesta, jak se varování zbavit úplně, je zaplatit vývojářský program a apku notarizovat
(`xcrun notarytool submit` + `xcrun stapler staple`).

---

## 5. Jak vydat další verzi

1. V Xcode zvýšit **MARKETING_VERSION** (target Chrono → General → Version), např. na `1.1`
2. Commitnout změny:
   ```bash
   git add -A
   git commit -m "Verze 1.1 – <co je nového>"
   git push
   ```
3. Nový build a release:
   ```bash
   xcodebuild -project Chrono.xcodeproj -scheme Chrono -configuration Release \
     -derivedDataPath build clean build
   ditto -c -k --keepParent \
     build/Build/Products/Release/Chrono.app \
     dist/Chrono-1.1-macOS.zip
   gh release create v1.1 dist/Chrono-1.1-macOS.zip \
     --title "Chrono 1.1" --notes "<co je nového>"
   ```

Tag (`v1.1`) si `gh release create` vytvoří sám z aktuálního commitu.

---

## Užitečné příkazy

| Příkaz | K čemu |
|---|---|
| `gh repo view --web` | otevřít repo v prohlížeči |
| `gh release list` | seznam vydaných verzí |
| `gh release delete v1.0 --cleanup-tag` | smazat release i s tagem |
| `git status --short` | co se chystá commitnout |
| `xcodebuild -list -project Chrono.xcodeproj` | jaká schémata projekt má |
