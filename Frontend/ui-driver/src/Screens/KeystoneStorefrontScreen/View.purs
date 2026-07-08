module Screens.KeystoneStorefrontScreen.View where

import Prelude

import Animation as Anim
import Common.Types.App (LazyCheck(..))
import Components.GenericHeader as GenericHeader
import Components.GenericHeader.Controller as GHC
import Control.Monad.Except (runExceptT)
import Control.Monad.Trans.Class (lift)
import Control.Transformers.Back.Trans (runBackT)
import Data.Array as DA
import Data.Int as DI
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (fromString) as Number
import Data.Number.Format (fixed, toStringWith)
import Data.String as DS
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
import PrestoDOM.Events (globalOnScroll)
import Screens.KeystoneStorefrontScreen.Controller (Action(..), ScreenOutput, eval) as KSC
import Screens.KeystoneStorefrontScreen.Debounce (debouncedSearch, pushAction, setSearchPush)
import Screens.Types (KeystoneCartItem, KeystoneCategory, KeystoneProduct, KeystoneStorefrontScreenState)
import Services.Backend as Remote
import Services.KeystoneCart as Cart
import Styles.Colors as Color
import Types.App (defaultGlobalState)

screen :: KeystoneStorefrontScreenState -> LoggableScreen KSC.Action KeystoneStorefrontScreenState KSC.ScreenOutput
screen initialState =
  { initialState
  , view
  , name: "KeystoneStorefrontScreen"
  , parent: Nothing
  , logWhitelist: []
  , globalEvents:
      [ globalOnScroll "KeystoneStorefrontScreen"
      , ( \push -> do
            setSearchPush push
            cart <- Cart.getCart
            push (KSC.UpdateCart cart)
            void $ launchAff $ flowRunner defaultGlobalState $ runExceptT $ runBackT do
              let initialCategoryId = if initialState.props.activeTab == "categories" && initialState.props.activeCategoryId == "" then firstCategoryId initialState.data.categories else initialState.props.activeCategoryId
              productsResult <- Remote.fetchKeystoneProductsBT initialState.props.searchQuery initialCategoryId 1 initialState.props.pageSize
              lift $ lift $ doAff do liftEffect $ push (KSC.UpdateCatalog productsResult)
              categoriesResult <- Remote.fetchKeystoneCategoriesBT
              lift $ lift $ doAff do liftEffect $ push (KSC.UpdateCategories categoriesResult)
            pure (pure unit)
        )
      ]
  , eval:
      ( \action state ->
          let _ = unsafePerformEffect (handleSideEffects action state)
          in KSC.eval action state
      )
  }

handleSideEffects :: KSC.Action -> KeystoneStorefrontScreenState -> Effect Unit
handleSideEffects action state =
  case action of
    KSC.BackPressed ->
      when (state.props.activeTab == "categories") $
        runFetch "" "" state.props.pageSize
    KSC.GenericHeaderAction GHC.PrefixImgOnClick ->
      when (state.props.activeTab == "categories") $
        runFetch "" "" state.props.pageSize
    KSC.SearchTextChanged q ->
      debouncedSearch 350 (KSC.RunSearch (state.props.searchSeq + 1) q)
    KSC.RunSearch seq q ->
      when (seq == state.props.searchSeq) $
        runFetch q state.props.activeCategoryId state.props.pageSize
    KSC.LoadNextPage ->
      when (state.props.hasMoreProducts && not state.props.isProductsLoading && not state.props.isLoadingMore) $
        runFetchPage state.props.searchQuery state.props.activeCategoryId (state.props.productPage + 1) state.props.pageSize
    KSC.Scroll value ->
      when (state.props.hasMoreProducts && not state.props.isProductsLoading && not state.props.isLoadingMore && shouldLoadNextPage value) $
        runFetchPage state.props.searchQuery state.props.activeCategoryId (state.props.productPage + 1) state.props.pageSize
    KSC.SelectCategory categoryId ->
      let nextCat = if state.props.activeCategoryId == categoryId then "" else categoryId
      in runFetch state.props.searchQuery nextCat state.props.pageSize
    KSC.BrowseCategory categoryId ->
      runFetch state.props.searchQuery categoryId state.props.pageSize
    KSC.SelectStoreTab tab ->
      let nextCat =
            if tab == "categories" && state.props.activeCategoryId == "" then firstCategoryId state.data.categories
            else if tab == "shop" then ""
            else state.props.activeCategoryId
          nextSearch = if tab == "shop" then "" else state.props.searchQuery
      in runFetch nextSearch nextCat state.props.pageSize
    KSC.GoToStoreHome ->
      runFetch "" "" state.props.pageSize
    KSC.AddProductToCart product -> do
      _ <- Cart.addToCart
        { slug: product.slug
        , name: product.name
        , brand: product.brand
        , image: product.image
        , defaultMrp: product.defaultMrp
        , defaultSellingPrice: product.defaultSellingPrice
        , quantity: 1
        }
      cart <- Cart.getCart
      pushAction (KSC.UpdateCart cart)
      void $ pure $ JB.toast (product.name <> " added to cart")
    _ -> pure unit

