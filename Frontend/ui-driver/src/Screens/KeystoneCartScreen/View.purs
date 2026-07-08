module Screens.KeystoneCartScreen.View where

import Prelude

import Animation as Anim
import Common.Types.App (LazyCheck(..))
import Components.GenericHeader as GenericHeader
import Components.GenericHeader.Controller as GHC
import Components.PrimaryButton as PrimaryButton
import Data.Array as DA
import Data.Int as DI
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (fromString) as Number
import Data.Number.Format (fixed, toStringWith)
import Effect (Effect)
import Effect.Unsafe (unsafePerformEffect)
import Font.Style as FontStyle
import Helpers.Utils as HU
import PrestoDOM
import PrestoDOM.Animation as PrestoAnim
import Screens.KeystoneCartScreen.Controller (Action(..), ScreenOutput, eval) as KCC
import Screens.Types (KeystoneCartItem, KeystoneCartScreenState)
import Services.KeystoneCart as Cart
import Styles.Colors as Color

screen :: KeystoneCartScreenState -> LoggableScreen KCC.Action KeystoneCartScreenState KCC.ScreenOutput
screen initialState =
  { initialState
  , view
  , name: "KeystoneCartScreen"
  , parent: Nothing
  , logWhitelist: []
  , globalEvents:
      [ ( \push -> do
            cart <- Cart.getCart
            push (KCC.UpdateCart cart)
            pure (pure unit)
        )
      ]
  , eval:
      ( \action state ->
          let _ = unsafePerformEffect (handleSideEffects action state)
          in KCC.eval action state
      )
  }

handleSideEffects :: KCC.Action -> KeystoneCartScreenState -> Effect Unit
handleSideEffects action _ =
  case action of
    KCC.IncrementItem slug -> do
      cart <- Cart.getCart
      case DA.find (\i -> i.slug == slug) cart of
        Just item -> void $ Cart.updateQuantity slug (item.quantity + 1)
        _ -> pure unit
    KCC.DecrementItem slug -> do
      cart <- Cart.getCart
      case DA.find (\i -> i.slug == slug) cart of
        Just item -> void $ Cart.updateQuantity slug (item.quantity - 1)
        _ -> pure unit
    KCC.RemoveItem slug -> void $ Cart.removeFromCart slug
    _ -> pure unit

view :: forall w. (KCC.Action -> Effect Unit) -> KeystoneCartScreenState -> PrestoDOM (Effect Unit) w
view push state =
  PrestoAnim.animationSet [ Anim.fadeIn true ] $
    linearLayout
      [ height MATCH_PARENT
      , width MATCH_PARENT
      , orientation VERTICAL
      , background Color.grey700
      , onBackPressed push (const KCC.BackPressed)
      ]
      [ headerView push
      , bodyView push state
      , footerView state
      , bottomStoreNavView push (cartTotalQty state.data.cart)
      ]

headerView :: forall w. (KCC.Action -> Effect Unit) -> PrestoDOM (Effect Unit) w
headerView push =
  linearLayout
    [ width MATCH_PARENT
    , height WRAP_CONTENT
    , orientation HORIZONTAL
    , gravity CENTER_VERTICAL
    , padding (Padding 4 4 16 4)
    , background Color.white900
    , stroke ("1," <> Color.grey900)
    ]
    [ GenericHeader.view (push <<< KCC.GenericHeaderAction) (cartHeaderConfig "Your Cart") ]

cartHeaderConfig :: String -> GHC.Config
cartHeaderConfig title =
  let cfg = GHC.config
  in cfg
       { height = WRAP_CONTENT
       , width = MATCH_PARENT
       , prefixImageConfig = cfg.prefixImageConfig
           { height = V 25
           , width = V 25
           , imageUrl = "ny_ic_chevron_left"
           , margin = Margin 8 8 8 8
           , visibility = VISIBLE
           }
       , textConfig = cfg.textConfig
           { text = title
           , color = Color.black800
           }
       , suffixImageConfig = cfg.suffixImageConfig { visibility = GONE }
       }

bodyView :: forall w. (KCC.Action -> Effect Unit) -> KeystoneCartScreenState -> PrestoDOM (Effect Unit) w
bodyView push state =
  scrollView
    [ height MATCH_PARENT
    , width MATCH_PARENT
    , weight 1.0
    , scrollBarY false
    , background Color.grey700
    ]
    [ if DA.null state.data.cart then emptyCartView push
      else linearLayout
             [ height WRAP_CONTENT
             , width MATCH_PARENT
             , orientation VERTICAL
             , padding (Padding 16 16 16 24)
             ]
             (map (cartItemRow push) state.data.cart)
    ]

