module SharedLogic.External.KeystoneCommerce.API where

import qualified EulerHS.Types as ET
import Kernel.Prelude
import Servant
import SharedLogic.External.KeystoneCommerce.Types

type KeystoneCategoriesAPI =
  "categories"
    :> Header "x-api-key" Text
    :> Get '[JSON] (KeystoneEnvelope [KeystoneCategory])

keystoneCategoriesAPI :: Proxy KeystoneCategoriesAPI
keystoneCategoriesAPI = Proxy

keystoneCategories :: Maybe Text -> ET.EulerClient (KeystoneEnvelope [KeystoneCategory])
keystoneCategories = ET.client keystoneCategoriesAPI

type KeystoneProductsAPI =
  "products"
    :> Header "x-api-key" Text
    :> QueryParam "page" Int
    :> QueryParam "limit" Int
    :> QueryParam "search" Text
    :> QueryParam "categoryId" Text
    :> QueryParam "brand" Text
    :> QueryParam "sortBy" Text
    :> QueryParam "sortOrder" Text
    :> Get '[JSON] (KeystoneEnvelope [KeystoneProduct])

keystoneProductsAPI :: Proxy KeystoneProductsAPI
keystoneProductsAPI = Proxy

keystoneProducts :: Maybe Text -> Maybe Int -> Maybe Int -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> ET.EulerClient (KeystoneEnvelope [KeystoneProduct])
keystoneProducts = ET.client keystoneProductsAPI

type KeystoneProductBySlugAPI =
  "products"
    :> Capture "slug" Text
    :> Header "x-api-key" Text
    :> Get '[JSON] (KeystoneEnvelope KeystoneProduct)

keystoneProductBySlugAPI :: Proxy KeystoneProductBySlugAPI
keystoneProductBySlugAPI = Proxy

keystoneProductBySlug :: Text -> Maybe Text -> ET.EulerClient (KeystoneEnvelope KeystoneProduct)
keystoneProductBySlug = ET.client keystoneProductBySlugAPI

type KeystoneSearchAPI =
  "search"
    :> Header "x-api-key" Text
    :> QueryParam "q" Text
    :> QueryParam "type" Text
    :> QueryParam "limit" Int
    :> QueryParam "source" Text
    :> Get '[JSON] (KeystoneEnvelope KeystoneSearchData)

keystoneSearchAPI :: Proxy KeystoneSearchAPI
keystoneSearchAPI = Proxy

keystoneSearch :: Maybe Text -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Text -> ET.EulerClient (KeystoneEnvelope KeystoneSearchData)
keystoneSearch = ET.client keystoneSearchAPI
