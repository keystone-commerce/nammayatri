# iOS Real Device And TestFlight Research

Date: 2026-05-05

## Short Answer

Yes, iOS real-device and TestFlight testing is possible if we have the actual iOS host project and App Store Connect access for the bundle ID.

For the current Keystone storefront plan, the storefront code should still be implemented once in `Frontend/ui-driver` as shared PureScript. The iOS work is about the native host, bundle packaging, signing, and TestFlight upload.

The current local checkout of `nammayatri/nammayatri` does not contain the production iOS native host. Public GitHub has a separate `nammayatri/nammayatri-react-native` repo with an iOS project, but it appears experimental/prototype-level rather than the production Namma Yatri 3 iOS app pipeline.

## Public Repository Findings

Namma Yatri GitHub org:

- `https://github.com/nammayatri`

Main open-source repo:

- `https://github.com/nammayatri/nammayatri`

Findings in `nammayatri/nammayatri`:

- `Frontend` contains `android-native`, `ui-driver`, `ui-customer`, and `ui-common`.
- No `.xcodeproj`, `.xcworkspace`, `Podfile`, Swift, or Objective-C app host files are present in this checkout.
- GitHub workflows include frontend compile checks and Android release workflows.
- The driver release workflow is Android-only: `.github/workflows/release-apk-driver.yaml`.
- Android Fastlane lanes upload driver AABs to Google Play internal track.
- No public TestFlight/App Store Connect upload workflow is visible in this repo.

Separate React Native repo:

- `https://github.com/nammayatri/nammayatri-react-native`

Findings in `nammayatri-react-native`:

- Contains `ios/NammaYatri.xcodeproj`.
- Contains `ios/NammaYatri.xcworkspace`.
- Contains `ios/Podfile`.
- `package.json` has `ios: react-native run-ios`.
- Uses React Native 0.73.6.
- Contains PureScript files under `src/`, including `src/ui-driver` and `src/ui-common`.
- The iOS project bundle identifier is still the React Native template value: `org.reactjs.native.example.$(PRODUCT_NAME:rfc1034identifier)`.
- `AppDelegate.mm` is a standard React Native host loading `index` in debug and `main.jsbundle` in release.
- No GitHub Actions workflows are visible for TestFlight upload.

Interpretation: `nammayatri-react-native` is useful evidence that the team has explored an iOS/RN host, but it does not look like a complete production release pipeline for the current Namma Yatri driver app.

## Public App Store Evidence

Apple App Store shows the rider app:

- App: Namma Yatri - Ride Booking App
- Bundle ID from iTunes Lookup API: `in.juspay.nammayatri`
- Developer: MOVING TECH INNOVATIONS PRIVATE LIMITED
- Current observed version: `3.3.140`
- Minimum observed iOS: `15.1`
- URL: `https://apps.apple.com/in/app/namma-yatri-ride-booking-app/id1637429831`

Apple App Store also shows a driver app under the same developer:

- App: Bridge Driver App
- Bundle ID from iTunes Lookup API: `com.mobility.movingtechdriver`
- Developer: MOVING TECH INNOVATIONS PRIVATE LIMITED
- Current observed version: `1.0.11`
- Minimum observed iOS: `14.0`
- URL: `https://apps.apple.com/us/app/bridge-driver-app/id6498885663`

I did not find a public App Store listing for `Namma Yatri Partner` on iOS equivalent to the Google Play driver package `in.juspay.nammayatripartner`. This may mean the Indian driver iOS app is not public, uses a different brand, is private/TestFlight-only, or the native host/release code is not in the public repo.

## What We Need To Test Keystone On iPhone

Minimum required inputs:

- Actual iOS host repository or project used for the driver app.
- The mechanism that consumes the `Frontend/ui-driver` bundle.
- Bundle identifier for the driver app being tested.
- Apple Developer team access for that bundle identifier.
- App Store Connect access if using TestFlight.
- Signing/capabilities setup.
- Any native secrets/config equivalent to Android `local.properties`.
- A way to package the updated PureScript storefront bundle into the iOS host.

