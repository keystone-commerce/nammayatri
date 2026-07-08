let pushRef = null;
let timerId = null;

export const setSearchPushImpl = (push) => () => {
  pushRef = push;
};

export const debouncedSearchImpl = (delayMs) => (action) => () => {
  if (timerId) clearTimeout(timerId);
  timerId = setTimeout(() => {
    if (pushRef) {
      try { pushRef(action)(); } catch (e) {}
    }
  }, delayMs);
};

export const pushActionImpl = (action) => () => {
  if (pushRef) {
    try { pushRef(action)(); } catch (e) {}
  }
};
