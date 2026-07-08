module Screens.KeystoneProductDetailScreen.View where

import Prelude

import Animation as Anim
import Common.Types.App (LazyCheck(..))
import Components.GenericHeader as GenericHeader
import Components.GenericHeader.Controller as GHC
import Components.PrimaryButton as PrimaryButton
import Control.Monad.Except (runExceptT)
import Control.Monad.Trans.Class (lift)
import Control.Transformers.Back.Trans (runBackT)
import Data.Array as DA
import Data.Maybe (Maybe(..), fromMaybe)
import Effect (Effect)
import Effect.Aff (launchAff)
import Effect.Class (liftEffect)
import Effect.Unsafe (unsafePerformEffect)
import Engineering.Helpers.Commons (flowRunner)
import Font.Style as FontStyle
import Helpers.Utils as HU
import JBridge as JB
import Presto.Core.Types.Language.Flow (doAff)
import PrestoDOM
import PrestoDOM.Animation as PrestoAnim
import Screens.KeystoneProductDetailScreen.Controller (Action(..), ScreenOutput, eval) as KPC
import Screens.Types (KeystoneCartItem, KeystoneProductDetail, KeystoneProductDetailScreenState)
import Services.Backend as Remote
import Services.KeystoneCart as Cart
import Styles.Colors as Color
import Types.App (defaultGlobalState)

screen :: KeystoneProductDetailScreenState -> LoggableScreen KPC.Action KeystoneProductDetailScreenState KPC.ScreenOutput
screen initialState =
  { initialState
  , view
  , name: "KeystoneProductDetailScreen"
  , parent: Nothing
  , logWhitelist: []
  , globalEvents:
      [ ( \push -> do
            cart <- Cart.getCart
            push (KPC.UpdateCart cart)
            case initialState.data.product of
              Nothing ->
                void $ launchAff $ flowRunner defaultGlobalState $ runExceptT $ runBackT do
                  result <- Remote.fetchKeystoneProductBySlugBT initialState.data.slug
                  lift $ lift $ doAff do liftEffect $ push (KPC.UpdateProduct result)
              Just _ -> pure unit
            pure (pure unit)
        )
      ]
  , eval:
      ( \action state ->
          let _ = unsafePerformEffect (handleSideEffects action state)
          in KPC.eval action state
      )
  }

handleSideEffects :: KPC.Action -> KeystoneProductDetailScreenState -> Effect Unit
handleSideEffects action state =
  case action of
    KPC.AddToCartClicked -> case state.data.product of
      Just product -> do
        let item =
              { slug: product.slug
              , name: product.name
              , brand: product.brand
              , image: fromMaybe "" (DA.head product.images)
              , defaultMrp: product.defaultMrp
              , defaultSellingPrice: product.defaultSellingPrice
              , quantity: state.props.quantity
              }
        _ <- Cart.addToCart item
        _ <- pure $ JB.toast (show state.props.quantity <> "x " <> product.name <> " added to cart")
        pure unit
      Nothing -> pure unit
    _ -> pure unit

view :: forall w. (KPC.Action -> Effect Unit) -> KeystoneProductDetailScreenState -> PrestoDOM (Effect Unit) w
view push state =
  PrestoAnim.animationSet [ Anim.fadeIn true ] $
    linearLayout
      [ height MATCH_PARENT
      , width MATCH_PARENT
      , orientation VERTICAL
      , background Color.white900
      , onBackPressed push (const KPC.BackPressed)
      ]
      [ headerView push state
      , bodyView push state
      , footerView push state
      , bottomStoreNavView push (cartTotalQty state.data.cart)
      ]

headerView :: forall w. (KPC.Action -> Effect Unit) -> KeystoneProductDetailScreenState -> PrestoDOM (Effect Unit) w
headerView push state =
  let totalQty = DA.foldl (\acc item -> acc + item.quantity) 0 state.data.cart
      title = case state.data.product of
        Just p -> p.name
        Nothing -> "Product"
  in linearLayout
       [ width MATCH_PARENT
       , height WRAP_CONTENT
       , orientation HORIZONTAL
       , gravity CENTER_VERTICAL
       , padding (Padding 4 4 12 4)
       , background Color.white900
       , stroke ("1," <> Color.grey900)
       ]
       [ linearLayout
           [ width WRAP_CONTENT
           , height WRAP_CONTENT
           , weight 1.0
           , orientation HORIZONTAL
           , gravity CENTER_VERTICAL
           ]
           [ GenericHeader.view (push <<< KPC.GenericHeaderAction) (productHeaderConfig title) ]
       , cartIconView push totalQty
       ]

