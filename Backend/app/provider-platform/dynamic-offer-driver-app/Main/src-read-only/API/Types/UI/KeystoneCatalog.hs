{-# OPTIONS_GHC -Wno-unused-imports #-}

module API.Types.UI.KeystoneCatalog where

import Data.OpenApi (ToSchema)
import EulerHS.Prelude hiding (id)
import qualified Kernel.Prelude
import Servant
import Tools.Auth

data KeystoneCategory = KeystoneCategory {id :: Kernel.Prelude.Text, name :: Kernel.Prelude.Text, slug :: Kernel.Prelude.Text}
  deriving stock (Generic)
  deriving anyclass (ToJSON, FromJSON, ToSchema)

data KeystoneCategoryListRes = KeystoneCategoryListRes {categories :: [KeystoneCategory]}
  deriving stock (Generic)
  deriving anyclass (ToJSON, FromJSON, ToSchema)

data KeystoneProduct = KeystoneProduct
  { brand :: Kernel.Prelude.Text,
    categoryId :: Kernel.Prelude.Text,
    defaultMrp :: Kernel.Prelude.Text,
    defaultSellingPrice :: Kernel.Prelude.Text,
    description :: Kernel.Prelude.Text,
    features :: [Kernel.Prelude.Text],
    id :: Kernel.Prelude.Text,
    image :: Kernel.Prelude.Text,
    images :: [Kernel.Prelude.Text],
    name :: Kernel.Prelude.Text,
    sku :: Kernel.Prelude.Text,
    slug :: Kernel.Prelude.Text
  }
  deriving stock (Generic)
  deriving anyclass (ToJSON, FromJSON, ToSchema)

data KeystoneProductDetail = KeystoneProductDetail
  { brand :: Kernel.Prelude.Text,
    categoryId :: Kernel.Prelude.Text,
    defaultMrp :: Kernel.Prelude.Text,
    defaultSellingPrice :: Kernel.Prelude.Text,
    description :: Kernel.Prelude.Text,
    features :: [Kernel.Prelude.Text],
    id :: Kernel.Prelude.Text,
    images :: [Kernel.Prelude.Text],
    name :: Kernel.Prelude.Text,
    sku :: Kernel.Prelude.Text,
    slug :: Kernel.Prelude.Text
  }
  deriving stock (Generic)
  deriving anyclass (ToJSON, FromJSON, ToSchema)

data KeystoneProductDetailRes = KeystoneProductDetailRes {productDetail :: KeystoneProductDetail}
  deriving stock (Generic)
  deriving anyclass (ToJSON, FromJSON, ToSchema)

data KeystoneProductListRes = KeystoneProductListRes {products :: [KeystoneProduct]}
  deriving stock (Generic)
  deriving anyclass (ToJSON, FromJSON, ToSchema)

data KeystoneSearchRes = KeystoneSearchRes {categories :: [KeystoneCategory], products :: [KeystoneProduct]}
  deriving stock (Generic)
  deriving anyclass (ToJSON, FromJSON, ToSchema)
