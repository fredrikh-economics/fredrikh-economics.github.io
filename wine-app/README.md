# VinScanner

Skanna vinflaskor med din iPhone och få direkt info om druvsort, matparing, Systembolaget-länk med mera.

## Snabbstart med Expo Snack (ingen dator krävs)

1. Installera **Expo Go** från App Store på din iPhone
2. Gå till [snack.expo.dev](https://snack.expo.dev) i Safari
3. Skapa ett nytt projekt och ersätt filerna med koden härifrån
4. Tryck på **"My Device"** och skanna QR-koden med Expo Go

## Lokal körning (med dator)

```bash
cd wine-app
npm install
npx expo start
```

## Funktioner

- **Streckkodsskanning** — skanna EAN-13 på vinflaskan
- **Vininfo** — namn, producent, druva, årgång, land, alkohol
- **Matparing** — anpassad för vintypen
- **Systembolaget** — direktlänk till sökning
- **Vinlogg** — spara viner med betyg och anteckningar

## Datakällor

- [Open Food Facts](https://world.openfoodfacts.org) — gratis produktdatabas
- Systembolaget — söklänk genereras automatiskt