cartIconView :: forall w. (KPC.Action -> Effect Unit) -> Int -> PrestoDOM (Effect Unit) w
cartIconView push totalQty =
  linearLayout
    [ width WRAP_CONTENT
    , height WRAP_CONTENT
    , orientation HORIZONTAL
    , gravity CENTER_VERTICAL
    , padding (Padding 12 8 12 8)
    , cornerRadius 18.0
    , background Color.grey700
    , stroke ("1," <> Color.grey900)
    , onClick push (const KPC.GoToCart)
    ]
    [ textView
        $ [ text (cartButtonLabel totalQty)
          , color Color.black800
          , singleLine true
          ]
        <> FontStyle.tags TypoGraphy
    ]

cartButtonLabel :: Int -> String
cartButtonLabel totalQty =
  if totalQty <= 0 then "Cart" else "Cart: " <> cartCountLabel totalQty

cartCountLabel :: Int -> String
cartCountLabel totalQty =
  if totalQty > 99 then "99+" else show totalQty

cartTotalQty :: Array KeystoneCartItem -> Int
cartTotalQty = DA.foldl (\acc item -> acc + item.quantity) 0

bottomStoreNavView :: forall w. (KPC.Action -> Effect Unit) -> Int -> PrestoDOM (Effect Unit) w
bottomStoreNavView push totalQty =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , background Color.white900
    , stroke ("1," <> Color.grey900)
    , padding (Padding 8 8 8 10)
    ]
    [ bottomNavItem push "Shop" (KPC.SelectStoreTab "shop") ""
    , bottomNavItem push "Categories" (KPC.SelectStoreTab "categories") ""
    , bottomNavItem push "Cart" KPC.GoToCart (cartCountLabel totalQty)
    ]

bottomNavItem :: forall w. (KPC.Action -> Effect Unit) -> String -> KPC.Action -> String -> PrestoDOM (Effect Unit) w
bottomNavItem push label action badge =
  linearLayout
    [ height (V 54)
    , width (V 0)
    , weight 1.0
    , orientation VERTICAL
    , gravity CENTER
    , cornerRadius 12.0
    , background Color.white900
    , onClick push (const action)
    ]
    [ textView
        $ [ text (bottomNavLabel label badge)
          , color Color.black700
          , gravity CENTER
          , maxLines 1
          ]
        <> FontStyle.body4 TypoGraphy
    ]

bottomNavLabel :: String -> String -> String
bottomNavLabel label badge =
  if badge /= "" && badge /= "0" then label <> ": " <> badge else label

productHeaderConfig :: String -> GHC.Config
productHeaderConfig title =
  let cfg = GHC.config
  in cfg
       { height = WRAP_CONTENT
       , width = WRAP_CONTENT
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

bodyView :: forall w. (KPC.Action -> Effect Unit) -> KeystoneProductDetailScreenState -> PrestoDOM (Effect Unit) w
bodyView push state =
  scrollView
    [ height MATCH_PARENT
    , width MATCH_PARENT
    , weight 1.0
    , scrollBarY false
    ]
    [ if state.props.isLoading then statusText "Loading product..." Color.black700
      else case state.data.error of
        Just err -> statusText err Color.red
        Nothing -> case state.data.product of
          Just product -> productBody push state product
          Nothing -> statusText "Product not found." Color.black700
    ]

statusText :: forall w. String -> String -> PrestoDOM (Effect Unit) w
statusText msg textColor =
  linearLayout
    [ height MATCH_PARENT
    , width MATCH_PARENT
    , gravity CENTER
    , padding (Padding 24 48 24 48)
    ]
    [ textView
        $ [ text msg
          , color textColor
          , gravity CENTER
          ]
        <> FontStyle.body3 TypoGraphy
    ]

productBody :: forall w. (KPC.Action -> Effect Unit) -> KeystoneProductDetailScreenState -> KeystoneProductDetail -> PrestoDOM (Effect Unit) w
productBody push state product =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation VERTICAL
    ]
    [ linearLayout
        [ width MATCH_PARENT
        , height WRAP_CONTENT
        , background Color.grey700
        , gravity CENTER
        , padding (Padding 16 24 16 24)
        ]
        [ imageView
            [ width MATCH_PARENT
            , height (V 240)
            , imageWithFallback ("," <> fromMaybe "" (DA.head product.images))
            ]
        ]
    , linearLayout
        [ height WRAP_CONTENT
        , width MATCH_PARENT
        , orientation VERTICAL
        , padding (Padding 16 16 16 24)
        ]
        [ textView
            $ [ text product.brand
              , color Color.black700
              ]
            <> FontStyle.body3 TypoGraphy
        , textView
            $ [ text product.name
              , color Color.black800
              , margin (MarginTop 4)
              , singleLine false
              ]
            <> FontStyle.h2 TypoGraphy
        , linearLayout
            [ height WRAP_CONTENT
            , width MATCH_PARENT
            , orientation HORIZONTAL
            , gravity CENTER_VERTICAL
            , margin (MarginTop 12)
            ]
            [ textView
                $ [ text ("Rs. " <> product.defaultSellingPrice)
                  , color Color.black800
                  , margin (MarginRight 10)
                  ]
                <> FontStyle.h1 TypoGraphy
            , textView
                $ [ textFromHtml ("<s>Rs. " <> product.defaultMrp <> "</s>")
                  , color Color.black700
                  ]
                <> FontStyle.body3 TypoGraphy
            ]
        , linearLayout
            [ height (V 1)
            , width MATCH_PARENT
            , background Color.grey900
            , margin (MarginVertical 16 16)
            ][]
        , if product.description /= ""
            then linearLayout
                   [ height WRAP_CONTENT
                   , width MATCH_PARENT
                   , orientation VERTICAL
                   , margin (MarginBottom 16)
                   ]
                   [ textView
                       $ [ text "Description"
                         , color Color.black800
                         , margin (MarginBottom 6)
                         ]
                       <> FontStyle.subHeading1 TypoGraphy
                   , textView
                       $ [ text product.description
                         , color Color.black700
                         , singleLine false
                         ]
                       <> FontStyle.body3 TypoGraphy
                   ]
            else linearLayout [ visibility GONE ] []
        , quantitySelectorView push state
        ]
    ]

