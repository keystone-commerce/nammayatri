module Screens.KeystoneProductDetailScreen.Controller where

import Prelude

import Components.GenericHeader.Controller as GenericHeader
import Data.Array as DA
import Data.Maybe (Maybe(..), fromMaybe)
import Log (trackAppActionClick, trackAppBackPress, trackAppEndScreen, trackAppScreenRender)
import PrestoDOM (Eval, continue, exit, update)
import PrestoDOM.Types.Core (class Loggable, defaultPerformLog)
import Screens (ScreenName(..), getScreen)
import Screens.Types (KeystoneCartItem, KeystoneProductDetailResult, KeystoneProductDetailScreenState)

instance showAction :: Show Action where
  show BackPressed = "BackPressed"
  show AfterRender = "AfterRender"
  show NoAction = "NoAction"
  show GoToCart = "GoToCart"
  show (SelectStoreTab _) = "SelectStoreTab"
  show AddToCartClicked = "AddToCartClicked"
  show IncrementQty = "IncrementQty"
  show DecrementQty = "DecrementQty"
  show (GenericHeaderAction _) = "GenericHeaderAction"
  show (UpdateProduct _) = "UpdateProduct"
  show (UpdateCart _) = "UpdateCart"

instance loggableAction :: Loggable Action where
  performLog action appId = case action of
    AfterRender -> trackAppScreenRender appId "screen" (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN)
    BackPressed -> do
      trackAppBackPress appId (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN)
      trackAppEndScreen appId (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN)
    GoToCart -> trackAppActionClick appId (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN) "header" "cart_icon"
    SelectStoreTab tab -> trackAppActionClick appId (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN) "bottom_nav" tab
    AddToCartClicked -> trackAppActionClick appId (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN) "primary_button" "add_to_cart"
    IncrementQty -> trackAppActionClick appId (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN) "qty" "increment"
    DecrementQty -> trackAppActionClick appId (getScreen KEYSTONE_PRODUCT_DETAIL_SCREEN) "qty" "decrement"
    _ -> defaultPerformLog action appId

data Action
  = BackPressed
  | AfterRender
  | NoAction
  | GoToCart
  | SelectStoreTab String
  | AddToCartClicked
  | IncrementQty
  | DecrementQty
  | GenericHeaderAction GenericHeader.Action
  | UpdateProduct KeystoneProductDetailResult
  | UpdateCart (Array KeystoneCartItem)

data ScreenOutput
  = GoBack
  | GoToCartScreen KeystoneProductDetailScreenState
  | BackToStorefront String

eval :: Action -> KeystoneProductDetailScreenState -> Eval Action ScreenOutput KeystoneProductDetailScreenState

eval AfterRender state = continue state

eval BackPressed state = exit GoBack
eval (GenericHeaderAction GenericHeader.PrefixImgOnClick) state = exit GoBack
eval (GenericHeaderAction GenericHeader.SuffixImgOnClick) state = exit (GoToCartScreen state)
eval GoToCart state = exit (GoToCartScreen state)
eval (SelectStoreTab tab) state = exit (BackToStorefront tab)

eval (UpdateProduct result) state =
  if result.isSuccess then
    continue state { data { product = Just result.product, error = Nothing }, props { isLoading = false } }
  else
    case state.data.product of
      Just _ -> continue state { props { isLoading = false } }
      Nothing -> continue state { data { product = Nothing, error = Just result.error }, props { isLoading = false } }

eval (UpdateCart items) state = continue state { data { cart = items } }

eval IncrementQty state = continue state { props { quantity = state.props.quantity + 1 } }

eval DecrementQty state =
  let next = if state.props.quantity > 1 then state.props.quantity - 1 else 1
  in continue state { props { quantity = next } }

eval AddToCartClicked state =
  case state.data.product of
    Just product -> continue state { data { cart = addItemToCart state.data.cart
      { slug: product.slug
      , name: product.name
      , brand: product.brand
      , image: fromMaybe "" (DA.head product.images)
      , defaultMrp: product.defaultMrp
      , defaultSellingPrice: product.defaultSellingPrice
      , quantity: state.props.quantity
      } } }
    Nothing -> continue state

eval _ state = update state

addItemToCart :: Array KeystoneCartItem -> KeystoneCartItem -> Array KeystoneCartItem
addItemToCart cart item =
  if DA.any (\cartItem -> cartItem.slug == item.slug) cart then
    map
      (\cartItem ->
        if cartItem.slug == item.slug then
          cartItem { quantity = cartItem.quantity + item.quantity }
        else
          cartItem
      )
      cart
  else
    cart <> [ item ]
