module Screens.KeystoneCartScreen.Controller where

import Prelude

import Components.GenericHeader.Controller as GenericHeader
import Data.Array as DA
import Data.Maybe (Maybe(..))
import Log (trackAppActionClick, trackAppBackPress, trackAppEndScreen, trackAppScreenRender)
import PrestoDOM (Eval, continue, exit, update)
import PrestoDOM.Types.Core (class Loggable, defaultPerformLog)
import Screens (ScreenName(..), getScreen)
import Screens.Types (KeystoneCartItem, KeystoneCartScreenState)

instance showAction :: Show Action where
  show BackPressed = "BackPressed"
  show AfterRender = "AfterRender"
  show NoAction = "NoAction"
  show ContinueShopping = "ContinueShopping"
  show (SelectStoreTab _) = "SelectStoreTab"
  show (GenericHeaderAction _) = "GenericHeaderAction"
  show (UpdateCart _) = "UpdateCart"
  show (IncrementItem _) = "IncrementItem"
  show (DecrementItem _) = "DecrementItem"
  show (RemoveItem _) = "RemoveItem"

instance loggableAction :: Loggable Action where
  performLog action appId = case action of
    AfterRender -> trackAppScreenRender appId "screen" (getScreen KEYSTONE_CART_SCREEN)
    BackPressed -> do
      trackAppBackPress appId (getScreen KEYSTONE_CART_SCREEN)
      trackAppEndScreen appId (getScreen KEYSTONE_CART_SCREEN)
    ContinueShopping -> trackAppActionClick appId (getScreen KEYSTONE_CART_SCREEN) "footer" "continue_shopping"
    SelectStoreTab tab -> trackAppActionClick appId (getScreen KEYSTONE_CART_SCREEN) "bottom_nav" tab
    IncrementItem _ -> trackAppActionClick appId (getScreen KEYSTONE_CART_SCREEN) "item" "increment"
    DecrementItem _ -> trackAppActionClick appId (getScreen KEYSTONE_CART_SCREEN) "item" "decrement"
    RemoveItem _ -> trackAppActionClick appId (getScreen KEYSTONE_CART_SCREEN) "item" "remove"
    _ -> defaultPerformLog action appId

data Action
  = BackPressed
  | AfterRender
  | NoAction
  | ContinueShopping
  | SelectStoreTab String
  | GenericHeaderAction GenericHeader.Action
  | UpdateCart (Array KeystoneCartItem)
  | IncrementItem String
  | DecrementItem String
  | RemoveItem String

data ScreenOutput
  = GoBack
  | BackToStorefront String

eval :: Action -> KeystoneCartScreenState -> Eval Action ScreenOutput KeystoneCartScreenState

eval AfterRender state = continue state

eval BackPressed state = exit GoBack
eval (GenericHeaderAction GenericHeader.PrefixImgOnClick) state = exit GoBack
eval ContinueShopping state = exit (BackToStorefront "shop")
eval (SelectStoreTab tab) state = exit (BackToStorefront tab)

eval (UpdateCart items) state = continue state { data { cart = items } }

eval (IncrementItem slug) state =
  continue state { data { cart = mapItem (\i -> i { quantity = i.quantity + 1 }) slug state.data.cart } }

eval (DecrementItem slug) state =
  let next = applyDecrement slug state.data.cart
  in continue state { data { cart = next } }

eval (RemoveItem slug) state =
  continue state { data { cart = DA.filter (\i -> i.slug /= slug) state.data.cart } }

eval _ state = update state

mapItem :: (KeystoneCartItem -> KeystoneCartItem) -> String -> Array KeystoneCartItem -> Array KeystoneCartItem
mapItem f slug items =
  map (\i -> if i.slug == slug then f i else i) items

applyDecrement :: String -> Array KeystoneCartItem -> Array KeystoneCartItem
applyDecrement slug items =
  DA.mapMaybe
    (\i ->
        if i.slug == slug then
          if i.quantity <= 1 then Nothing else Just (i { quantity = i.quantity - 1 })
        else Just i)
    items
