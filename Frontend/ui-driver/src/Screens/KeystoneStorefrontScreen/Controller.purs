module Screens.KeystoneStorefrontScreen.Controller where

import Prelude

import Components.GenericHeader.Controller as GenericHeader
import Data.Array as DA
import Data.Int (fromString)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String (Pattern(..), split)
import Log (trackAppActionClick, trackAppBackPress, trackAppEndScreen, trackAppScreenRender)
import PrestoDOM (Eval, continue, exit, update)
import PrestoDOM.Types.Core (class Loggable, defaultPerformLog)
import Screens (ScreenName(..), getScreen)
import Screens.Types (KeystoneCartItem, KeystoneCatalogResult, KeystoneCategory, KeystoneCategoryResult, KeystoneProduct, KeystoneStorefrontScreenState)

instance showAction :: Show Action where
  show BackPressed = "BackPressed"
  show AfterRender = "AfterRender"
  show NoAction = "NoAction"
  show GoToCart = "GoToCart"
  show GoToStoreHome = "GoToStoreHome"
  show GoToSearch = "GoToSearch"
  show (SelectStoreTab _) = "SelectStoreTab"
  show (GenericHeaderAction _) = "GenericHeaderAction"
  show (UpdateCatalog _) = "UpdateCatalog"
  show (AppendCatalog _ _) = "AppendCatalog"
  show (UpdateCategories _) = "UpdateCategories"
  show (UpdateCart _) = "UpdateCart"
  show (SearchTextChanged _) = "SearchTextChanged"
  show (RunSearch _ _) = "RunSearch"
  show LoadNextPage = "LoadNextPage"
  show (Scroll _) = "Scroll"
  show (SelectCategory _) = "SelectCategory"
  show (BrowseCategory _) = "BrowseCategory"
  show (SelectProduct _) = "SelectProduct"
  show (AddProductToCart _) = "AddProductToCart"

instance loggableAction :: Loggable Action where
  performLog action appId = case action of
    AfterRender -> trackAppScreenRender appId "screen" (getScreen KEYSTONE_STOREFRONT_SCREEN)
    BackPressed -> do
      trackAppBackPress appId (getScreen KEYSTONE_STOREFRONT_SCREEN)
      trackAppEndScreen appId (getScreen KEYSTONE_STOREFRONT_SCREEN)
    GoToCart -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "header" "cart_icon"
    GoToStoreHome -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "bottom_nav" "home"
    GoToSearch -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "bottom_nav" "search"
    SelectStoreTab tab -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "bottom_nav" tab
    SelectProduct _ -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "list" "product_select"
    AddProductToCart _ -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "list" "product_add_to_cart"
    SelectCategory _ -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "chips" "category_select"
    BrowseCategory _ -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "category_browser" "category_select"
    SearchTextChanged _ -> trackAppActionClick appId (getScreen KEYSTONE_STOREFRONT_SCREEN) "search" "text_changed"
    _ -> defaultPerformLog action appId

data Action
  = BackPressed
  | AfterRender
  | NoAction
  | GoToCart
  | GoToStoreHome
  | GoToSearch
  | SelectStoreTab String
  | GenericHeaderAction GenericHeader.Action
  | UpdateCatalog KeystoneCatalogResult
  | AppendCatalog Int KeystoneCatalogResult
  | UpdateCategories KeystoneCategoryResult
  | UpdateCart (Array KeystoneCartItem)
  | SearchTextChanged String
  | RunSearch Int String
  | LoadNextPage
  | Scroll String
  | SelectCategory String
  | BrowseCategory String
  | SelectProduct KeystoneProduct
  | AddProductToCart KeystoneProduct

data ScreenOutput
  = GoBack
  | OpenProduct KeystoneProduct KeystoneStorefrontScreenState
  | OpenCart KeystoneStorefrontScreenState

eval :: Action -> KeystoneStorefrontScreenState -> Eval Action ScreenOutput KeystoneStorefrontScreenState

eval AfterRender state = continue state

eval BackPressed state =
  if state.props.activeTab == "categories" then eval GoToStoreHome state else exit GoBack

eval (GenericHeaderAction GenericHeader.PrefixImgOnClick) state =
  if state.props.activeTab == "categories" then eval GoToStoreHome state else exit GoBack
eval (GenericHeaderAction GenericHeader.SuffixImgOnClick) state = exit (OpenCart state)

eval GoToCart state = exit (OpenCart state)