runFetch :: String -> String -> Int -> Effect Unit
runFetch q categoryId pageSize =
  void $ launchAff $ flowRunner defaultGlobalState $ runExceptT $ runBackT do
    result <- Remote.fetchKeystoneProductsBT q categoryId 1 pageSize
    lift $ lift $ doAff do liftEffect $ pushAction (KSC.UpdateCatalog result)

runFetchPage :: String -> String -> Int -> Int -> Effect Unit
runFetchPage q categoryId page pageSize =
  void $ launchAff $ flowRunner defaultGlobalState $ runExceptT $ runBackT do
    result <- Remote.fetchKeystoneProductsBT q categoryId page pageSize
    lift $ lift $ doAff do liftEffect $ pushAction (KSC.AppendCatalog page result)

shouldLoadNextPage :: String -> Boolean
shouldLoadNextPage value =
  let parts = DS.split (DS.Pattern ",") value
      firstIndex = scrollPart 0 parts
      visibleItems = scrollPart 1 parts
      totalItems = scrollPart 2 parts
  in totalItems > 0 && ((firstIndex + visibleItems) * 100 >= totalItems * 70)

scrollPart :: Int -> Array String -> Int
scrollPart index parts = fromMaybe 0 (DI.fromString =<< DA.index parts index)

view :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
view push state =
  PrestoAnim.animationSet [ Anim.fadeIn true ] $
    linearLayout
      [ height MATCH_PARENT
      , width MATCH_PARENT
      , orientation VERTICAL
      , background Color.white900
      , onBackPressed push (const KSC.BackPressed)
      ]
      [ headerView push state
      , linearLayout
          [ height WRAP_CONTENT
          , width MATCH_PARENT
          , padding (Padding 16 12 16 12)
          , background Color.white900
          ]
          [ searchBarView push state ]
      , storeBodyView push state
      , cartStickyBar push state
      , bottomStoreNavView push state.props.activeTab (cartTotalQty state.data.cart)
      ]

storeBodyView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
storeBodyView push state =
  if state.props.activeTab == "categories" then
    categoriesBrowserView push state
  else
    scrollView
      [ height MATCH_PARENT
      , width MATCH_PARENT
      , weight 1.0
      , scrollBarY false
      , onScroll "keystoneProducts" "KeystoneStorefrontScreen" push KSC.Scroll
      ]
      [ linearLayout
          [ height WRAP_CONTENT
          , width MATCH_PARENT
          , orientation VERTICAL
          , padding (Padding 16 4 16 24)
          ]
          [ shopHomeView push state ]
      ]

headerView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
headerView push state =
  let totalQty = cartTotalQty state.data.cart
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
           [ GenericHeader.view (push <<< KSC.GenericHeaderAction) (storefrontHeaderConfig "Keystone Store") ]
       , cartIconView push totalQty
       ]

storefrontHeaderConfig :: String -> GHC.Config
storefrontHeaderConfig title =
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

cartIconView :: forall w. (KSC.Action -> Effect Unit) -> Int -> PrestoDOM (Effect Unit) w
cartIconView push totalQty =
  linearLayout
    [ width WRAP_CONTENT
    , height WRAP_CONTENT
    , orientation HORIZONTAL
    , gravity CENTER_VERTICAL
    , padding (Padding 12 8 12 8)
    , margin (MarginRight 2)
    , cornerRadius 18.0
    , background Color.grey700
    , stroke ("1," <> Color.grey900)
    , onClick push (const KSC.GoToCart)
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

bottomStoreNavView :: forall w. (KSC.Action -> Effect Unit) -> String -> Int -> PrestoDOM (Effect Unit) w
bottomStoreNavView push activeTab totalQty =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , background Color.white900
    , stroke ("1," <> Color.grey900)
    , padding (Padding 8 8 8 10)
    ]
    [ bottomNavItem push "Shop" (activeTab == "shop") (KSC.SelectStoreTab "shop") ""
    , bottomNavItem push "Categories" (activeTab == "categories") (KSC.SelectStoreTab "categories") ""
    , bottomNavItem push "Cart" false KSC.GoToCart (cartCountLabel totalQty)
    ]

bottomNavItem :: forall w. (KSC.Action -> Effect Unit) -> String -> Boolean -> KSC.Action -> String -> PrestoDOM (Effect Unit) w
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

