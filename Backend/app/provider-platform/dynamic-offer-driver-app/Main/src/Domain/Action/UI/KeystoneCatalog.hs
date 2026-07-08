module Domain.Action.UI.KeystoneCatalog
  ( getDriverKeystoneCategories,
    getDriverKeystoneProducts,
    getDriverKeystoneProduct,
    getDriverKeystoneSearch,
  )
where

import qualified API.Types.UI.KeystoneCatalog as API
import qualified Data.Aeson as A
import qualified Data.Aeson.Key as AKey
import qualified Data.Aeson.KeyMap as KM
import Data.Maybe (listToMaybe)
import qualified Data.Text as T
import qualified Domain.Types.Extra.MerchantServiceConfig as ExtraMSC
import qualified Domain.Types.Merchant as Merchant
import qualified Domain.Types.MerchantOperatingCity as DMOC
import qualified Domain.Types.MerchantServiceConfig as DMSC
import qualified Domain.Types.Person as Person
import Environment
import EulerHS.Prelude hiding (id)
import Kernel.External.Encryption (decrypt)
import Kernel.Types.Id
import Kernel.Utils.Common
import qualified SharedLogic.External.KeystoneCommerce.Flow as Keystone
import qualified SharedLogic.External.KeystoneCommerce.Types as Keystone
import qualified Storage.CachedQueries.Merchant.MerchantServiceConfig as CQMSC
import Tools.Error

type DriverContext =
  ( Maybe (Id Person.Person),
    Id Merchant.Merchant,
    Id DMOC.MerchantOperatingCity
  )

getDriverKeystoneCategories ::
  DriverContext ->
  Flow API.KeystoneCategoryListRes
getDriverKeystoneCategories ctx = do
  (cfg, apiKey) <- getKeystoneConfig ctx
  response <- Keystone.getCategories cfg apiKey
  ensureSuccess "categories" response
  pure $ API.KeystoneCategoryListRes {categories = concatMap normalizeCategoryTree response.data_}

getDriverKeystoneProducts ::
  DriverContext ->
  Maybe Int ->
  Maybe Int ->
  Maybe Text ->
  Maybe Text ->
  Maybe Text ->
  Maybe Text ->
  Maybe Text ->
  Flow API.KeystoneProductListRes
getDriverKeystoneProducts ctx page limit search categoryId brand sortByParam sortOrderParam = do
  (cfg, apiKey) <- getKeystoneConfig ctx
  response <-
    Keystone.getProducts
      cfg
      apiKey
      (Just $ fromMaybe 1 page)
      (Just $ fromMaybe 12 limit)
      (nonBlankText search)
      (nonBlankText categoryId)
      (nonBlankText brand)
      (Just $ fromMaybe "createdAt" sortByParam)
      (Just $ fromMaybe "desc" sortOrderParam)
  ensureSuccess "products" response
  pure $ API.KeystoneProductListRes {products = normalizeProduct <$> filter isActiveProduct response.data_}

getDriverKeystoneProduct ::
  DriverContext ->
  Text ->
  Flow API.KeystoneProductDetailRes
getDriverKeystoneProduct ctx slug = do
  (cfg, apiKey) <- getKeystoneConfig ctx
  response <- Keystone.getProductBySlug cfg apiKey slug
  ensureSuccess "product" response
  pure $ API.KeystoneProductDetailRes {productDetail = normalizeProductDetail response.data_}

getDriverKeystoneSearch ::
  DriverContext ->
  Maybe Text ->
  Maybe Text ->
  Maybe Int ->
  Flow API.KeystoneSearchRes
getDriverKeystoneSearch ctx q searchType limit = do
  (cfg, apiKey) <- getKeystoneConfig ctx
  response <- Keystone.search cfg apiKey (nonBlankText q) (nonBlankText searchType) limit
  ensureSuccess "search" response
  let searchData = response.data_
  pure $
    API.KeystoneSearchRes
      { products = normalizeProduct <$> filter isActiveProduct (fromMaybe [] searchData.products),
        categories = concatMap normalizeCategoryTree (fromMaybe [] searchData.categories)
      }

getKeystoneConfig :: DriverContext -> Flow (ExtraMSC.KeystoneCommerceConfig, Text)
getKeystoneConfig (_, merchantId, merchantOperatingCityId) = do
  merchantServiceConfig <-
    CQMSC.findByServiceAndCity (DMSC.CommerceService ExtraMSC.KeystoneCommerce) merchantOperatingCityId
      >>= fromMaybeM (MerchantServiceConfigNotFound merchantId.getId "Commerce" (show ExtraMSC.KeystoneCommerce))
  cfg <- case merchantServiceConfig.serviceConfig of
    DMSC.CommerceServiceConfig keystoneConfig -> pure keystoneConfig
    _ -> throwError $ ServiceConfigError "Service config is not Keystone commerce config."
  unless cfg.enabled $ throwError $ InvalidRequest "Keystone catalog is disabled for this city."
  apiKey <- decrypt cfg.apiKey
  pure (cfg, apiKey)