quantitySelectorView :: forall w. (KPC.Action -> Effect Unit) -> KeystoneProductDetailScreenState -> PrestoDOM (Effect Unit) w
quantitySelectorView push state =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , gravity CENTER_VERTICAL
    ]
    [ textView
        $ [ text "Quantity"
          , color Color.black800
          , weight 1.0
          ]
        <> FontStyle.subHeading1 TypoGraphy
    , linearLayout
        [ height WRAP_CONTENT
        , width WRAP_CONTENT
        , orientation HORIZONTAL
        , gravity CENTER_VERTICAL
        , stroke ("1," <> Color.grey900)
        , cornerRadius 24.0
        , padding (Padding 4 4 4 4)
        ]
        [ stepperButton push KPC.DecrementQty "ny_ic_minus_dec"
        , textView
            $ [ text (show state.props.quantity)
              , color Color.black800
              , gravity CENTER
              , width (V 40)
              ]
            <> FontStyle.subHeading1 TypoGraphy
        , stepperButton push KPC.IncrementQty "ny_ic_plus_inc"
        ]
    ]

stepperButton :: forall w. (KPC.Action -> Effect Unit) -> KPC.Action -> String -> PrestoDOM (Effect Unit) w
stepperButton push action icon =
  linearLayout
    [ height (V 32)
    , width (V 32)
    , gravity CENTER
    , cornerRadius 16.0
    , background Color.grey800
    , onClick push (const action)
    ]
    [ imageView
        [ height (V 14)
        , width (V 14)
        , imageWithFallback (HU.fetchImage HU.FF_ASSET icon)
        ]
    ]

footerView :: forall w. (KPC.Action -> Effect Unit) -> KeystoneProductDetailScreenState -> PrestoDOM (Effect Unit) w
footerView push state =
  let isAdded = currentProductInCart state
      enabled = case state.data.product of
        Just _ -> not state.props.isLoading
        Nothing -> false
  in linearLayout
       [ height WRAP_CONTENT
       , width MATCH_PARENT
       , padding (Padding 16 12 16 16)
       , background Color.white900
       , stroke ("1," <> Color.grey900)
       ]
       [ PrimaryButton.view (push <<< addToCartButtonAction isAdded) (addToCartButtonConfig enabled isAdded)
       ]

currentProductInCart :: KeystoneProductDetailScreenState -> Boolean
currentProductInCart state =
  case state.data.product of
    Just product -> DA.any (\item -> item.slug == product.slug) state.data.cart
    Nothing -> false

addToCartButtonAction :: Boolean -> PrimaryButton.Action -> KPC.Action
addToCartButtonAction true PrimaryButton.OnClick = KPC.GoToCart
addToCartButtonAction false PrimaryButton.OnClick = KPC.AddToCartClicked
addToCartButtonAction _ _ = KPC.NoAction

addToCartButtonConfig :: Boolean -> Boolean -> PrimaryButton.Config
addToCartButtonConfig enabled isAdded =
  let cfg = PrimaryButton.config
  in cfg
       { textConfig = cfg.textConfig
           { text = if isAdded then "View Cart" else "Add to Cart"
           , color = Color.white900
           }
       , margin = MarginVertical 0 0
       , background = if enabled then Color.black900 else Color.grey900
       , height = V 48
       , width = MATCH_PARENT
       , id = "KeystoneProductDetailAddToCart"
       , isClickable = enabled
       , cornerRadius = 12.0
       }