cartStickyBar :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
cartStickyBar push state =
  let totalQty = cartTotalQty state.data.cart
      total = formatTotal state.data.cart
  in if totalQty == 0 then linearLayout [ visibility GONE ] []
     else linearLayout
            [ width MATCH_PARENT
            , height WRAP_CONTENT
            , padding (Padding 16 12 16 16)
            , background Color.white900
            , stroke ("1," <> Color.grey900)
            ]
            [ linearLayout
                [ height (V 56)
                , width MATCH_PARENT
                , orientation HORIZONTAL
                , gravity CENTER_VERTICAL
                , background Color.black900
                , cornerRadius 12.0
                , padding (Padding 18 0 14 0)
                , onClick push (const KSC.GoToCart)
                ]
                [ linearLayout
                    [ height WRAP_CONTENT
                    , width WRAP_CONTENT
                    , weight 1.0
                    , orientation VERTICAL
                    ]
                    [ textView
                        $ [ text (show totalQty <> (if totalQty == 1 then " item" else " items"))
                          , color Color.white900
                          ]
                        <> FontStyle.body4 TypoGraphy
                    , textView
                        $ [ text ("Rs. " <> total)
                          , color Color.white900
                          ]
                        <> FontStyle.subHeading1 TypoGraphy
                    ]
                , textView
                    $ [ text "View Cart"
                      , color Color.white900
                      , margin (MarginRight 6)
                      ]
                    <> FontStyle.subHeading1 TypoGraphy
                , imageView
                    [ height (V 16)
                    , width (V 16)
                    , imageWithFallback (HU.fetchImage HU.FF_COMMON_ASSET "ny_ic_chevron_right_white")
                    ]
                ]
            ]

cartTotalQty :: Array KeystoneCartItem -> Int
cartTotalQty = DA.foldl (\acc item -> acc + item.quantity) 0

formatTotal :: Array KeystoneCartItem -> String
formatTotal items =
  let
    sumValue = DA.foldl (\acc item -> acc + (parsePrice item.defaultSellingPrice) * (DI.toNumber item.quantity)) 0.0 items
  in toStringWith (fixed 2) sumValue

parsePrice :: String -> Number
parsePrice s = fromMaybe 0.0 (Number.fromString s)

searchBarView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
searchBarView push state =
  linearLayout
    [ height (V 50)
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , gravity CENTER_VERTICAL
    , background Color.white900
    , cornerRadius 16.0
    , padding (Padding 16 0 16 0)
    , stroke ("1," <> Color.grey900)
    ]
    [ imageView
        [ height (V 18)
        , width (V 18)
        , imageWithFallback (HU.fetchImage HU.FF_ASSET "ny_ic_search_grey")
        , margin (MarginRight 8)
        ]
    , editText
        $ [ width MATCH_PARENT
          , height MATCH_PARENT
          , weight 1.0
          , color Color.black800
          , text state.props.searchQuery
          , setCursorAtEnd true
          , hint "Search helmets, gear, plans..."
          , hintColor Color.black700
          , onChange push KSC.SearchTextChanged
          , background Color.transparent
          ]
        <> FontStyle.body1 TypoGraphy
    ]

shopHomeView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
shopHomeView push state =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation VERTICAL
    ]
    [ categoriesView push state
    , productsSectionView push state
    ]

categoriesBrowserView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
categoriesBrowserView push state =
  if state.props.isCategoriesLoading then statusText "Loading categories..." Color.black700
  else if DA.null state.data.categories then statusText "No categories found." Color.black700
  else
    linearLayout
      [ height MATCH_PARENT
      , width MATCH_PARENT
      , weight 1.0
      , orientation VERTICAL
      , padding (Padding 16 4 16 0)
      ]
      (sectionHeaderView "All categories" (Just "Browse the full Keystone catalog")
        <> [ linearLayout
              [ height MATCH_PARENT
              , width MATCH_PARENT
              , weight 1.0
              , orientation HORIZONTAL
              ]
              [ scrollView
                  [ height MATCH_PARENT
                  , width (V 104)
                  , scrollBarY false
                  , margin (MarginRight 12)
                  ]
                  [ linearLayout
                      [ height WRAP_CONTENT
                      , width MATCH_PARENT
                      , orientation VERTICAL
                      , background Color.grey700
                      , stroke ("1," <> Color.grey900)
                      , cornerRadius 12.0
                      , padding (Padding 0 4 0 4)
                      ]
                      (map (categoryRailItem push state) state.data.categories)
                  ]
              , categoryProductsPane push state
              ]
           ]
      )

categoryRailItem :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> KeystoneCategory -> PrestoDOM (Effect Unit) w
categoryRailItem push state category =
  let active = state.props.activeCategoryId == category.id || (state.props.activeCategoryId == "" && category.id == firstCategoryId state.data.categories)
  in linearLayout
       [ height WRAP_CONTENT
       , width MATCH_PARENT
       , orientation VERTICAL
       , gravity CENTER
       , padding (Padding 8 10 8 10)
       , background (if active then Color.white900 else Color.grey700)
       , onClick push (const (KSC.BrowseCategory category.id))
       ]
       [ imageView
           [ height (V 34)
           , width (V 34)
           , imageWithFallback (HU.fetchImage HU.FF_ASSET (categoryIconName category))
           ]
       , textView
           $ [ text (shortCategoryName category)
             , color (if active then Color.black800 else Color.black700)
             , gravity CENTER
             , maxLines 2
             , margin (MarginTop 5)
             ]
           <> FontStyle.tags TypoGraphy
       ]