eval GoToStoreHome state =
  continue state { props { searchQuery = "", activeCategoryId = "", activeTab = "shop", productPage = 1, hasMoreProducts = true, isProductsLoading = true, isLoadingMore = false } }

eval GoToSearch state =
  continue state { props { activeCategoryId = "" } }

eval (SelectStoreTab tab) state =
  let nextCategoryId =
        if tab == "categories" && state.props.activeCategoryId == "" then firstCategoryId state.data.categories
        else if tab == "shop" then ""
        else state.props.activeCategoryId
      nextSearch = if tab == "shop" then "" else state.props.searchQuery
  in continue state { props { activeTab = tab, activeCategoryId = nextCategoryId, searchQuery = nextSearch, productPage = 1, hasMoreProducts = true, isProductsLoading = true, isLoadingMore = false } }

eval (SelectProduct product) state = exit (OpenProduct product state)

eval (UpdateCatalog result) state =
  if result.isSuccess then
    continue state
      { data { products = result.products, catalogError = Nothing }
      , props { isProductsLoading = false, isLoadingMore = false, productPage = 1, hasMoreProducts = DA.length result.products == state.props.pageSize }
      }
  else
    continue state
      { data { products = [], catalogError = Just result.error }
      , props { isProductsLoading = false, isLoadingMore = false, productPage = 1, hasMoreProducts = false }
      }

eval (AppendCatalog page result) state =
  if result.isSuccess then
    continue state
      { data { products = mergeProducts state.data.products result.products, catalogError = Nothing }
      , props { isLoadingMore = false, productPage = page, hasMoreProducts = DA.length result.products == state.props.pageSize }
      }
  else
    continue state { data { catalogError = Just result.error }, props { isLoadingMore = false, hasMoreProducts = false } }

eval (UpdateCategories result) state =
  if result.isSuccess then
    continue state { data { categories = result.categories, categoriesError = Nothing }, props { isCategoriesLoading = false } }
  else
    continue state { data { categories = [], categoriesError = Just result.error }, props { isCategoriesLoading = false } }

eval (UpdateCart items) state = continue state { data { cart = items } }

eval (SearchTextChanged q) state =
  let nextSeq = state.props.searchSeq + 1
  in continue state { props { searchQuery = q, searchSeq = nextSeq } }

eval (RunSearch seq q) state =
  if seq /= state.props.searchSeq then
    continue state
  else
    continue state { props { productPage = 1, hasMoreProducts = true, isProductsLoading = true, isLoadingMore = false } }

eval LoadNextPage state =
  if state.props.isProductsLoading || state.props.isLoadingMore || not state.props.hasMoreProducts then
    continue state
  else
    continue state { props { isLoadingMore = true } }

eval (Scroll value) state =
  if shouldLoadNextPage value state then
    eval LoadNextPage state
  else
    continue state

eval (SelectCategory categoryId) state =
  let next = if state.props.activeCategoryId == categoryId then "" else categoryId
  in continue state { props { activeCategoryId = next, productPage = 1, hasMoreProducts = true, isProductsLoading = true, isLoadingMore = false } }

eval (BrowseCategory categoryId) state =
  continue state { props { activeCategoryId = categoryId, activeTab = "categories", productPage = 1, hasMoreProducts = true, isProductsLoading = true, isLoadingMore = false } }

eval _ state = update state

cartItemCount :: Array KeystoneCartItem -> Int
cartItemCount items = DA.foldl (\acc item -> acc + item.quantity) 0 items

firstCategoryId :: Array KeystoneCategory -> String
firstCategoryId categories = fromMaybe "" (_.id <$> DA.head categories)

mergeProducts :: Array KeystoneProduct -> Array KeystoneProduct -> Array KeystoneProduct
mergeProducts existing incoming =
  DA.unionBy (\a b -> a.id == b.id) existing incoming

shouldLoadNextPage :: String -> KeystoneStorefrontScreenState -> Boolean
shouldLoadNextPage value state =
  let parts = split (Pattern ",") value
      firstIndex = scrollPart 0 parts
      visibleItems = scrollPart 1 parts
      totalItems = scrollPart 2 parts
      crossedThreshold = (firstIndex + visibleItems) * 100 >= totalItems * 70
  in totalItems > 0 && crossedThreshold && state.props.hasMoreProducts && not state.props.isProductsLoading && not state.props.isLoadingMore

scrollPart :: Int -> Array String -> Int
scrollPart index parts = fromMaybe 0 (fromString =<< DA.index parts index)
