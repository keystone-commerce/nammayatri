module SharedLogic.External.KeystoneCommerce.Types where

import Data.Aeson
import Kernel.Prelude

data KeystoneEnvelope a = KeystoneEnvelope
  { statusCode :: Int,
    message :: Text,
    data_ :: a,
    meta :: Maybe Value
  }
  deriving stock (Generic, Show)

instance FromJSON a => FromJSON (KeystoneEnvelope a) where
  parseJSON = withObject "KeystoneEnvelope" $ \obj ->
    KeystoneEnvelope
      <$> obj .: "statusCode"
      <*> obj .: "message"
      <*> obj .: "data"
      <*> obj .:? "meta"

instance ToJSON a => ToJSON (KeystoneEnvelope a) where
  toJSON KeystoneEnvelope {..} =
    object
      [ "statusCode" .= statusCode,
        "message" .= message,
        "data" .= data_,
        "meta" .= meta
      ]

data KeystoneProduct = KeystoneProduct
  { id :: Maybe Value,
    name :: Maybe Value,
    slug :: Maybe Value,
    description :: Maybe Value,
    shortDescription :: Maybe Value,
    brand :: Maybe Value,
    sku :: Maybe Value,
    categoryId :: Maybe Value,
    defaultMrp :: Maybe Value,
    defaultSellingPrice :: Maybe Value,
    images :: Maybe Value,
    features :: Maybe Value,
    highlights :: Maybe Value,
    keyFeatures :: Maybe Value,
    isActive :: Maybe Bool
  }
  deriving stock (Generic, Show)
  deriving anyclass (FromJSON, ToJSON)

data KeystoneCategory = KeystoneCategory
  { id :: Maybe Value,
    name :: Maybe Value,
    slug :: Maybe Value,
    description :: Maybe Value,
    parentId :: Maybe Value,
    children :: Maybe [KeystoneCategory],
    isActive :: Maybe Bool
  }
  deriving stock (Generic, Show)
  deriving anyclass (FromJSON, ToJSON)

data KeystoneSearchData = KeystoneSearchData
  { products :: Maybe [KeystoneProduct],
    categories :: Maybe [KeystoneCategory]
  }
  deriving stock (Generic, Show)
  deriving anyclass (FromJSON, ToJSON)