categoryProductsPane :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
categoryProductsPane push state =
  linearLayout
    [ height MATCH_PARENT
    , width (V 0)
    , weight 1.0
    , orientation VERTICAL
    ]
    [ linearLayout
        [ height WRAP_CONTENT
        , width MATCH_PARENT
        , orientation VERTICAL
        , margin (MarginBottom 12)
        ]
        [ textView
            $ [ text (selectedCategoryName state)
              , color Color.black800
              , maxLines 1
              ]
            <> FontStyle.subHeading1 TypoGraphy
        , textView
            $ [ text ((show (DA.length state.data.products)) <> " products")
              , color Color.black700
              , margin (MarginTop 2)
              ]
            <> FontStyle.tags TypoGraphy
        ]
    , scrollView
        [ height MATCH_PARENT
        , width MATCH_PARENT
        , weight 1.0
        , scrollBarY false
        , onScroll "keystoneCategoryProducts" "KeystoneStorefrontScreen" push KSC.Scroll
        ]
        [ if state.props.isProductsLoading then statusText "Loading products..." Color.black700
          else case state.data.catalogError of
            Just err -> statusText err Color.red
            Nothing ->
              if DA.null state.data.products then statusText "No products found." Color.black700
              else linearLayout
                     [ height WRAP_CONTENT
                     , width MATCH_PARENT
                     , orientation VERTICAL
                     , padding (PaddingBottom 16)
                     ]
                     [ categoryProductListView push state.data.products
                     , loadMoreStatusView state
                     ]
        ]
    ]

loadMoreStatusView :: forall w. KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
loadMoreStatusView state =
  if state.props.isLoadingMore then
    statusText "Loading more products..." Color.black700
  else if state.props.hasMoreProducts then
    textView
      $ [ text "Scroll for more products"
        , color Color.black700
        , gravity CENTER
        , margin (MarginVertical 10 18)
        ]
      <> FontStyle.tags TypoGraphy
  else linearLayout [ visibility GONE ] []

categoryProductListView :: forall w. (KSC.Action -> Effect Unit) -> Array KeystoneProduct -> PrestoDOM (Effect Unit) w
categoryProductListView push products =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation VERTICAL
    ]
    (map (categoryProductRow push) products)

categoryProductRow :: forall w. (KSC.Action -> Effect Unit) -> KeystoneProduct -> PrestoDOM (Effect Unit) w
categoryProductRow push product =
  let discount = discountPercent product
  in linearLayout
       [ height WRAP_CONTENT
       , width MATCH_PARENT
       , orientation HORIZONTAL
       , padding (Padding 8 8 8 8)
       , margin (MarginBottom 10)
       , background Color.white900
       , stroke ("1," <> Color.grey900)
       , cornerRadius 12.0
       , onClick push (const (KSC.SelectProduct product))
       ]
       [ frameLayout
           [ height (V 76)
           , width (V 76)
           , background Color.grey700
           , cornerRadius 10.0
           ]
           [ imageView
               [ height MATCH_PARENT
               , width MATCH_PARENT
               , cornerRadius 10.0
               , imageWithFallback ("," <> product.image)
               ]
           , if discount > 0 then
               linearLayout
                 [ height WRAP_CONTENT
                 , width WRAP_CONTENT
                 , layoutGravity "left"
                 , margin (Margin 4 4 0 0)
                 , background Color.black900
                 , cornerRadius 4.0
                 , padding (Padding 5 2 5 2)
                 ]
                 [ textView
                     $ [ text ((show discount) <> "%")
                       , color Color.white900
                       ]
                     <> FontStyle.tags TypoGraphy
                 ]
             else linearLayout [ visibility GONE ] []
           ]
       , linearLayout
           [ height WRAP_CONTENT
           , width (V 0)
           , weight 1.0
           , orientation VERTICAL
           , margin (MarginLeft 10)
           ]
           [ if product.brand /= "" then productBrandView product.brand else linearLayout [ visibility GONE ] []
           , textView
               $ [ text product.name
                 , color Color.black800
                 , maxLines 2
                 , margin (MarginTop 2)
                 ]
               <> FontStyle.body4 TypoGraphy
           , linearLayout
               [ height WRAP_CONTENT
               , width MATCH_PARENT
               , orientation HORIZONTAL
               , gravity CENTER_VERTICAL
               , margin (MarginTop 6)
               ]
               [ textView
                   $ [ text ("Rs. " <> product.defaultSellingPrice)
                     , color Color.black800
                     , weight 1.0
                     ]
                   <> FontStyle.subHeading1 TypoGraphy
               , imageView
                   [ height (V 28)
                   , width (V 28)
                   , imageWithFallback (HU.fetchImage HU.FF_ASSET "ny_ic_plus_inc")
                   , onClick push (const (KSC.AddProductToCart product))
                   ]
               ]
           ]
       ]

