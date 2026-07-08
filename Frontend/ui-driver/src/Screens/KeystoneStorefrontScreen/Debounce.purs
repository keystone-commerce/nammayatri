module Screens.KeystoneStorefrontScreen.Debounce where

import Prelude (Unit)
import Effect (Effect)

foreign import setSearchPushImpl :: forall a. (a -> Effect Unit) -> Effect Unit
foreign import debouncedSearchImpl :: forall a. Int -> a -> Effect Unit
foreign import pushActionImpl :: forall a. a -> Effect Unit

setSearchPush :: forall a. (a -> Effect Unit) -> Effect Unit
setSearchPush = setSearchPushImpl

debouncedSearch :: forall a. Int -> a -> Effect Unit
debouncedSearch = debouncedSearchImpl

pushAction :: forall a. a -> Effect Unit
pushAction = pushActionImpl
