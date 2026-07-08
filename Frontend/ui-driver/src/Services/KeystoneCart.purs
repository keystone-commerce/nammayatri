module Services.KeystoneCart where

import Prelude
import Effect (Effect)
import Screens.Types (KeystoneCartItem)

foreign import getCartImpl :: Effect (Array KeystoneCartItem)
foreign import addToCartImpl :: KeystoneCartItem -> Effect (Array KeystoneCartItem)
foreign import updateQuantityImpl :: String -> Int -> Effect (Array KeystoneCartItem)
foreign import removeFromCartImpl :: String -> Effect (Array KeystoneCartItem)
foreign import clearCartImpl :: Effect (Array KeystoneCartItem)

getCart :: Effect (Array KeystoneCartItem)
getCart = getCartImpl

addToCart :: KeystoneCartItem -> Effect (Array KeystoneCartItem)
addToCart = addToCartImpl

updateQuantity :: String -> Int -> Effect (Array KeystoneCartItem)
updateQuantity slug qty = updateQuantityImpl slug qty

removeFromCart :: String -> Effect (Array KeystoneCartItem)
removeFromCart = removeFromCartImpl

clearCart :: Effect (Array KeystoneCartItem)
clearCart = clearCartImpl
