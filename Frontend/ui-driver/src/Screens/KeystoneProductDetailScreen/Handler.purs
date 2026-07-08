module Screens.KeystoneProductDetailScreen.Handler where

import Engineering.Helpers.BackTrack (getState)
import Prelude (bind, pure, ($), (<$>))
import Screens.KeystoneProductDetailScreen.Controller (ScreenOutput(..))
import Control.Monad.Except.Trans (lift)
import Control.Transformers.Back.Trans as App
import PrestoDOM.Core.Types.Language.Flow (runLoggableScreen)
import Screens.KeystoneProductDetailScreen.View as KeystoneProductDetailScreen
import Types.App (KEYSTONE_PRODUCT_DETAIL_SCREEN_OUTPUT(..), GlobalState(..), FlowBT)

keystoneProductDetailScreen :: FlowBT String KEYSTONE_PRODUCT_DETAIL_SCREEN_OUTPUT
keystoneProductDetailScreen = do
  (GlobalState state) <- getState
  action <- lift $ lift $ runLoggableScreen $ KeystoneProductDetailScreen.screen state.keystoneProductDetailScreen
  case action of
    GoBack -> App.BackT $ pure App.GoBack
    GoToCartScreen st -> App.BackT $ App.BackPoint <$> (pure $ GO_TO_KEYSTONE_CART_FROM_DETAIL st)
    BackToStorefront tab -> App.BackT $ App.BackPoint <$> (pure $ GO_TO_KEYSTONE_STOREFRONT_FROM_DETAIL tab)
