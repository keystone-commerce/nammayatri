# Driver App Navigation And Entry Points

## Navigation Model

Navigation is not React Navigation and not normal Android Fragment navigation. It is flow-driven in PureScript.

Core files:

- `Frontend/ui-driver/src/Main.purs` - app entrypoint.
- `Frontend/ui-driver/src/Flow.purs` - app flow and screen routing.
- `Frontend/ui-driver/src/App.purs` - global state and app-level screen output types.
- `Frontend/ui-driver/src/Screens/Handlers.purs` - screen handler registry.
- `Frontend/ui-driver/src/Screens/ScreenNames.purs` - screen names and analytics identifiers.
- `Frontend/ui-driver/src/ModifyScreenTypes.purs` - global state update plumbing.

Most screens follow this shape:

- `ScreenData.purs` - initial state and data model.
- `View.purs` - PrestoDOM UI tree.
- `Controller.purs` - actions, eval logic, screen outputs.
- `Handler.purs` - runs the screen and maps outputs to app-level outputs.
- Optional `ComponentConfig.purs`, `Transformer.purs`, `Types.purs`.

## Home Screen

Home is a map-first operational screen. It is not naturally a storefront page.

Core files:

- `Frontend/ui-driver/src/Screens/HomeScreen/View.purs`
- `Frontend/ui-driver/src/Screens/HomeScreen/Controller.purs`
- `Frontend/ui-driver/src/Screens/HomeScreen/Handler.purs`

`Flow.homeScreenFlow` in `Frontend/ui-driver/src/Flow.purs` calls `UI.homeScreen` and routes the resulting `HOME_SCREENOUTPUT`.

Existing Home entry surfaces include:

- Bottom nav.
- Online/offline map widgets.
- Quick action pill/tile rows.
- Banner carousel.
- Help/support, hotspots, open meter, go-to, ride requests, Aadhaar, alternate number.

Home already supports remote links through banner action handling. `HomeScreen.Controller` uses `openUrlInApp` for remote banner links and generic `OpenLink`.

## Bottom Nav

Bottom nav is defined in:

- `Frontend/ui-driver/src/Components/BottomNavBar/Controller.purs`
- `Frontend/ui-driver/src/Components/BottomNavBar/View.purs`

Structurally supported items are:

- Home.
- Earnings.
- Rides.
- Join.
- Rankings.
- Alert.

Visibility is driven by bottom nav config, but the item set and action handling are hardcoded enough that adding a new Keystone tab would touch many existing paths.

Recommendation: do not add a new bottom nav item for launch unless Keystone must be a top-level app pillar.

## Profile/Menu Entry

Profile menu is a lower-risk secondary entry surface.

Core files:

- `Frontend/ui-driver/src/Screens/DriverProfileScreen/Controller.purs`
- `Frontend/ui-driver/src/Screens/DriverProfileScreen/View.purs`
- `Frontend/ui-driver/src/Screens/Types.purs` for `MenuOptions`.

This is simple but likely too buried for storefront discovery.

## Benefits Screen Is The Best Initial Fit

Benefits/Rankings is the strongest existing conceptual fit for Keystone because it already aggregates driver benefits, rewards, partner-like flows, referral economics, learning modules, and external SDK/link patterns.

Core files:

- `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen/View.purs`
- `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen/Controller.purs`
- `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen/Handler.purs`
- `Frontend/ui-driver/src/Screens/Benefits/BenefitsScreen/ScreenData.purs`
- `Frontend/ui-driver/src/Flow.purs` around the `benefitsScreenFlow`.

Useful precedent:

- Benefits screen global events fetch backend data after render.
- Gullak uses feature/remote config, token caching, and an external SDK launch.
- Learn-and-earn modules render a list of cards.
- Namma Kutumba / reward-like cards are already in the benefits context.

Recommended first user-facing entry:

1. Add a Keystone storefront card/section in Benefits.
2. On tap, route to a dedicated Keystone storefront screen.
3. Optionally add a Home quick-entry tile after product validation.

## New Full Screen Wiring Checklist

A new Keystone storefront screen will likely need:

- New screen folder under `Frontend/ui-driver/src/Screens/KeystoneStorefrontScreen`.
- Screen state in `Frontend/ui-driver/src/App.purs` `GlobalState`.
- Default state in `defaultGlobalState`.
- `ScreenType` and `modifyScreenState` wiring.
- Screen name in `Screens/ScreenNames.purs`.
- Handler export in `Screens/Handlers.purs`.
- App-level screen output type in `App.purs`.
- Flow function and route handling in `Flow.purs`.
- Entry action in Benefits/Home/Profile controller.
- Localizable strings in the existing localization system.
- Assets through existing merchant asset helpers if static icons/banners are needed.