selectedCategoryName :: KeystoneStorefrontScreenState -> String
selectedCategoryName state =
  let categoryId = if state.props.activeCategoryId == "" then firstCategoryId state.data.categories else state.props.activeCategoryId
  in fromMaybe "Category" (_.name <$> DA.find (\category -> category.id == categoryId) state.data.categories)

firstCategoryId :: Array KeystoneCategory -> String
firstCategoryId categories = fromMaybe "" (_.id <$> DA.head categories)

categoriesView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
categoriesView push state =
  if state.props.isCategoriesLoading || DA.null state.data.categories then
    linearLayout [ visibility GONE ] []
  else
    let rows = chunk3 ([ allCategoryTile push state ] <> map (categoryTile push state) (DA.take 5 state.data.categories))
    in
    linearLayout
      [ height WRAP_CONTENT
      , width MATCH_PARENT
      , orientation VERTICAL
      , margin (MarginBottom 24)
      ]
      (sectionHeaderView "Shop by category" Nothing
        <> map categoryTilesRow rows
      )

allCategoryTile :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
allCategoryTile push state =
  categoryTileLayout push "" "All" "ny_ic_baggage" (state.props.activeCategoryId == "")

categoryTile :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> KeystoneCategory -> PrestoDOM (Effect Unit) w
categoryTile push state category =
  categoryTileLayout push category.id (shortCategoryName category) (categoryIconName category) (state.props.activeCategoryId == category.id)

categoryTilesRow :: forall w. Array (PrestoDOM (Effect Unit) w) -> PrestoDOM (Effect Unit) w
categoryTilesRow row =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , margin (MarginBottom 10)
    ]
    (row <> categoryTileFiller (3 - DA.length row))

categoryTileFiller :: forall w. Int -> Array (PrestoDOM (Effect Unit) w)
categoryTileFiller count =
  if count <= 0 then []
  else [ linearLayout [ weight 1.0, width (V 0), height WRAP_CONTENT, margin (MarginRight 10) ] [] ] <> categoryTileFiller (count - 1)

categoryTileLayout :: forall w. (KSC.Action -> Effect Unit) -> String -> String -> String -> Boolean -> PrestoDOM (Effect Unit) w
categoryTileLayout push categoryId label imageName _active =
  linearLayout
    [ height WRAP_CONTENT
    , width (V 0)
    , weight 1.0
    , orientation VERTICAL
    , gravity CENTER
    , margin (MarginRight 10)
    , onClick push (const (KSC.BrowseCategory categoryId))
    ]
    [ linearLayout
        [ height (V 84)
          , width MATCH_PARENT
        , gravity CENTER
        , background Color.white900
        , stroke ("1," <> Color.grey900)
        , cornerRadius 12.0
        , padding (Padding 16 14 16 14)
        ]
        [ imageView
            [ height (V 52)
            , width (V 52)
            , imageWithFallback (HU.fetchImage HU.FF_ASSET imageName)
            ]
        ]
    , textView
        $ [ text label
          , color Color.black800
          , gravity CENTER
          , maxLines 1
          , margin (MarginTop 7)
          ]
        <> FontStyle.body4 TypoGraphy
    ]

shortCategoryName :: KeystoneCategory -> String
shortCategoryName category =
  let key = DS.toLower (category.slug <> " " <> category.name)
  in if DS.contains (DS.Pattern "helmet") key then "Helmets"
     else if DS.contains (DS.Pattern "mount") key || DS.contains (DS.Pattern "phone") key then "Mounts"
     else if DS.contains (DS.Pattern "rain") key || DS.contains (DS.Pattern "jacket") key then "Rainwear"
     else if DS.contains (DS.Pattern "loan") key || DS.contains (DS.Pattern "finance") key then "Loans"
     else if DS.contains (DS.Pattern "fuel") key then "Fuel"
     else if DS.contains (DS.Pattern "grocery") key then "Grocery"
     else if DS.contains (DS.Pattern "wallet") key || DS.contains (DS.Pattern "payment") key then "Wallet"
     else if DS.contains (DS.Pattern "data") key || DS.contains (DS.Pattern "mobile") key then "Data"
     else category.name

