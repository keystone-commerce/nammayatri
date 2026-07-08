module Screens.KeystoneCartScreen.Handler where

import Engineering.Helpers.BackTrack (getState)
import Prelude (bind, pure, ($), (<$>))
import Screens.KeystoneCartScreen.Controller (ScreenOutput(..))
import Control.Monad.Except.Trans (lift)
import Control.Transformers.Back.Trans as App
import PrestoDOM.Core.Types.Language.Flow (runLoggableScreen)
import Screens.KeystoneCartScreen.View as KeystoneCartScreen
import Types.App (KEYSTONE_CART_SCREEN_OUTPUT(..), GlobalState(..), FlowBT)

keystoneCartScreen :: FlowBT String KEYSTONE_CART_SCREEN_OUTPUT
keystoneCartScreen = do
  (GlobalState state) <- getState
  action <- lift $ lift $ runLoggableScreen $ KeystoneCartScreen.screen state.keystoneCartScreen
  case action of
    GoBack -> App.BackT $ pure App.GoBack
    BackToStorefront tab -> App.BackT $ App.BackPoint <$> (pure $ GO_TO_KEYSTONE_STOREFRONT_FROM_CART tab)
