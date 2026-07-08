# Backend API Integration

## Existing Driver Backend API Shape

The driver app talks to the provider platform backend through `/ui/...` APIs.

Important files:

- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/API.hs`
- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/API/UI.hs`
- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/API/UI/Driver.hs`

Driver-facing routes use `TokenAuth`. A representative route family is under `"driver"` in `API/UI/Driver.hs`.

Handlers typically delegate with `withFlowHandlerAPI` into `Domain.Action.UI.*`.

## Auth Model

Driver mobile authentication is token-based, not API-key-based.

Important file:

- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/Tools/Auth.hs`

`TokenAuth` verifies the driver token and returns identity context including:

- person/driver id.
- merchant id.
- merchant operating city id.

This is important for Keystone because catalog access can be gated by merchant, city, driver eligibility, vehicle category, or rollout config before any Keystone call is made.

## Why Backend Proxy Is Required

Keystone Catalog API requires:

```http
x-api-key: <partner_api_key>
```

That key should stay server-side. Putting it in the driver app would expose it in the APK/IPA/PureScript bundle and in client-side traffic.

Backend proxy benefits:

- Keeps Keystone API key secret.
- Preserves driver auth and authorization.
- Enables merchant/city rollout gates.
- Enables backend-side rate limits and audit logs.
- Allows key rotation without app releases.
- Allows response normalization and compatibility guarantees.
- Prevents arbitrary external use of Keystone API with an extracted mobile key.

## Existing External Service Patterns

Server-side outbound APIs are usually typed Servant clients near the integration.

Examples:

- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/SharedLogic/CallBAPInternal.hs`
- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/SharedLogic/External/LocationTrackingService/API`
- `Backend/app/provider-platform/dynamic-offer-driver-app/Main/src/SharedLogic/External/LocationTrackingService/Flow.hs`

`CallBAPInternal.hs` is especially relevant because it keeps an API key in backend config and sends it as a server-side header. Keystone should follow the same principle with `x-api-key`.

## Recommended Backend Module Shape

Use generated API routes if the endpoint shape fits NammaDSL:

- Add `Backend/app/provider-platform/dynamic-offer-driver-app/Main/spec/API/KeystoneCatalog.yaml`.
- Generate server types/handlers.
- Implement business logic in `Domain.Action.UI.KeystoneCatalog`.

If the generator becomes awkward for external proxy pass-through, use a small handwritten UI API module following the style of `API/UI/Driver.hs`, but prefer established generated routes when possible.

Suggested route shape:

```text
/ui/driver/keystone/categories
/ui/driver/keystone/products
/ui/driver/keystone/products/:slug
/ui/driver/keystone/search
```

All routes should use `TokenAuth`.

Suggested Haskell modules:

- `API.Action.UI.KeystoneCatalog` or `API.UI.KeystoneCatalog`
- `API.Types.UI.KeystoneCatalog`
- `Domain.Action.UI.KeystoneCatalog`
- `SharedLogic.External.KeystoneCommerce.API`
- `SharedLogic.External.KeystoneCommerce.Flow`

## Config And Secrets

The Keystone base URL and API key should be server-side config.

Possible config levels:

- Global service config in app `Environment` / Dhall config if one Keystone partner key applies to all enabled drivers.
- Merchant/city-scoped config through `merchant_service_config` if Namma Yatri deployments need different keys, enablement, or endpoints per merchant/city.

Recommendation: prefer merchant/city-scoped config if Keystone is not globally enabled across all driver merchants and cities.

Do not hardcode:

- `https://api.keystonecommerce.in/api/v1`
- partner API key
- rollout city list

## Response Normalization

Keystone returns an envelope:

```json
{
  "statusCode": 200,
  "message": "Success",
  "data": {},
  "meta": {}
}
```

The driver app does not need Keystone's entire envelope. The Namma Yatri backend can return driver-app-friendly DTOs:

- `CategoryTreeRes`
- `ProductListRes { products, meta }`
- `ProductDetailRes`
- `SearchRes`

Prices are strings in Keystone responses. The backend should either keep them as `Text` for display-only flows or parse/validate into a money type if any downstream arithmetic is introduced.

## Frontend API Wiring

Once backend proxy endpoints exist, the PureScript app should add:

- Request/response types in `Frontend/ui-driver/src/Services/API.purs`.
- Endpoint functions in `Frontend/ui-driver/src/Services/Endpoint.purs`.
- Backend wrapper functions in `Frontend/ui-driver/src/Services/Backend.purs`.
- Screen global event/load functions that call those wrappers.

Use the existing driver token/header path. The frontend should never send Keystone `x-api-key`.

