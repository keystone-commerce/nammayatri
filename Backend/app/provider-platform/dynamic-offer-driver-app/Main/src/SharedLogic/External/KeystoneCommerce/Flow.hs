module SharedLogic.External.KeystoneCommerce.Flow where

import Domain.Types.Extra.MerchantServiceConfig (KeystoneCommerceConfig)
import EulerHS.Types (EulerClient)
import Kernel.Prelude
import Kernel.Tools.Metrics.CoreMetrics (CoreMetrics)
import Kernel.Types.Error
import Kernel.Utils.Common
import Kernel.Utils.Monitoring.Prometheus.Servant (SanitizedUrl)
import qualified SharedLogic.External.KeystoneCommerce.API as API
import SharedLogic.External.KeystoneCommerce.Types

getCategories ::
  (CoreMetrics m, MonadFlow m, HasShortDurationRetryCfg r c, HasRequestId r, MonadReader r m) =>
  KeystoneCommerceConfig ->
  Text ->
  m (KeystoneEnvelope [KeystoneCategory])
getCategories cfg apiKey =
  callKeystone cfg "KeystoneCategories" "UNABLE_TO_CALL_KEYSTONE_CATEGORIES_API" API.keystoneCategoriesAPI (API.keystoneCategories (Just apiKey))

getProducts ::
  (CoreMetrics m, MonadFlow m, HasShortDurationRetryCfg r c, HasRequestId r, MonadReader r m) =>
  KeystoneCommerceConfig ->
  Text ->
  Maybe Int ->
  Maybe Int ->
  Maybe Text ->
  Maybe Text ->
  Maybe Text ->
  Maybe Text ->
  Maybe Text ->
  m (KeystoneEnvelope [KeystoneProduct])
getProducts cfg apiKey page limit searchText categoryId brand sortBy sortOrder =
  callKeystone cfg "KeystoneProducts" "UNABLE_TO_CALL_KEYSTONE_PRODUCTS_API" API.keystoneProductsAPI $
    API.keystoneProducts (Just apiKey) page limit searchText categoryId brand sortBy sortOrder

getProductBySlug ::
  (CoreMetrics m, MonadFlow m, HasShortDurationRetryCfg r c, HasRequestId r, MonadReader r m) =>
  KeystoneCommerceConfig ->
  Text ->
  Text ->
  m (KeystoneEnvelope KeystoneProduct)
getProductBySlug cfg apiKey slug =
  callKeystone cfg "KeystoneProductBySlug" "UNABLE_TO_CALL_KEYSTONE_PRODUCT_API" API.keystoneProductBySlugAPI $
    API.keystoneProductBySlug slug (Just apiKey)

search ::
  (CoreMetrics m, MonadFlow m, HasShortDurationRetryCfg r c, HasRequestId r, MonadReader r m) =>
  KeystoneCommerceConfig ->
  Text ->
  Maybe Text ->
  Maybe Text ->
  Maybe Int ->
  m (KeystoneEnvelope KeystoneSearchData)
search cfg apiKey q searchType limit =
  callKeystone cfg "KeystoneSearch" "UNABLE_TO_CALL_KEYSTONE_SEARCH_API" API.keystoneSearchAPI $
    API.keystoneSearch (Just apiKey) q searchType limit cfg.source

callKeystone ::
  (CoreMetrics m, MonadFlow m, HasShortDurationRetryCfg r c, HasRequestId r, MonadReader r m, SanitizedUrl api, ToJSON a) =>
  KeystoneCommerceConfig ->
  Text ->
  Text ->
  Proxy api ->
  EulerClient a ->
  m a
callKeystone cfg callName errorCode api clientCall =
  withShortRetry $
    callAPI cfg.url clientCall callName api
      >>= fromEitherM (ExternalAPICallError (Just errorCode) cfg.url)
