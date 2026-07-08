# Android Storefront Implementation Notes

## Current implementation

- Driver UI target: `Frontend/ui-driver`.
- Native Android target: `Frontend/android-native`, `nyDriver` flavor, source root `app/src/driver/nammaYatriPartner`.
- Storefront entry point: Benefits screen, after the referral/Gullak cards and before the leaderboard.
- Catalog source: Keystone partner catalog API, `GET /products?page=1&limit=12&sortBy=createdAt&sortOrder=desc`.

## Files changed

- `Frontend/ui-driver/webpack.android.js`
  - Adds `window.__KEYSTONE_API_KEY` and `window.__KEYSTONE_API_BASE_URL` through webpack `DefinePlugin`.
  - The key is read from the `KEYSTONE_API_KEY` environment variable at bundle time.
- `Frontend/ui-driver/src/Services/KeystoneCatalog.purs`
  - PureScript `Aff` wrapper around the catalog fetch FFI.
- `Frontend/ui-driver/src/Services/KeystoneCatalog.js`
  - Calls Keystone `/products`, adds `x-api-key`, normalizes API products for the UI.
  - Uses `window.JBridge.callAPIWithOptions`/`callAPI` in the native app, with browser `fetch` only as a fallback.
- `Frontend/ui-driver/src/Screens/Types.purs`
  - Adds Keystone catalog/product state types.
- `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen/ScreenData.purs`
  - Initializes Keystone products, error state, and loading state.
- `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen/Controller.purs`
  - Handles `UpdateKeystoneCatalog`.
- `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen/View.purs`
  - Fetches catalog on screen load and renders a horizontal product storefront.

## Local verification

From `Frontend/ui-driver`:

```bash
npm install --cache ./.npm-cache
npm install --no-save purescript@0.15.4 --cache ./.npm-cache
npm run compile:purs
KEYSTONE_API_KEY='<partner_key>' npm run bundle:android
```

Results from this workspace:

- `npm run compile:purs`: passed.
- `KEYSTONE_API_KEY=... npm run bundle:android`: passed, generated `Frontend/ui-driver/dist/android/index_bundle.js`.
- Live Keystone `/products` call: returned `200`, `total = 58`, with product images and prices.

## Android emulator build path

This repo expects Android app setup before Gradle can build:

- Java/JDK available to Gradle.
- `Frontend/android-native/local.properties`.
- `Frontend/android-native/app/google-services.json`.
- Required `local.properties` values from `Frontend/README.md`, including `MAPS_API_KEY`, `MERCHANT_ID_USER`, and `MERCHANT_ID_DRIVER`.

Once Android setup exists:

```bash
cd Frontend/ui-driver
KEYSTONE_API_KEY='<partner_key>' npm run prod:android

cd ../android-native
cp ../ui-driver/dist/android/index_bundle.js app/src/driver/nammaYatriPartner/assets/juspay/index_bundle.js
cd ..
sh driverJuspayAssets.sh nammaYatriPartner

cd android-native
./gradlew installNyDriverDevDebug
```

Use the actual Gradle task name from `./gradlew tasks --all` if it differs.

## Security note

This is a debug/emulator-only integration path. The generated Android JS bundle contains the API key when built with `KEYSTONE_API_KEY`, so do not commit generated bundle changes. Production should proxy Keystone catalog requests through the Namma Yatri backend so the partner key stays server-side.