ensureSuccess :: Text -> Keystone.KeystoneEnvelope a -> Flow ()
ensureSuccess label response =
  when (response.statusCode >= 400) $
    throwError $ InternalError ("Keystone " <> label <> " failed: " <> response.message)

normalizeProduct :: Keystone.KeystoneProduct -> API.KeystoneProduct
normalizeProduct keystoneProduct =
  let images = valueToTextList keystoneProduct.images
   in API.KeystoneProduct
        { id = valueToText keystoneProduct.id,
          name = valueToText keystoneProduct.name,
          slug = valueToText keystoneProduct.slug,
          description = productDescription keystoneProduct,
          brand = valueToText keystoneProduct.brand,
          sku = valueToText keystoneProduct.sku,
          categoryId = valueToText keystoneProduct.categoryId,
          defaultMrp = valueToText keystoneProduct.defaultMrp,
          defaultSellingPrice = valueToText keystoneProduct.defaultSellingPrice,
          image = fromMaybe "" (listToMaybe images),
          images,
          features = productFeatures keystoneProduct
        }

normalizeProductDetail :: Keystone.KeystoneProduct -> API.KeystoneProductDetail
normalizeProductDetail keystoneProduct =
  API.KeystoneProductDetail
    { id = valueToText keystoneProduct.id,
      name = valueToText keystoneProduct.name,
      slug = valueToText keystoneProduct.slug,
      brand = valueToText keystoneProduct.brand,
      sku = valueToText keystoneProduct.sku,
      categoryId = valueToText keystoneProduct.categoryId,
      defaultMrp = valueToText keystoneProduct.defaultMrp,
      defaultSellingPrice = valueToText keystoneProduct.defaultSellingPrice,
      description = productDescription keystoneProduct,
      images = valueToTextList keystoneProduct.images,
      features = productFeatures keystoneProduct
    }

normalizeCategoryTree :: Keystone.KeystoneCategory -> [API.KeystoneCategory]
normalizeCategoryTree category
  | category.isActive == Just False = []
  | otherwise = normalizeCategory category : concatMap normalizeCategoryTree (fromMaybe [] category.children)

normalizeCategory :: Keystone.KeystoneCategory -> API.KeystoneCategory
normalizeCategory category =
  API.KeystoneCategory
    { id = valueToText category.id,
      name = valueToText category.name,
      slug = valueToText category.slug
    }

productDescription :: Keystone.KeystoneProduct -> Text
productDescription keystoneProduct =
  fromMaybe "" . find (not . T.null) $
    [ valueToText keystoneProduct.description,
      valueToText keystoneProduct.shortDescription
    ]

productFeatures :: Keystone.KeystoneProduct -> [Text]
productFeatures keystoneProduct =
  fromMaybe [] . find (not . null) $
    [ valueToTextList keystoneProduct.features,
      valueToTextList keystoneProduct.highlights,
      valueToTextList keystoneProduct.keyFeatures
    ]

isActiveProduct :: Keystone.KeystoneProduct -> Bool
isActiveProduct keystoneProduct = keystoneProduct.isActive /= Just False

nonBlankText :: Maybe Text -> Maybe Text
nonBlankText = \case
  Just value | not (T.null value) -> Just value
  _ -> Nothing

valueToText :: Maybe A.Value -> Text
valueToText = maybe "" valueToText'

valueToText' :: A.Value -> Text
valueToText' = \case
  A.String value -> value
  A.Number value -> show value
  A.Bool True -> "true"
  A.Bool False -> "false"
  _ -> ""

valueToTextList :: Maybe A.Value -> [Text]
valueToTextList = \case
  Just (A.Array values) -> mapMaybe valueItemToText (toList values)
  Just value ->
    let textValue = valueToText' value
     in [textValue | not (T.null textValue)]
  Nothing -> []

valueItemToText :: A.Value -> Maybe Text
valueItemToText = \case
  A.Object obj -> listToMaybe . filter (not . T.null) $ lookupObjectText obj <$> ["label", "name", "title", "value"]
  value ->
    let textValue = valueToText' value
     in guard (not $ T.null textValue) $> textValue

lookupObjectText :: A.Object -> String -> Text
lookupObjectText obj key = maybe "" valueToText' $ KM.lookup (AKey.fromString key) obj