categoryIconName :: KeystoneCategory -> String
categoryIconName category =
  case category.slug of
    "vehicle-electronics" -> "keystone_category_vehicle_electronics"
    "sub0101-stereos-head-units" -> "keystone_category_sub0101_stereos_head_units"
    "sub0102-cameras-dash-reverse" -> "keystone_category_sub0102_cameras_dash_reverse"
    "sub0104-in-car-charging" -> "keystone_category_sub0104_in_car_charging"
    "sub0105-mounts-holders" -> "keystone_category_sub0105_mounts_holders"
    "vehicle-interior" -> "keystone_category_vehicle_interior"
    "sub0201-seat-covers" -> "keystone_category_sub0201_seat_covers"
    "sub0202-cushions-supports" -> "keystone_category_sub0202_cushions_supports"
    "sub0203-storage-cleanliness" -> "keystone_category_sub0203_storage_cleanliness"
    "sub0204-floor-mats" -> "keystone_category_sub0204_floor_mats"
    "sub0205-dashboard-decor" -> "keystone_category_sub0205_dashboard_decor"
    "sub0206-air-fresheners" -> "keystone_category_sub0206_air_fresheners"
    "vehicle-exterior" -> "keystone_category_vehicle_exterior"
    "sub0301-sun-shades-body-covers" -> "keystone_category_sub0301_sun_shades_body_covers"
    "sub0302-door-guards-trims" -> "keystone_category_sub0302_door_guards_trims"
    "vehicle-maintenance-care" -> "keystone_category_vehicle_maintenance_care"
    "sub0401-tools" -> "keystone_category_sub0401_tools"
    "sub0402-tyre-care" -> "keystone_category_sub0402_tyre_care"
    "sub0403-cleaning-tools" -> "keystone_category_sub0403_cleaning_tools"
    "sub0404-vacuum-detailing-tools" -> "keystone_category_sub0404_vacuum_detailing_tools"
    "sub0405-cloths-brushes" -> "keystone_category_sub0405_cloths_brushes"
    "vehicle-gadgets-in-car-comfort" -> "keystone_category_vehicle_gadgets_in_car_comfort"
    "sub0501-jump-starters-power" -> "keystone_category_sub0501_jump_starters_power"
    "sub0502-ambient-lighting-effects" -> "keystone_category_sub0502_ambient_lighting_effects"
    "sub0503-in-car-cooling" -> "keystone_category_sub0503_in_car_cooling"
    "driver-apparel" -> "keystone_category_driver_apparel"
    "sub0601-shirts-t-shirts" -> "keystone_category_sub0601_shirts_t_shirts"
    "sub0602-suits-sets" -> "keystone_category_sub0602_suits_sets"
    "sub0603-footwear" -> "keystone_category_sub0603_footwear"
    "sub0604-belts-gloves" -> "keystone_category_sub0604_belts_gloves"
    "sub0605-rainwear" -> "keystone_category_sub0605_rainwear"
    "driver-comfort-climate" -> "keystone_category_driver_comfort_climate"
    "sub0701-eyewear" -> "keystone_category_sub0701_eyewear"
    "sub0702-cooling-wearables" -> "keystone_category_sub0702_cooling_wearables"
    "sub0703-face-protection" -> "keystone_category_sub0703_face_protection"
    "personal-electronics" -> "keystone_category_personal_electronics"
    "sub0801-earphones-headphones" -> "keystone_category_sub0801_earphones_headphones"
    "sub0802-bluetooth-speakers" -> "keystone_category_sub0802_bluetooth_speakers"
    _ ->
      let key = DS.toLower (category.slug <> " " <> category.name)
      in if DS.contains (DS.Pattern "helmet") key then "keystone_category_helmet_icon"
         else if DS.contains (DS.Pattern "mount") key || DS.contains (DS.Pattern "phone") key then "keystone_category_mount_icon"
         else if DS.contains (DS.Pattern "rain") key || DS.contains (DS.Pattern "jacket") key then "keystone_category_rain_jacket_icon"
         else if DS.contains (DS.Pattern "loan") key || DS.contains (DS.Pattern "finance") key then "keystone_category_loan_icon"
         else if DS.contains (DS.Pattern "fuel") key then "keystone_category_fuel_icon"
         else if DS.contains (DS.Pattern "grocery") key then "keystone_category_grocery_icon"
         else if DS.contains (DS.Pattern "wallet") key || DS.contains (DS.Pattern "payment") key then "keystone_category_wallet_icon"
         else if DS.contains (DS.Pattern "shield") key || DS.contains (DS.Pattern "insurance") key then "keystone_category_shield_icon"
         else if DS.contains (DS.Pattern "house") key || DS.contains (DS.Pattern "home") key then "keystone_category_house_icon"
         else if DS.contains (DS.Pattern "data") key || DS.contains (DS.Pattern "mobile") key then "keystone_category_data_icon"
         else "keystone_category_gear_icon"