emptyCartView :: forall w. (KCC.Action -> Effect Unit) -> PrestoDOM (Effect Unit) w
emptyCartView push =
  linearLayout
    [ height MATCH_PARENT
    , width MATCH_PARENT
    , orientation VERTICAL
    , gravity CENTER
    , background Color.white900
    , padding (Padding 32 64 32 64)
    ]
    [ linearLayout
        [ height (V 96)
        , width (V 96)
        , gravity CENTER
        , cornerRadius 48.0
        , background Color.grey700
        ]
        [ imageView
            [ height (V 48)
            , width (V 48)
            , imageWithFallback (HU.fetchImage HU.FF_ASSET "ny_ic_baggage")
            ]
        ]
    , textView
        $ [ text "Your cart is empty"
          , color Color.black800
          , margin (MarginTop 20)
          , gravity CENTER
          ]
        <> FontStyle.h2 TypoGraphy
    , textView
        $ [ text "Browse the Keystone Store and add items to your cart."
          , color Color.black700
          , margin (MarginTop 8)
          , gravity CENTER
          , singleLine false
          ]
        <> FontStyle.body3 TypoGraphy
    , linearLayout
        [ height (V 44)
        , width WRAP_CONTENT
        , gravity CENTER
        , margin (MarginTop 24)
        , padding (Padding 24 0 24 0)
        , cornerRadius 22.0
        , background Color.black900
        , onClick push (const KCC.ContinueShopping)
        ]
        [ textView
            $ [ text "Browse store"
              , color Color.white900
              , gravity CENTER
              ]
            <> FontStyle.subHeading1 TypoGraphy
        ]
    ]

cartItemRow :: forall w. (KCC.Action -> Effect Unit) -> KeystoneCartItem -> PrestoDOM (Effect Unit) w
cartItemRow push item =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , padding (Padding 12 12 12 12)
    , margin (MarginBottom 12)
    , background Color.white900
    , cornerRadius 12.0
    ]
    [ linearLayout
        [ height (V 80)
        , width (V 80)
        , gravity CENTER
        , cornerRadius 8.0
        , background Color.grey700
        ]
        [ imageView
            [ height (V 72)
            , width (V 72)
            , imageWithFallback ("," <> item.image)
            ]
        ]
    , linearLayout
        [ height WRAP_CONTENT
        , width MATCH_PARENT
        , weight 1.0
        , orientation VERTICAL
        , margin (MarginLeft 12)
        ]
        [ linearLayout
            [ height WRAP_CONTENT
            , width MATCH_PARENT
            , orientation HORIZONTAL
            ]
            [ linearLayout
                [ height WRAP_CONTENT
                , width MATCH_PARENT
                , weight 1.0
                , orientation VERTICAL
                ]
                [ textView
                    $ [ text item.name
                      , color Color.black800
                      , maxLines 2
                      ]
                    <> FontStyle.body1 TypoGraphy
                , textView
                    $ [ text item.brand
                      , color Color.black700
                      , margin (MarginTop 2)
                      ]
                    <> FontStyle.body4 TypoGraphy
                ]
            , imageView
                [ height (V 20)
                , width (V 20)
                , margin (MarginLeft 8)
                , imageWithFallback (HU.fetchImage HU.FF_ASSET "ny_ic_bin_black")
                , onClick push (const (KCC.RemoveItem item.slug))
                ]
            ]
        , linearLayout
            [ height WRAP_CONTENT
            , width MATCH_PARENT
            , orientation HORIZONTAL
            , gravity CENTER_VERTICAL
            , margin (MarginTop 10)
            ]
            [ textView
                $ [ text ("Rs. " <> item.defaultSellingPrice)
                  , color Color.black800
                  , weight 1.0
                  ]
                <> FontStyle.subHeading1 TypoGraphy
            , quantityStepper push item
            ]
        ]
    ]

quantityStepper :: forall w. (KCC.Action -> Effect Unit) -> KeystoneCartItem -> PrestoDOM (Effect Unit) w
quantityStepper push item =
  linearLayout
    [ height WRAP_CONTENT
    , width WRAP_CONTENT
    , orientation HORIZONTAL
    , gravity CENTER_VERTICAL
    , stroke ("1," <> Color.grey900)
    , cornerRadius 18.0
    , padding (Padding 4 4 4 4)
    ]
    [ stepperBtn push (KCC.DecrementItem item.slug) "ny_ic_minus_dec"
    , textView
        $ [ text (show item.quantity)
          , color Color.black800
          , gravity CENTER
          , width (V 32)
          ]
        <> FontStyle.subHeading1 TypoGraphy
    , stepperBtn push (KCC.IncrementItem item.slug) "ny_ic_plus_inc"
    ]

