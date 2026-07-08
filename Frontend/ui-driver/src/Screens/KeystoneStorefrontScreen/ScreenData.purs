module Screens.KeystoneStorefrontScreen.ScreenData where

import Data.Maybe (Maybe(..))
import Screens.Types (KeystoneStorefrontScreenState)

initData :: KeystoneStorefrontScreenState
initData =
  { data:
      { products: []
      , categories: []
      , cart: []
      , catalogError: Nothing
      , categoriesError: Nothing
      }
  , props:
      { isProductsLoading: true
      , isCategoriesLoading: true
      , searchQuery: ""
      , activeCategoryId: ""
      , activeTab: "shop"
      , productPage: 1
      , pageSize: 20
      , hasMoreProducts: true
      , isLoadingMore: false
      , searchSeq: 0
      }
  }