sectionHeaderView :: forall w. String -> Maybe String -> Array (PrestoDOM (Effect Unit) w)
sectionHeaderView titleLabel subTitle =
  [ linearLayout
      [ height WRAP_CONTENT
      , width MATCH_PARENT
      , orientation VERTICAL
      , margin (MarginBottom 12)
      ]
      ([ textView
          $ [ text titleLabel
            , color Color.black800
            ]
          <> FontStyle.h2 TypoGraphy
       ]
       <> case subTitle of
            Just value ->
              [ textView
                  $ [ text value
                    , color Color.black700
                    , margin (MarginTop 2)
                    ]
                  <> FontStyle.body4 TypoGraphy
              ]
            Nothing -> []
      )
  ]

chunk3 :: forall a. Array a -> Array (Array a)
chunk3 arr =
  case DA.uncons arr of
    Nothing -> []
    Just { head: a, tail: t1 } ->
      case DA.uncons t1 of
        Nothing -> [ [ a ] ]
        Just { head: b, tail: t2 } ->
          case DA.uncons t2 of
            Nothing -> [ [ a, b ] ]
            Just { head: c, tail: t3 } -> [ [ a, b, c ] ] <> chunk3 t3

productsSectionView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
productsSectionView push state =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation VERTICAL
    ]
    [ if state.props.isProductsLoading then statusText "Loading products..." Color.black700
      else case state.data.catalogError of
        Just err -> statusText err Color.red
        Nothing ->
          if DA.null state.data.products
            then statusText "No products found." Color.black700
            else catalogSectionsView push state
    ]

catalogSectionsView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> PrestoDOM (Effect Unit) w
catalogSectionsView push state =
  let deals = dealProducts state.data.products
      filteredMode = state.props.searchQuery /= "" || state.props.activeCategoryId /= ""
  in linearLayout
       [ height WRAP_CONTENT
       , width MATCH_PARENT
       , orientation VERTICAL
       ]
       (if filteredMode then
          [ productGridSection push state (sectionTitle state) Nothing state.data.products ]
        else
          (if DA.null deals then [] else [ dealsSectionView push deals ])
            <> [ productGridSection push state "Popular right now" (Just "Picked from the latest Keystone catalog") state.data.products ]
       )

dealsSectionView :: forall w. (KSC.Action -> Effect Unit) -> Array KeystoneProduct -> PrestoDOM (Effect Unit) w
dealsSectionView push products =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation VERTICAL
    , margin (MarginBottom 24)
    ]
    (sectionHeaderView "Deals for you" (Just "Save on driver essentials")
      <> [ horizontalScrollView
            [ height WRAP_CONTENT
            , width MATCH_PARENT
            , scrollBarX false
            ]
            [ linearLayout
                [ height WRAP_CONTENT
                , width WRAP_CONTENT
                , orientation HORIZONTAL
                ]
                (map (dealProductCardView push) products)
            ]
         ]
    )

productGridSection :: forall w. (KSC.Action -> Effect Unit) -> KeystoneStorefrontScreenState -> String -> Maybe String -> Array KeystoneProduct -> PrestoDOM (Effect Unit) w
productGridSection push state title subTitle products =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation VERTICAL
    ]
    (sectionHeaderView title subTitle <> [ productsGridView push products, loadMoreStatusView state ])

sectionTitle :: KeystoneStorefrontScreenState -> String
sectionTitle state =
  if state.props.searchQuery /= "" then "Search results"
  else if state.props.activeCategoryId /= "" then fromMaybe "Category" (_.name <$> DA.find (\category -> category.id == state.props.activeCategoryId) state.data.categories)
  else "Popular right now"

dealProducts :: Array KeystoneProduct -> Array KeystoneProduct
dealProducts products =
  DA.take 8 $ DA.sortBy (\a b -> compare (discountPercent b) (discountPercent a)) $ DA.filter (\product -> discountPercent product > 0) products

discountPercent :: KeystoneProduct -> Int
discountPercent product =
  let mrp = parsePrice product.defaultMrp
      sellingPrice = parsePrice product.defaultSellingPrice
  in if mrp <= 0.0 || sellingPrice >= mrp then 0
     else DI.floor (((mrp - sellingPrice) / mrp) * 100.0)

statusText :: forall w. String -> String -> PrestoDOM (Effect Unit) w
statusText msg textColor =
  textView
    $ [ text msg
      , color textColor
      , margin (MarginVertical 12 12)
      ]
    <> FontStyle.body3 TypoGraphy

productsGridView :: forall w. (KSC.Action -> Effect Unit) -> Array KeystoneProduct -> PrestoDOM (Effect Unit) w
productsGridView push products =
  let rows = chunk2 products
  in linearLayout
       [ height WRAP_CONTENT
       , width MATCH_PARENT
       , orientation VERTICAL
       ]
       (map (productsRowView push) rows)

