module Screens.KeystoneProductDetailScreen.ScreenData where

import Data.Maybe (Maybe(..))
import Screens.Types (KeystoneProductDetailScreenState)

initData :: KeystoneProductDetailScreenState
initData =
  { data:
      { slug: ""
      , product: Nothing
      , cart: []
      , error: Nothing
      }
  , props:
      { isLoading: true
      , quantity: 1
      }
  }