Without the actual iOS host or packaging script, we can compile the shared storefront code, but cannot truthfully install the Namma Yatri driver app on an iPhone or upload it to TestFlight from this checkout alone.

## Real Device Development Install

If the iOS host project is available:

1. Build the shared driver JS/PureScript bundle.
2. Install JS/native dependencies.
3. Run CocoaPods:

```bash
cd ios
pod install
open NammaYatri.xcworkspace
```

4. In Xcode, select the app target.
5. Set the Apple team in Signing & Capabilities.
6. Use a valid bundle identifier that belongs to that team.
7. Connect the iPhone or use wireless debugging.
8. Select the physical iPhone as the run destination.
9. Run from Xcode.

For a React Native host, the debug path is usually:

```bash
npm install
cd ios && pod install && cd ..
npm start
npm run ios -- --device "<device name>"
```

For a Namma Yatri Hyper/Presto host, the exact commands depend on the missing iOS host and bundle ingestion pipeline.

## TestFlight Path

Apple-supported TestFlight flow:

1. Create or use an App Store Connect app record for the exact bundle ID.
2. Ensure the bundle ID exists in Certificates, Identifiers & Profiles.
3. Configure signing in Xcode with an Apple Distribution certificate and App Store provisioning.
4. Increment build number every upload.
5. Select `Any iOS Device (arm64)` in Xcode.
6. `Product > Archive`.
7. In Organizer, choose `Distribute App`.
8. Select `App Store Connect`.
9. Select `Upload`.
10. Wait for App Store Connect processing.
11. Add the build to an internal TestFlight group.
12. For external testers, submit the build for Apple beta review.

Apple also supports upload through Transporter, App Store Connect API, and command-line tooling. Fastlane can wrap this with `build_app` and `upload_to_testflight`.

## Fastlane Shape If We Own The iOS Host

The public `nammayatri/nammayatri` Fastlane setup is Android-only. For iOS, a minimal lane would look conceptually like:

```ruby
platform :ios do
  lane :beta do
    build_app(
      workspace: "ios/NammaYatri.xcworkspace",
      scheme: "NammaYatri",
      export_method: "app-store"
    )

    upload_to_testflight(
      api_key_path: "app_store_connect_api_key.json",
      skip_waiting_for_build_processing: false
    )
  end
end
```

Do not copy this literally until the real iOS workspace, scheme, bundle ID, entitlements, and signing model are known.

## Keystone-Specific Implications

Keystone should not change the iOS release model:

- Backend proxy keeps the Keystone key off-device.
- Shared `Frontend/ui-driver` storefront means one UI implementation.
- iOS TestFlight only needs a host that can package and run the updated shared bundle.

Before Keystone implementation starts, resolve:

- Which public/private iOS host is authoritative for the driver app?
- Is `nammayatri-react-native` intended to replace the current Hyper/Presto host, or is it only a prototype?
- How does the production iOS host receive updated `ui-driver` bundles?
- Which iOS driver bundle ID should Keystone testing use?
- Will Keystone be tested under Moving Tech's App Store Connect account, Keystone's account, or a separate fork/app record?

## Source Links

- Namma Yatri org: `https://github.com/nammayatri`
- Main repo: `https://github.com/nammayatri/nammayatri`
- React Native repo: `https://github.com/nammayatri/nammayatri-react-native`
- Main repo Frontend tree: `https://github.com/nammayatri/nammayatri/tree/main/Frontend`
- Android driver release workflow: `https://github.com/nammayatri/nammayatri/blob/main/.github/workflows/release-apk-driver.yaml`
- React Native iOS tree: `https://github.com/nammayatri/nammayatri-react-native/tree/main/ios`
- Apple TestFlight: `https://developer.apple.com/testflight/`
- Apple upload builds: `https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds`
- Xcode upload to App Store Connect: `https://help.apple.com/xcode/mac/current/en.lproj/dev442d7f2ca.html`
- Fastlane TestFlight upload: `https://docs.fastlane.tools/actions/pilot/`

