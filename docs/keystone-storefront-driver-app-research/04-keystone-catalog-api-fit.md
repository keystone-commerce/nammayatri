# Keystone Catalog API Fit

## Documentation Source

The documentation index is:

```text
https://keystonecommerce.mintlify.app/llms.txt
```

The index currently points to:

- `https://keystonecommerce.mintlify.app/catalog-api.md`
- `https://keystonecommerce.mintlify.app/api-reference/openapi.json`

The Markdown catalog API matches the user-provided docs and should be treated as source of truth.

The OpenAPI JSON currently appears to be a generic Mintlify sample plant-store spec, not the Keystone catalog API. Do not generate clients from that OpenAPI file until Keystone publishes the correct spec.

## Base URL

```text
https://api.keystonecommerce.in/api/v1
```

## Auth

Catalog endpoints require:

```http
x-api-key: <partner_api_key>
```

The API key identifies the partner. Do not send `partnerId` in URL, query params, or request body.

## Endpoints

### Health

```http
GET /health
```

No auth required.

Use for backend observability or startup diagnostics, not for every mobile screen load.

### Categories

```http
GET /categories
x-api-key: <partner_api_key>
```

Returns active category tree.

Mobile mapping:

- Parent category tabs or sections.
- Child category chips/filters.
- Use `categoryId` for product filtering.

### Products

```http
GET /products
x-api-key: <partner_api_key>
```

Supported query params:

- `page`
- `limit`, default 20, max 100.
- `search`
- `categoryId`
- `brand`
- `sortBy`
- `sortOrder`, `asc` or `desc`.

Mobile mapping:

- Infinite scroll / paginated list.
- Category filter.
- Brand filter if useful later.
- Search box can use either `/products?search=` or `/search`.

### Product Detail

```http
GET /products/:slug
x-api-key: <partner_api_key>
```

Mobile mapping:

- Product detail page.
- Image carousel.
- MRP and selling price.
- Description.
- Brand/SKU/category.

### Search

```http
GET /search?q=<term>&type=<products|categories|all>&limit=<n>&source=<source>
x-api-key: <partner_api_key>
```

Mobile mapping:

- Global storefront search.
- Typeahead or full search results.
- Set `source` server-side, for example `ny-driver-app`, if Keystone wants analytics attribution.

## Current Feature Boundary

Keystone explicitly excludes these from this release:

- Orders.
- Payments.
- Coupons.

This matters for Namma Yatri product planning. The current integration cannot complete a native purchase lifecycle unless another Keystone API or web checkout flow exists.

## Storefront UX That Fits The API

Supported now:

- Store landing with highlighted categories and first page of products.
- Category browsing.
- Product listing.
- Product detail.
- Search.
- Deep links into product detail by slug, if later needed.

Not supported natively by current API:

- Cart.
- Checkout.
- Order history.
- Payment status.
- Coupons.
- Returns/cancellations.

## Data Model Notes

Category:

- `id`
- `name`
- `slug`
- `description`
- `parentId`
- `isActive`
- `sortOrder`
- `children`

Product list item:

- `id`
- `name`
- `slug`
- `brand`
- `sku`
- `categoryId`
- `defaultMrp`
- `defaultSellingPrice`
- `images`
- `isActive`

Product detail adds:

- `description`

Search returns products and categories with lightweight fields.

## Reliability Notes

Backend should handle:

- Keystone timeout.
- Non-200 status.
- Envelope decode failure.
- Empty `data`.
- Product image failures in frontend.
- Pagination end state.
- Search debounce and cancellation in frontend.

