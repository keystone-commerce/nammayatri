# Driver App Technology Stack

## Main Answer

The driver-facing app is not React Native in its primary UI path. It is a native mobile shell that hosts a PureScript UI bundle rendered through Juspay HyperSDK / Presto / PrestoDOM.

React Native appears in optional Android application wiring, but the driver app screens, navigation, API calls, and UI state are in PureScript.

## Repository Layout

Important frontend directories:

- `Frontend/ui-driver` - driver PureScript app.
- `Frontend/ui-customer` - rider/customer PureScript app.
- `Frontend/ui-common` - shared PureScript services, components, bridge wrappers.
- `Frontend/android-native/app` - Android app wrapper and product flavors.
- `Frontend/android-native/mobility-driver` - driver native bridge/assets.
- `Frontend/android-native/mobility-common` - shared native bridge/services.
- `Frontend/android-native/mobility-app` - shared Android services.

This checkout does not include an iOS native Xcode project. A repository-wide search found no `.xcodeproj`, `.xcworkspace`, `Podfile`, Swift, or Objective-C app host files. iOS support is visible from the PureScript bundle and bridge side, not from native iOS source in this repo.

## Build Stack

`Frontend/ui-driver/package.json` identifies the driver UI package as `atlas-ui-driver`.

Important scripts:

- `spago build` for PureScript compilation.
- Webpack bundling for Android and iOS outputs.
- `npm start` for local frontend development.

Important caveat: `Frontend/ui-driver/package.json` declares `bundle:ios` and `prod:ios`, but `Frontend/ui-driver/webpack.ios.js` is missing in this checkout. The customer app has a corresponding `Frontend/ui-customer/webpack.ios.js`, so the likely driver-side fix is to add an equivalent driver iOS Webpack config before trying to produce the iOS driver bundle from this repo.

`Frontend/ui-driver/spago.dhall` declares the PureScript package and dependencies such as Presto and PrestoDOM.

`Frontend/android-native/app/build.gradle` configures the Android app, SDK versions, product flavors, driver application IDs, and native config values such as merchant IDs and backend config URLs.

`Frontend/android-native/mobility-driver/build.gradle` includes the driver Android library and Juspay HyperSDK dependency.

`Frontend/README.md` references iOS startup with `npm run start:ios:<master, sandbox, or prod>`, but the driver package currently only has generic `start` and no `start:ios:*` scripts. Treat iOS build/run instructions as incomplete in this checkout until the missing packaging scripts or separate iOS host repository are identified.

## Runtime Shape

The native app provides a container and bridge. The PureScript UI renders inside the DUI/Hyper container.

The Android XML host is mostly a shell. `Frontend/android-native/app/src/main/res/layout/activity_main.xml` defines the DUI container view used by HyperSDK.

The primary driver UI entrypoint is:

- `Frontend/ui-driver/src/Main.purs`

`Main.purs` exports `main`, initializes the app state, starts `flowRunner`, and enters `Flow.baseAppFlow`.

The main router is:

- `Frontend/ui-driver/src/Flow.purs`

## API Call Path From UI

PureScript defines typed request/response objects and endpoint instances in:

- `Frontend/ui-driver/src/Services/API.purs`

URL construction lives in:

- `Frontend/ui-driver/src/Services/Endpoint.purs`

Headers and app-level API wrappers live in:

- `Frontend/ui-driver/src/Services/Backend.purs`

The shared API bridge is:

- `Frontend/ui-common/src/Services/CallAPI.purs`
- `Frontend/ui-common/src/Services/CallAPI.js`

The JS FFI calls native `window.JBridge.callAPI` / `callAPIWithOptions`. Native Android then performs HTTP through bridge/service code in `Frontend/android-native/mobility-common`.

For iOS, the same PureScript/JS call path is expected to call the iOS implementation of `window.JBridge`. `Frontend/ui-common/src/Services/CallAPI.js` has explicit iOS handling: when `window.__OS == "IOS"`, request body/header payloads are base64 encoded before being passed to `JBridge.callAPI`. This means the storefront API client code should remain in shared PureScript and rely on the platform bridge.

`Frontend/ui-common/src/Engineering/Helpers/JBridge.js` also has iOS-specific branches for common bridge functions such as network checks and app/link opening. For storefront browsing, the most important cross-platform bridge functions are normal API calls, remote image rendering, and optional `openUrlInApp`.

## Practical Consequences For Keystone

Build the storefront as a PureScript/PrestoDOM screen, not as a React Native feature.

Use existing PureScript API patterns for Namma Yatri backend calls. Do not call Keystone directly from PureScript with `x-api-key`.

Because the driver UI is shared, the storefront should be implemented once under `Frontend/ui-driver` and then validated on both Android and iOS host apps. Platform-specific work should be limited to packaging, bridge behavior, image/webview behavior, and any native config needed to ship the bundle.

If a quick proof of concept is needed, the app already has `openUrlInApp` patterns for external URLs and embedded web-like flows, but a long-term integrated catalog should use a native PureScript screen backed by a Namma Yatri server proxy.
