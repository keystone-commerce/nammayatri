module Screens.KeystoneStorefrontScreen.Handler where

import Engineering.Helpers.BackTrack (getState)
import Prelude (bind, pure, ($), (<$>))
import Screens.KeystoneStorefrontScreen.Controller (ScreenOutput(..))
import Control.Monad.Except.Trans (lift)
import Control.Transformers.Back.Trans as App
import PrestoDOM.Core.Types.Language.Flow (runLoggableScreen)
import Screens.KeystoneStorefrontScreen.View as KeystoneStorefrontScreen
import Types.App (KEYSTONE_STOREFRONT_SCREEN_OUTPUT(..), GlobalState(..), FlowBT)

keystoneStorefrontScreen :: FlowBT String KEYSTONE_STOREFRONT_SCREEN_OUTPUT
keystoneStorefrontScreen = do
  (GlobalState state) <- getState
  action <- lift $ lift $ runLoggableScreen $ KeystoneStorefrontScreen.screen state.keystoneStorefrontScreen
  case action of
    GoBack -> App.BackT $ pure App.GoBack
    OpenProduct product st -> App.BackT $ App.BackPoint <$> (pure $ GO_TO_KEYSTONE_PRODUCT_DETAIL product st)
    OpenCart st -> App.BackT $ App.BackPoint <$> (pure $ GO_TO_KEYSTONE_CART_FROM_STOREFRONT st)