stepperBtn :: forall w. (KCC.Action -> Effect Unit) -> KCC.Action -> String -> PrestoDOM (Effect Unit) w
stepperBtn push action icon =
  linearLayout
    [ height (V 28)
    , width (V 28)
    , gravity CENTER
    , cornerRadius 14.0
    , background Color.grey800
    , onClick push (const action)
    ]
    [ imageView
        [ height (V 12)
        , width (V 12)
        , imageWithFallback (HU.fetchImage HU.FF_ASSET icon)
        ]
    ]

footerView :: forall w. KeystoneCartScreenState -> PrestoDOM (Effect Unit) w
footerView state =
  if DA.null state.data.cart then linearLayout [ visibility GONE ] []
  else
    linearLayout
      [ height WRAP_CONTENT
      , width MATCH_PARENT
      , padding (Padding 16 16 16 16)
      , background Color.white900
      , stroke ("1," <> Color.grey900)
      , orientation VERTICAL
      ]
      [ totalRow state
      , linearLayout
          [ height WRAP_CONTENT
          , width MATCH_PARENT
          , orientation HORIZONTAL
          , gravity CENTER_VERTICAL
          , background Color.grey700
          , cornerRadius 8.0
          , padding (Padding 10 8 10 8)
          , margin (MarginVertical 12 12)
          ]
          [ imageView
              [ height (V 16)
              , width (V 16)
              , imageWithFallback (HU.fetchImage HU.FF_ASSET "ny_ic_info_black")
              , margin (MarginRight 8)
              ]
          , textView
              $ [ text "Online checkout coming soon"
                , color Color.black700
                , singleLine false
                , weight 1.0
                ]
              <> FontStyle.body4 TypoGraphy
          ]
      , PrimaryButton.view (\_ -> pure unit) placeOrderButtonConfig
      ]

totalRow :: forall w. KeystoneCartScreenState -> PrestoDOM (Effect Unit) w
totalRow state =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , gravity CENTER_VERTICAL
    ]
    [ textView
        $ [ text "Total"
          , color Color.black800
          , weight 1.0
          ]
        <> FontStyle.subHeading1 TypoGraphy
    , textView
        $ [ text ("Rs. " <> formatTotal state.data.cart)
          , color Color.black800
          ]
        <> FontStyle.h2 TypoGraphy
    ]

formatTotal :: Array KeystoneCartItem -> String
formatTotal items =
  let
    sumValue = DA.foldl (\acc item -> acc + (parsePrice item.defaultSellingPrice) * (DI.toNumber item.quantity)) 0.0 items
  in toStringWith (fixed 2) sumValue

parsePrice :: String -> Number
parsePrice s = fromMaybe 0.0 (Number.fromString s)

placeOrderButtonConfig :: PrimaryButton.Config
placeOrderButtonConfig =
  let cfg = PrimaryButton.config
  in cfg
       { textConfig = cfg.textConfig
           { text = "Place Order"
           , color = Color.white900
           }
       , margin = MarginVertical 0 0
       , background = Color.black900
       , height = V 48
       , width = MATCH_PARENT
       , id = "KeystoneCartPlaceOrder"
       , isClickable = false
       , alpha = 0.4
       , cornerRadius = 12.0
       }

cartTotalQty :: Array KeystoneCartItem -> Int
cartTotalQty = DA.foldl (\acc item -> acc + item.quantity) 0

cartCountLabel :: Int -> String
cartCountLabel totalQty =
  if totalQty > 99 then "99+" else show totalQty

bottomStoreNavView :: forall w. (KCC.Action -> Effect Unit) -> Int -> PrestoDOM (Effect Unit) w
bottomStoreNavView push totalQty =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , background Color.white900
    , stroke ("1," <> Color.grey900)
    , padding (Padding 8 8 8 10)
    ]
    [ bottomNavItem push "Shop" false (KCC.SelectStoreTab "shop") ""
    , bottomNavItem push "Categories" false (KCC.SelectStoreTab "categories") ""
    , bottomNavItem push "Cart" true KCC.NoAction (cartCountLabel totalQty)
    ]

bottomNavItem :: forall w. (KCC.Action -> Effect Unit) -> String -> Boolean -> KCC.Action -> String -> PrestoDOM (Effect Unit) w
bottomNavItem push label active action badge =
  linearLayout
    [ height (V 54)
    , width (V 0)
    , weight 1.0
    , orientation VERTICAL
    , gravity CENTER
    , cornerRadius 12.0
    , background (if active then Color.blue600 else Color.white900)
    , onClick push (const action)
    ]
    [ textView
        $ [ text (bottomNavLabel label badge)
          , color (if active then Color.blue900 else Color.black700)
          , gravity CENTER
          , maxLines 1
          ]
        <> FontStyle.body4 TypoGraphy
    ]

bottomNavLabel :: String -> String -> String
bottomNavLabel label badge =
  if badge /= "" && badge /= "0" then label <> ": " <> badge else label
