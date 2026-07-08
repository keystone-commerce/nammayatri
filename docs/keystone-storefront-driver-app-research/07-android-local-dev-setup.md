# Android local dev setup notes

Checked against the official upstream remote `git@github.com:nammayatri/nammayatri.git` and the current local checkout.

## Official README path

The top-level README points Android setup to `Frontend/README.md`.

Official frontend setup says:

- Enter the frontend Nix shell: `nix develop .#frontend`.
- Install dependencies inside both `Frontend/ui-customer` and `Frontend/ui-driver` with `npm i`.
- For Android:
  - Open `Frontend/android-native` in Android Studio.
  - Select the required build variant.
  - Add `app/google-services.json`.
  - Add `MAPS_API_KEY` to `Frontend/android-native/local.properties`.
  - Add user and driver merchant ids to `Frontend/android-native/local.properties`.
  - Run the app on a selected device.

For bundle creation, the official README uses:

```bash
cd Frontend/android-native
bash bundling.sh nammaYatri nammaYatriPartner
```

For Namma Yatri Partner Android debug, the useful Gradle task is:

```bash
cd Frontend/android-native
./gradlew :app:installNyDriverDevDebug
```

## Property names that Gradle actually reads

`Frontend/android-native/app/build.gradle` loads `Frontend/android-native/local.properties` and injects these values into `BuildConfig`:

```properties
CONFIG_URL_DRIVER = "..."
CONFIG_URL_USER = "..."
MERCHANT_ID_USER = "..."
MERCHANT_ID_DRIVER = "..."
MAPS_API_KEY = "..."
RS_ENC_KEY = "..."
RS_ALGO = "..."
RS_INSTANCE_TYPE = "..."
RS_ALGO_PADDING = "..."
```

The README says `USER_MERCHANT_ID` and `DRIVER_MERCHANT_ID`, but the Gradle file uses `MERCHANT_ID_USER` and `MERCHANT_ID_DRIVER`. The Gradle names are authoritative for this checkout.

`MainActivity.updateConfigURL` writes these into shared preferences:

- `MERCHANT_ID`
- `BASE_URL`
- `CUSTOMER_BASE_URL`
- `CUSTOMER_REG_TOKEN`

For the driver app, `BASE_URL` comes from `CONFIG_URL_DRIVER`, and `MERCHANT_ID` comes from `MERCHANT_ID_DRIVER`.

## Current blocker

The app is installed and `MainActivity` is resumed, but it remains on the splash screen. The current local `local.properties` contains empty placeholders, so the native bootstrap payload and shared prefs do not contain a usable driver backend/config URL or merchant id.

The local placeholder `google-services.json` also lets Firebase initialize enough to avoid an immediate crash, but Firebase Remote Config logs auth/fetch failures. A real dev Firebase config is needed for a faithful local run.

## Backend dev stack from official README

The backend README recommends:

```bash
ln -sf .envrc.backend .envrc
direnv allow
cd Backend
cabal build all
, run-mobility-stack-dev
```

The local dev command starts the mobility stack with `cabal run` and also starts dependencies such as Postgres, Redis, Passetto, OSRM, and Kafka.

Relevant local ports:

- Rider app: `8013`
- Dynamic offer driver app: `8016`
- Beckn gateway: `8015`
- Mock registry: `8020`
- Transporter scheduler: `8053`
- Allocation service: `9996`

If we run a fully local backend, the Android emulator must use host routing for localhost endpoints, usually `10.0.2.2` instead of `localhost`.

## Recommended next step

For fastest Android validation, get the real Namma Yatri dev/sandbox Android config first:

- `Frontend/android-native/app/google-services.json`
- `Frontend/android-native/local.properties` values for `nyDriverDevDebug`, especially `CONFIG_URL_DRIVER`, `MERCHANT_ID_DRIVER`, `CONFIG_URL_USER`, `MERCHANT_ID_USER`, and `MAPS_API_KEY`.

Only create local backend instances if no hosted dev/sandbox backend is available or if Keystone needs server-side integration work immediately.

## Sourcing config values

Current local findings:

- `gcloud` is authenticated as a Keystone account against project `keystone-7892`.
- Keystone Secret Manager has Keystone backend/corporate gifting secrets, but not the Namma Yatri Android app config.
- Firebase CLI is installed, but is not authenticated yet.
- `gcloud firebase` only exposes Firebase Test Lab commands in this SDK; use Firebase CLI for app SDK config.

Expected sources:

- `google-services.json`: Firebase project that owns Namma Yatri Android apps.
- `MAPS_API_KEY`: Google Cloud project/API key used for Android Maps/Places.
- `CONFIG_URL_DRIVER` and `CONFIG_URL_USER`: Namma Yatri dev/sandbox backend URLs, or local backend URLs if running `, run-mobility-stack-dev`.
- `MERCHANT_ID_DRIVER` and `MERCHANT_ID_USER`: merchant IDs for the chosen Namma Yatri environment.
- `RS_*`: internal route/security/encryption config used by the native app. These need to come from the same dev/sandbox config source as the backend URLs.

Firebase CLI workflow once the right Firebase project access is available:

```bash
firebase login
firebase projects:list
firebase apps:list ANDROID --project <firebase-project-id>
firebase apps:sdkconfig ANDROID <firebase-app-id> \
  --project <firebase-project-id> \
  --out Frontend/android-native/app/google-services.json
```

For `nyDriverDevDebug`, the Firebase Android app must include package:

```text
in.juspay.nammayatripartner.debug
```

For release/prod-style builds, the package is:

```text
in.juspay.nammayatripartner
```

Secret Manager workflow if Namma Yatri stores Android config there:

```bash
gcloud config set project <nammayatri-dev-project>
gcloud secrets list --format='table(name,createTime)'
gcloud secrets versions access latest --secret=<secret-name> > /tmp/nammayatri-android-config
```

Do not print secret payloads in terminal history or commit generated config files. `Frontend/android-native/local.properties` and `Frontend/android-native/app/google-services.json` are ignored by git.
