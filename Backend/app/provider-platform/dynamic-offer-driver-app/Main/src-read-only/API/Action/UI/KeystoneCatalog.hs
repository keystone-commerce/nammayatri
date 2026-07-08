{-# OPTIONS_GHC -Wno-orphans #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

module API.Action.UI.KeystoneCatalog
  ( API,
    handler,
  )
where

import qualified API.Types.UI.KeystoneCatalog
import qualified Control.Lens
import qualified Domain.Action.UI.KeystoneCatalog
import qualified Domain.Types.Merchant
import qualified Domain.Types.MerchantOperatingCity
import qualified Domain.Types.Person
import qualified Environment
import EulerHS.Prelude
import qualified Kernel.Prelude
import qualified Kernel.Types.Id
import Kernel.Utils.Common
import Servant
import Storage.Beam.SystemConfigs ()
import Tools.Auth

type API =
  ( TokenAuth :> "driver" :> "keystone" :> "categories"
      :> Get
           ('[JSON])
           API.Types.UI.KeystoneCatalog.KeystoneCategoryListRes
      :<|> TokenAuth
      :> "driver"
      :> "keystone"
      :> "products"
      :> QueryParam "page" Kernel.Prelude.Int
      :> QueryParam
           "limit"
           Kernel.Prelude.Int
      :> QueryParam
           "search"
           Kernel.Prelude.Text
      :> QueryParam
           "categoryId"
           Kernel.Prelude.Text
      :> QueryParam
           "brand"
           Kernel.Prelude.Text
      :> QueryParam
           "sortBy"
           Kernel.Prelude.Text
      :> QueryParam
           "sortOrder"
           Kernel.Prelude.Text
      :> Get
           ('[JSON])
           API.Types.UI.KeystoneCatalog.KeystoneProductListRes
      :<|> TokenAuth
      :> "driver"
      :> "keystone"
      :> "product"
      :> Capture
           "slug"
           Kernel.Prelude.Text
      :> Get
           ('[JSON])
           API.Types.UI.KeystoneCatalog.KeystoneProductDetailRes
      :<|> TokenAuth
      :> "driver"
      :> "keystone"
      :> "search"
      :> QueryParam
           "q"
           Kernel.Prelude.Text
      :> QueryParam
           "searchType"
           Kernel.Prelude.Text
      :> QueryParam
           "limit"
           Kernel.Prelude.Int
      :> Get
           ('[JSON])
           API.Types.UI.KeystoneCatalog.KeystoneSearchRes
  )

handler :: Environment.FlowServer API
handler = getDriverKeystoneCategories :<|> getDriverKeystoneProducts :<|> getDriverKeystoneProduct :<|> getDriverKeystoneSearch

getDriverKeystoneCategories ::
  ( ( Kernel.Types.Id.Id Domain.Types.Person.Person,
      Kernel.Types.Id.Id Domain.Types.Merchant.Merchant,
      Kernel.Types.Id.Id Domain.Types.MerchantOperatingCity.MerchantOperatingCity
    ) ->
    Environment.FlowHandler API.Types.UI.KeystoneCatalog.KeystoneCategoryListRes
  )
getDriverKeystoneCategories a1 = withFlowHandlerAPI $ Domain.Action.UI.KeystoneCatalog.getDriverKeystoneCategories (Control.Lens.over Control.Lens._1 Kernel.Prelude.Just a1)

getDriverKeystoneProducts ::
  ( ( Kernel.Types.Id.Id Domain.Types.Person.Person,
      Kernel.Types.Id.Id Domain.Types.Merchant.Merchant,
      Kernel.Types.Id.Id Domain.Types.MerchantOperatingCity.MerchantOperatingCity
    ) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Int) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Int) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Text) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Text) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Text) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Text) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Text) ->
    Environment.FlowHandler API.Types.UI.KeystoneCatalog.KeystoneProductListRes
  )
getDriverKeystoneProducts a8 a7 a6 a5 a4 a3 a2 a1 = withFlowHandlerAPI $ Domain.Action.UI.KeystoneCatalog.getDriverKeystoneProducts (Control.Lens.over Control.Lens._1 Kernel.Prelude.Just a8) a7 a6 a5 a4 a3 a2 a1

getDriverKeystoneProduct ::
  ( ( Kernel.Types.Id.Id Domain.Types.Person.Person,
      Kernel.Types.Id.Id Domain.Types.Merchant.Merchant,
      Kernel.Types.Id.Id Domain.Types.MerchantOperatingCity.MerchantOperatingCity
    ) ->
    Kernel.Prelude.Text ->
    Environment.FlowHandler API.Types.UI.KeystoneCatalog.KeystoneProductDetailRes
  )
getDriverKeystoneProduct a2 a1 = withFlowHandlerAPI $ Domain.Action.UI.KeystoneCatalog.getDriverKeystoneProduct (Control.Lens.over Control.Lens._1 Kernel.Prelude.Just a2) a1

getDriverKeystoneSearch ::
  ( ( Kernel.Types.Id.Id Domain.Types.Person.Person,
      Kernel.Types.Id.Id Domain.Types.Merchant.Merchant,
      Kernel.Types.Id.Id Domain.Types.MerchantOperatingCity.MerchantOperatingCity
    ) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Text) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Text) ->
    Kernel.Prelude.Maybe (Kernel.Prelude.Int) ->
    Environment.FlowHandler API.Types.UI.KeystoneCatalog.KeystoneSearchRes
  )
getDriverKeystoneSearch a4 a3 a2 a1 = withFlowHandlerAPI $ Domain.Action.UI.KeystoneCatalog.getDriverKeystoneSearch (Control.Lens.over Control.Lens._1 Kernel.Prelude.Just a4) a3 a2 a1