productsRowView :: forall w. (KSC.Action -> Effect Unit) -> Array KeystoneProduct -> PrestoDOM (Effect Unit) w
productsRowView push row =
  linearLayout
    [ height WRAP_CONTENT
    , width MATCH_PARENT
    , orientation HORIZONTAL
    , margin (MarginBottom 12)
    ]
    (map (productCardView push) row <> rowFiller (DA.length row))

rowFiller :: forall w. Int -> Array (PrestoDOM (Effect Unit) w)
rowFiller len = if len < 2 then [ linearLayout [ weight 1.0, width (V 0), height WRAP_CONTENT ] [] ] else []

productCardView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneProduct -> PrestoDOM (Effect Unit) w
productCardView push product =
  linearLayout
    [ height WRAP_CONTENT
    , weight 1.0
    , width (V 0)
    , orientation VERTICAL
    , margin (MarginRight 10)
    , background Color.white900
    , stroke ("1," <> Color.grey900)
    , cornerRadius 12.0
    , onClick push (const (KSC.SelectProduct product))
    ]
    (productCardContent push product)

dealProductCardView :: forall w. (KSC.Action -> Effect Unit) -> KeystoneProduct -> PrestoDOM (Effect Unit) w
dealProductCardView push product =
  linearLayout
    [ height WRAP_CONTENT
    , width (V 170)
    , orientation VERTICAL
    , margin (MarginRight 12)
    , background Color.white900
    , stroke ("1," <> Color.grey900)
    , cornerRadius 12.0
    , onClick push (const (KSC.SelectProduct product))
    ]
    (productCardContent push product)

productCardContent :: forall w. (KSC.Action -> Effect Unit) -> KeystoneProduct -> Array (PrestoDOM (Effect Unit) w)
productCardContent push product =
  let discount = discountPercent product
  in
  [ frameLayout
      [ width MATCH_PARENT
      , height (V 132)
      , background Color.grey700
      , cornerRadius 12.0
      ]
      [ imageView
          [ width MATCH_PARENT
          , height MATCH_PARENT
          , cornerRadius 12.0
          , imageWithFallback ("," <> product.image)
          ]
      , if discount > 0 then discountBadgeView discount else linearLayout [ visibility GONE ] []
      , imageView
          [ height (V 32)
          , width (V 32)
          , layoutGravity "right"
          , margin (Margin 0 8 8 0)
          , imageWithFallback (HU.fetchImage HU.FF_ASSET "ny_ic_plus_inc")
          , onClick push (const (KSC.AddProductToCart product))
          ]
      ]
  , linearLayout
      [ height WRAP_CONTENT
      , width MATCH_PARENT
      , orientation VERTICAL
      , padding (Padding 12 10 12 12)
      ]
      ([ if product.brand /= "" then productBrandView product.brand else linearLayout [ visibility GONE ] []
       , textView
           $ [ text product.name
             , color Color.black800
             , margin (MarginTop 4)
             , maxLines 2
             ]
           <> FontStyle.body1 TypoGraphy
       , linearLayout
           [ height WRAP_CONTENT
           , width MATCH_PARENT
           , orientation HORIZONTAL
           , gravity CENTER_VERTICAL
           , margin (MarginTop 8)
           ]
           ([ textView
                $ [ text ("Rs. " <> product.defaultSellingPrice)
                  , color Color.black800
                  , margin (MarginRight 6)
                  ]
                <> FontStyle.subHeading1 TypoGraphy
            ]
            <> if discount > 0 then
                [ textView
                    $ [ textFromHtml ("<s>Rs. " <> product.defaultMrp <> "</s>")
                      , color Color.black700
                      ]
                    <> FontStyle.body4 TypoGraphy
                ]
              else []
           )
       ])
  ]

productBrandView :: forall w. String -> PrestoDOM (Effect Unit) w
productBrandView brand =
  textView
    $ [ text (DS.toUpper brand)
      , color Color.black700
      , singleLine true
      ]
    <> FontStyle.body4 TypoGraphy

discountBadgeView :: forall w. Int -> PrestoDOM (Effect Unit) w
discountBadgeView discount =
  linearLayout
    [ height WRAP_CONTENT
    , width WRAP_CONTENT
    , layoutGravity "left"
    , margin (Margin 8 8 0 0)
    , background Color.black900
    , cornerRadius 4.0
    , padding (Padding 8 3 8 3)
    ]
    [ textView
        $ [ text (show discount <> "% OFF")
          , color Color.white900
          ]
        <> FontStyle.body4 TypoGraphy
    ]

chunk2 :: forall a. Array a -> Array (Array a)
chunk2 arr =
  case DA.uncons arr of
    Nothing -> []
    Just { head: a, tail: t1 } ->
      case DA.uncons t1 of
        Nothing -> [ [ a ] ]
        Just { head: b, tail: t2 } -> [ [ a, b ] ] <> chunk2 t2
