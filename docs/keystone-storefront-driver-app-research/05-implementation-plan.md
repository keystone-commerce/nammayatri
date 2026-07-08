# Keystone Storefront Implementation Plan

## Phase 0 - Product Decisions

Resolve before implementation:

- Is this strictly driver-facing for launch? This research assumes yes.
- Is Keystone visible to all drivers or only selected merchants/cities/vehicle categories?
- What is the first checkout behavior if orders/payments are not in the API?
- Is a Keystone-hosted checkout/web URL available, or is launch browse-only?
- What should the storefront entry label be in driver languages?
- Who owns catalog analytics: Keystone, Namma Yatri, or both?

## Phase 1 - Backend Proxy

Add authenticated driver UI endpoints that proxy Keystone catalog calls.

Recommended routes:

```text
GET /ui/driver/keystone/categories
GET /ui/driver/keystone/products?page=&limit=&search=&categoryId=&brand=&sortBy=&sortOrder=
GET /ui/driver/keystone/products/:slug
GET /ui/driver/keystone/search?q=&type=&limit=&source=
```

Implementation:

- Add API spec or handwritten API module.
- Add request/response DTOs.
- Add `Domain.Action.UI.KeystoneCatalog`.
- Add outbound typed Servant client under `SharedLogic.External.KeystoneCommerce`.
- Read Keystone base URL and API key from backend config.
- Gate access by merchant/city/config.
- Normalize errors into app-friendly failures.

Verification:

- Unit-level decode tests if a local test pattern exists.
- Manual call through local backend with a driver token.
- Confirm Keystone key is never in frontend files, Android resources, logs, or response payloads.

## Phase 2 - Frontend API Client

Add PureScript client bindings to the Namma Yatri backend proxy.

Files likely touched:

- `Frontend/ui-driver/src/Services/API.purs`
- `Frontend/ui-driver/src/Services/Endpoint.purs`
- `Frontend/ui-driver/src/Services/Backend.purs`

Patterns to follow:

- Existing `RestEndpoint` instances in `Services/API.purs`.
- Existing `getHeaders` and `withAPIResultBT` wrappers in `Services/Backend.purs`.
- Existing endpoint URL construction in `Services/Endpoint.purs`.

This client code is shared by Android and iOS because it lives in `Frontend/ui-driver` and uses the shared `Frontend/ui-common` JBridge API runner. iOS-specific request encoding is already handled in `Frontend/ui-common/src/Services/CallAPI.js`.

## Phase 3 - Storefront Screen

Add a new PureScript screen:

```text
Frontend/ui-driver/src/Screens/KeystoneStorefrontScreen/
  Controller.purs
  Handler.purs
  ScreenData.purs
  View.purs
  ComponentConfig.purs       # if needed
  Transformer.purs           # if needed
```

Initial screen capabilities:

- Load categories and first product page.
- Category selection.
- Product grid/list.
- Search.
- Product detail route or modal.
- Loading, empty, error, retry states.
- Image fallback.
- Pagination.

Avoid adding cart/checkout UI until Keystone order/payment APIs or a web checkout flow exists.

The same screen should render on both driver Android and driver iOS. Do not create separate native Android/iOS storefront screens unless a platform bridge limitation is discovered.

## Phase 4 - Entry Points

Recommended launch entry:

- Add a Keystone card/section in `BenefitsScreen`.
- On click, route to the new Keystone storefront screen.

Optional stronger discovery:

- Add a Home quick-entry tile that routes to the same screen.

Avoid initially:

- New bottom nav item.
- Deep Android-native screen.
- Direct Keystone webview with exposed API key.

## Phase 5 - Feature Gating And Localization

Feature gate by:

- Merchant.
- Operating city.
- App config/remote config.
- Driver eligibility if needed.

Add localization through existing systems:

- `Frontend/ui-driver/src/Resource/Localizable/Strings.purs`
- `Frontend/ui-driver/src/Resource/LocalizableV2/TypesV2.purs`
- `Frontend/ui-driver/src/Resource/LocalizableV2/StringsV2.purs`

Use existing asset helpers if static Keystone icons/banners are needed.

## Phase 6 - Observability

Track at minimum:

- Storefront entry click.
- Category selected.
- Product list loaded.
- Product card clicked.
- Search submitted.
- Product detail opened.
- External checkout/web CTA clicked, if any.
- API load failure.

Keystone `/search` supports `source`; set it server-side to a stable value such as `ny-driver-app`.

## Phase 7 - iOS Packaging And Parity

Before claiming iOS support, identify the actual iOS host source or release pipeline. This checkout does not include an Xcode project or native iOS host code.

Required iOS checks:

- Add or recover `Frontend/ui-driver/webpack.ios.js`; `package.json` references it but it is missing here.
- Confirm how the iOS host sets `window.__OS = "IOS"` and injects `window.JBridge`.
- Confirm `JBridge.callAPI` on iOS accepts the base64-encoded body/header format used by `Frontend/ui-common/src/Services/CallAPI.js`.
- Verify remote product images render correctly in iOS PrestoDOM image components.
- Verify `openUrlInApp` behavior if checkout or product CTAs use external links.
- Test screen layout on small iPhones, large iPhones, safe areas, dynamic text, and slow networks.
- Confirm bundle publication/update flow for the iOS driver app.

Expected outcome: one shared PureScript storefront implementation, two platform bundle/release validations.

## Risks

### Secret Leakage

Risk: Keystone `x-api-key` ends up in mobile app code or logs.

Mitigation: backend proxy only; server-side config only; log redaction.

### Missing Checkout

Risk: users can browse but cannot buy.

Mitigation: product-align on browse-only vs web checkout vs waiting for orders/payments API.

### App Flow Blast Radius

Risk: adding top-level nav creates regressions across home, bottom nav, and flow routing.

Mitigation: Benefits card first; add Home tile later.

### iOS Packaging Gap

Risk: the shared storefront compiles but cannot be packaged for driver iOS from this checkout because the native iOS host and driver `webpack.ios.js` are missing.

Mitigation: locate the iOS host repository or restore the missing driver iOS Webpack config before implementation planning is finalized.

### API Spec Mismatch

Risk: Mintlify OpenAPI is not Keystone catalog.

Mitigation: use Markdown docs and sample payloads until a real OpenAPI spec is published.

### Price Handling

Risk: price values are strings and may be mishandled if arithmetic is introduced.

Mitigation: treat prices as display text for catalog-only phase; parse to money type only when needed.

### Image Quality And Load Failure

Risk: product images are remote GCS URLs and may fail or be slow.

Mitigation: image fallback, fixed aspect ratios, lazy loading/pagination.

## Suggested First Engineering Milestone

Deliver a browse-only Keystone storefront behind a feature flag:

1. Backend proxy for categories, products, product detail, search.
2. PureScript storefront screen.
3. Benefits card entry.
4. Product detail with a disabled or informational CTA until checkout path is finalized.
5. Analytics and error handling.
6. Android and iOS bundle verification.

This milestone proves the integration, keeps the API key safe, and avoids premature checkout UI before Keystone exposes order/payment APIs.
