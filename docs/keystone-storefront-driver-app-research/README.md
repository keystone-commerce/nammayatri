# Keystone Storefront Driver App Research

Date: 2026-05-05

Scope: driver-facing Namma Yatri app. The user mentioned both rider-facing and driver-facing during discovery, but the latest explicit instruction was to focus on the driver-facing app.

## Executive Summary

The Namma Yatri driver app is not React Native in its main UI path. It is a hybrid architecture:

- Native mobile shell, with Android host code present in this checkout under `Frontend/android-native`.
- Driver UI written in PureScript under `Frontend/ui-driver`.
- UI rendered through Juspay HyperSDK / Presto / PrestoDOM.
- Shared PureScript services and bridge code under `Frontend/ui-common`.

The iOS native host project is not present in this checkout, but the shared PureScript/JBridge code contains iOS paths and the frontend README references iOS startup. In this architecture the storefront should be implemented once in `Frontend/ui-driver` and bundled for both Android and iOS.

The safest Keystone catalog integration is a Namma Yatri backend proxy:

1. Driver app calls a new authenticated Namma Yatri `/ui/...` endpoint using the existing driver token.
2. Driver backend calls Keystone Catalog API server-side with `x-api-key`.
3. Backend returns normalized catalog DTOs to the app.
4. PureScript storefront screen renders categories, product lists, search, and product detail.

Do not put the Keystone `x-api-key` in the mobile app or PureScript bundle. It is extractable from APK/IPA/bundle artifacts and bypasses Namma Yatri's driver auth, merchant/city gating, auditing, rate limits, and key rotation.

## Recommended Product Entry

Start with a Keystone card or section in the existing Benefits/Rankings area, then optionally add a Home quick-entry tile if stronger discovery is needed.

Avoid a new bottom navigation tab for the first release. Bottom nav is config-driven but structurally hardcoded across app flow, and a new permanent tab has a larger blast radius than a Benefits card plus routed screen.

## What Can Ship With Current Keystone API

Current Keystone API supports:

- Health check.
- Category tree.
- Product list with pagination and filters.
- Product detail by slug.
- Search across products/categories.

Current Keystone API does not support:

- Orders.
- Payments.
- Coupons.

Therefore the first Namma Yatri integration can be a browse/search/detail storefront, but checkout must be deferred, handled by a separate Keystone-hosted web flow, or implemented through a later orders/payments API.

## Docs In This Folder

- `01-driver-app-technology-stack.md` - native vs PureScript vs React Native, Android/iOS build/runtime layout.
- `02-driver-app-navigation-and-entrypoints.md` - screen structure, home, bottom nav, profile, Benefits fit.
- `03-backend-api-integration.md` - Namma Yatri backend API patterns, auth, external-service calls, secrets.
- `04-keystone-catalog-api-fit.md` - Keystone API shape and how it maps to app features.
- `05-implementation-plan.md` - concrete integration plan, files likely touched, risks, open decisions.
- `06-ios-real-device-and-testflight-research.md` - public iOS evidence, TestFlight path, and current blockers.
- `08-payment-exploration.md` - existing driver payment technology, Juspay Payment Page flow, and recommended Keystone checkout architecture.

## Primary Code Anchors

- Driver PureScript package: `Frontend/ui-driver/package.json`.
- Driver PureScript entrypoint: `Frontend/ui-driver/src/Main.purs`.
- Driver flow router: `Frontend/ui-driver/src/Flow.purs`.
- Driver global app state: `Frontend/ui-driver/src/App.purs`.
- Home screen: `Frontend/ui-driver/src/Screens/HomeScreen`.
- Benefits screen: `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen`.
- PureScript API types: `Frontend/ui-driver/src/Services/API.purs`.
- PureScript API wrappers: `Frontend/ui-driver/src/Services/Backend.purs`.
- Shared cross-platform API bridge: `Frontend/ui-common/src/Services/CallAPI.js`.
- Driver backend UI API: `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/API/UI.hs`.
- Driver backend driver routes: `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/API/UI/Driver.hs`.
- Existing external call pattern: `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/SharedLogic/CallBAPInternal.hs`.
