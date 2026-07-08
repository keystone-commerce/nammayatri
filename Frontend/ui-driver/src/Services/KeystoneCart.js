const STORAGE_KEY = "KEYSTONE_CART";

const safeString = (val) => (val === null || val === undefined ? "" : String(val));

const memoryCart = () => {
  window.__KEYSTONE_CART_CACHE = window.__KEYSTONE_CART_CACHE || [];
  return window.__KEYSTONE_CART_CACHE;
};

const readRaw = () => {
  try {
    if (window.JBridge && typeof window.JBridge.getKeysInSharedPref === "function") {
      const raw = window.JBridge.getKeysInSharedPref(STORAGE_KEY);
      if (raw && raw !== "__failed" && raw !== "(null)" && raw !== "null") return raw;
    }
    if (typeof window.localStorage !== "undefined") {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (raw) return raw;
    }
  } catch (e) {}
  return "";
};

const writeRaw = (value) => {
  try {
    if (window.JBridge && typeof window.JBridge.setKeysInSharedPrefs === "function") {
      window.JBridge.setKeysInSharedPrefs(STORAGE_KEY, value);
    }
    if (typeof window.localStorage !== "undefined") {
      window.localStorage.setItem(STORAGE_KEY, value);
    }
  } catch (e) {}
};

const normalizeItem = (item) => ({
  slug: safeString(item.slug),
  name: safeString(item.name),
  brand: safeString(item.brand),
  image: safeString(item.image),
  defaultMrp: safeString(item.defaultMrp),
  defaultSellingPrice: safeString(item.defaultSellingPrice),
  quantity: Number.isFinite(Number(item.quantity)) && Number(item.quantity) > 0 ? Math.floor(Number(item.quantity)) : 1
});

const readCart = () => {
  const raw = readRaw();
  if (!raw) return memoryCart();
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return memoryCart();
    const cart = parsed
      .filter((item) => item && item.slug)
      .map(normalizeItem);
    window.__KEYSTONE_CART_CACHE = cart;
    return cart;
  } catch (e) {
    return memoryCart();
  }
};

const writeCart = (items) => {
  window.__KEYSTONE_CART_CACHE = items.map(normalizeItem);
  writeRaw(JSON.stringify(items));
};

export const getCartImpl = () => readCart();

export const addToCartImpl = (item) => () => {
  const normalized = normalizeItem(item);
  const cart = readCart();
  const idx = cart.findIndex((c) => c.slug === normalized.slug);
  if (idx >= 0) {
    cart[idx].quantity = cart[idx].quantity + normalized.quantity;
  } else {
    cart.push(normalized);
  }
  writeCart(cart);
  return cart;
};

export const updateQuantityImpl = (slug) => (quantity) => () => {
  const cart = readCart();
  const idx = cart.findIndex((c) => c.slug === slug);
  if (idx >= 0) {
    if (quantity <= 0) {
      cart.splice(idx, 1);
    } else {
      cart[idx].quantity = Math.floor(quantity);
    }
  }
  writeCart(cart);
  return cart;
};

export const removeFromCartImpl = (slug) => () => {
  const cart = readCart().filter((c) => c.slug !== slug);
  writeCart(cart);
  return cart;
};

export const clearCartImpl = () => () => {
  writeCart([]);
  return [];
};
