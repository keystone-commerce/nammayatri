module Screens.KeystoneCartScreen.ScreenData where

import Screens.Types (KeystoneCartScreenState)

initData :: KeystoneCartScreenState
initData =
  { data: { cart: [] }
  , props: { showOrderPlacedPopup: false }
  }
