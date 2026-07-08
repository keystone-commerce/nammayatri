# Payment Exploration

Date: 2026-05-07

Scope: driver-facing Namma Yatri app payment flow, with the goal of reusing the same payment experience for Keystone Store checkout while Keystone/Namma Yatri owns order, payment report, reconciliation, and settlement records.

## Summary

The driver app already uses Juspay in two different ways:

- Juspay HyperSDK is part of the Android app runtime and bridge layer.
- Juspay Hyperpay / Payment Page is used for in-app payment checkout flows such as subscription payments, clearing dues, invoice payments, and payout/UPI registration flows.

For Keystone checkout, the recommended integration is to reuse the existing Payment Page invocation path. The app should not receive only a payment link or raw payment session id. For the smooth native checkout, the app should receive the same kind of Juspay SDK payload that existing driver payment APIs already return.

The backend should create the Keystone order and payment session/order, then return a `CreateOrderRes`-shaped response to the app:

```json
{
  "sdk_payload": { "...": "Juspay Payment Page payload" },
  "sdk_payload_json": { "...": "optional raw payload" },
  "id": "juspay/payment-service-order-id",
  "order_id": "display/order short id",
  "payment_links": {
    "web": null,
    "iframe": null,
    "mobile": null
  }
}
```

The app can then call the existing Payment Page helpers and poll a Keystone-owned backend status endpoint.

## Existing Driver Payment Flow

Current high-level flow:

1. Driver taps a payment action in the app.
2. App calls the Namma Yatri backend.
3. Backend creates or reuses a payment order with the configured payment provider.
4. Backend returns a Juspay Payment Page SDK payload.
5. App starts/initiates Juspay Payment Page and passes the SDK payload.
6. Payment Page returns control to the app.
7. App asks backend for order status.
8. Backend reconciles with payment provider status and updates internal invoice/fee/subscription/payout state.

Important app-side code anchors:

- `Frontend/android-native/app/build.gradle`
  - Includes `in.juspay:hypersdk`, `hyperqr`, and `hypersmshandler`.
- `Frontend/android-native/mobility-common/src/main/java/in/juspay/mobility/common/PaymentPage.java`
  - Native Android wrapper around `HyperServices`.
  - Calls `hyperInstance.initiate(...)` and `hyperInstance.process(...)`.
- `Frontend/ui-common/src/Payment/PaymentPage.purs`
  - Defines `PaymentPagePayload` and `PayPayload`.
  - Exposes `initiatePaymentPage` and `paymentPageUI`.
- `Frontend/ui-common/src/Payment/PaymentPage.js`
  - Starts Hyperpay microapp service `in.juspay.hyperpay`.
  - Calls `JBridge.initiatePP(...)` and `JBridge.processPP(...)` where available.
- `Frontend/ui-driver/src/Services/API.purs`
  - Defines `CreateOrderRes`, `PaymentLinks`, and `OrderStatusRes`.
- `Frontend/ui-driver/src/Services/Endpoint.purs`
  - Defines app endpoints such as `/payment/:id/createOrder`, `/payment/:orderId/status`, `/payment/dues`, and `/driver/cleardues`.
- `Frontend/ui-driver/src/Flow.purs`
  - Uses the Payment Page flow for clear dues, plan subscription, invoice payments, and payout registration.

Important backend-side code anchors:

- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/API/UI/Payment.hs`
  - Exposes driver payment create-order/status routes.
- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/Domain/Action/UI/Payment.hs`
  - Driver-facing payment actions and status handling.
- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/SharedLogic/Payment.hs`
  - Builds driver fee/invoice payment order requests and delegates to shared payment service.
- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/Tools/Payment.hs`
  - Resolves merchant service config and chooses payment provider/service.
- `Backend/lib/payment/src/Lib/Payment/Domain/Action.hs`
  - Shared payment order creation, SDK payload rebuild, payment order persistence, and status lookup.
- `Backend/lib/payment/src/Lib/Payment/Domain/Types/PaymentOrder.hs`
  - Payment order domain model, including `paymentServiceOrderId`, `clientAuthToken`, `clientAuthTokenExpiry`, `paymentLinks`, `serviceProvider`, and `sdkPayloadDump`.

## What The App Needs For Smooth Checkout

The existing app flow expects a complete Payment Page payload, not only a link.

The payload contains fields such as:

- `clientAuthToken`
- `clientAuthTokenExpiry`
- `merchantId`
- `clientId`
- `amount`
- `currency`
- `orderId`
- `customerId`
- `customerPhone`
- `customerEmail`
- `environment`
- optional mandate fields

This is why returning only a payment link is a weaker fit. A link can still work as a fallback by opening a browser/custom tab/webview, but it will not reuse the native Payment Page path as cleanly.

Returning only a session id is also insufficient unless the app can exchange that session id for the full SDK payload. The better contract is for the backend to return the final SDK payload directly.

## Recommended Keystone Checkout Architecture

Use a Keystone-owned backend checkout layer that speaks the same shape as existing driver payment APIs.

Recommended flow:

1. Driver opens Keystone Store in the driver app.
2. Driver selects product and quantity.
3. App calls Keystone/Namma Yatri backend endpoint such as:

```text
POST /ui/driver/keystone/orders
POST /ui/driver/keystone/orders/:orderId/payment
GET  /ui/driver/keystone/orders/:orderId/payment/status
```

4. Backend validates driver, merchant, city, products, price, availability, shipping assumptions, and feature eligibility.
5. Backend creates Keystone order records.
6. Backend creates a Juspay payment order/session using the same configured payment technology.
7. Backend returns a `CreateOrderRes`-compatible payload.
8. App calls existing `initiatePaymentPage` and `paymentPageUI`.
9. App polls Keystone payment status endpoint or returns to order detail screen.
10. Backend uses webhooks/status polling to reconcile final payment state and maintain Keystone payment reports.

This keeps payment secrets, API keys, settlement data, and reconciliation server-side while preserving the same driver-app checkout UX.

## Suggested Frontend Contract

The Keystone payment endpoint should either reuse `CreateOrderRes` exactly or define a thin wrapper around it:

```purescript
newtype KeystoneCreatePaymentRes = KeystoneCreatePaymentRes
  { orderId :: String
  , keystoneOrderId :: String
  , orderResp :: CreateOrderRes
  }
```

Frontend use should mirror existing flows:

```purescript
liftFlowBT $ initiatePaymentPage
response <- lift $ lift $ Remote.createKeystonePayment keystoneOrderId
case response of
  Right (KeystoneCreatePaymentRes res) -> do
    let (CreateOrderRes orderResp) = res.orderResp
    lift $ lift $ doAff $ makeAff \cb -> runEffectFn1 checkPPInitiateStatus (cb <<< Right) $> nonCanceler
    let sdkPayload = maybe (encodeJSON orderResp.sdk_payload) (addLanguageToPayload lang) orderResp.sdk_payload_json
    void $ paymentPageUI sdkPayload
    paymentStatus <- lift $ lift $ Remote.keystonePaymentStatus res.orderId
    -- update order detail / success / failure UI
  Left err ->
    toast $ Remote.getCorrespondingErrorMessage err
```

Do not put payment provider secrets, Keystone API keys, or client auth token creation logic in `Frontend/ui-driver`.

## Backend Responsibilities For Keystone

Keystone payment backend should own:

- Keystone order id and line items.
- Final payable amount, currency, tax, delivery, discounts, and fees.
- Driver identity and merchant/city eligibility checks.
- Payment order creation with Juspay or the configured provider.
- Payment status endpoint for app polling.
- Webhook ingestion and idempotent reconciliation.
- Payment reports.
- Refund/cancellation handling.
- Settlement mapping.
- Audit logs.

For Namma Yatri compatibility, backend should persist enough identifiers to join:

- Keystone order id.
- App/user driver id.
- Payment provider order id.
- Payment short id shown to user.
- Payment status.
- Gateway transaction id, if returned.
- Amount and currency.
- Created/updated timestamps.

## Provider Choice

The codebase has provider abstraction for multiple payment services, including Juspay, AAJuspay, Stripe, Paytm EDC, wallet, and payout flows. For the Indian driver app path, the existing app-side checkout integration is Juspay Hyperpay / Payment Page.

If Keystone wants the same smooth driver-app experience, use Juspay Payment Page payloads rather than a standalone web payment link.

If Keystone later needs a different provider, the app contract should still stay backend-driven. The mobile app should not become provider-aware beyond receiving and invoking the supported checkout payload.

## Implementation Notes

- Keep the current browse-only storefront until order/payment APIs are ready.
- Add Keystone cart/product detail UI first, but keep the buy CTA gated until backend checkout exists.
- Reuse existing payment status handling patterns from `Flow.purs`.
- Add Keystone-specific analytics:
  - checkout started
  - payment page opened
  - payment success
  - payment failed
  - payment pending
  - checkout abandoned/back pressed
- Avoid directly opening Keystone-hosted pages unless using them as an intentional interim fallback.

## Main Decision

For Keystone Store, the target integration should be:

```text
Keystone app UI -> Keystone/Namma Yatri backend checkout -> Juspay order/session -> SDK payload -> existing driver Payment Page -> backend status/reconciliation
```

This gives the same checkout technology and app smoothness as existing driver payments while allowing Keystone to own payment reports and operational records.
