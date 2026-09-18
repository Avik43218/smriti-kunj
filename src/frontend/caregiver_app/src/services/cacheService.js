/**
 * Lightweight Caching Service for Caregiver App
 * 
 * Features:
 * - LocalStorage persistence keyed by endpoint + optional patient ID
 * - Stale-while-revalidate (SWR) pattern: renders cached data immediately,
 *   fetches fresh data in the background, and updates both UI and localStorage.
 * - Timestamp tracking with 5-minute freshness threshold. Stale entries (> 5 min)
 *   are served immediately without blocking, while fresh data revalidates in the background.
 * - Explicitly excludes all auth / login / OTP endpoints from caching.
 * - Safe error handling for storage quota limits and SSR/window safety.
 */

export const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes in milliseconds
export const CACHE_PREFIX = 'smriti_cache:';

/**
 * Checks whether an endpoint belongs to auth/login/OTP flows.
 * Such endpoints must NEVER be cached.
 * 
 * @param {string} endpoint 
 * @returns {boolean}
 */
export const isAuthEndpoint = (endpoint) => {
  if (!endpoint || typeof endpoint !== 'string') return false;
  const lower = endpoint.toLowerCase();
  return (
    lower.includes('/api/auth') ||
    lower.includes('/login') ||
    lower.includes('/register') ||
    lower.includes('/otp') ||
    lower.includes('/logout')
  );
};

/**
 * Generates a consistent cache key from endpoint and optional patientId.
 * Returns null for auth endpoints to prevent caching.
 * 
 * @param {string} endpoint 
 * @param {string|number|null} patientId 
 * @returns {string|null}
 */
export const getCacheKey = (endpoint, patientId = null) => {
  if (!endpoint || isAuthEndpoint(endpoint)) {
    return null;
  }
  const cleanEndpoint = endpoint.trim().replace(/\/+$/, '');
  const cleanId = patientId !== null && patientId !== undefined ? String(patientId).trim() : '';
  return cleanId ? `${CACHE_PREFIX}${cleanEndpoint}:${cleanId}` : `${CACHE_PREFIX}${cleanEndpoint}`;
};

/**
 * Reads a cache entry from localStorage.
 * 
 * @param {string} key 
 * @returns {{ data: any, timestamp: number, isStale: boolean, ageMs: number } | null}
 */
export const readCache = (key) => {
  if (!key || typeof window === 'undefined' || !window.localStorage) {
    return null;
  }

  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;

    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || typeof parsed.timestamp !== 'number') {
      return null;
    }

    const age = Date.now() - parsed.timestamp;
    const isStale = age > CACHE_TTL_MS;

    return {
      data: parsed.data,
      timestamp: parsed.timestamp,
      isStale,
      ageMs: age,
    };
  } catch (err) {
    console.warn(`[cacheService] Failed to read cache key "${key}":`, err);
    return null;
  }
};

/**
 * Writes data with the current timestamp into localStorage.
 * 
 * @param {string} key 
 * @param {any} data 
 * @returns {boolean} True if saved successfully
 */
export const writeCache = (key, data) => {
  if (!key || typeof window === 'undefined' || !window.localStorage) {
    return false;
  }

  try {
    const payload = {
      timestamp: Date.now(),
      data,
    };
    localStorage.setItem(key, JSON.stringify(payload));
    return true;
  } catch (err) {
    console.warn(`[cacheService] Failed to write cache key "${key}" (quota exceeded?):`, err);
    return false;
  }
};

/**
 * Removes a specific cache entry.
 * 
 * @param {string} endpoint 
 * @param {string|number|null} patientId 
 */
export const invalidateCache = (endpoint, patientId = null) => {
  const key = getCacheKey(endpoint, patientId);
  if (key && typeof window !== 'undefined' && window.localStorage) {
    try {
      localStorage.removeItem(key);
    } catch (err) {
      console.warn(`[cacheService] Failed to invalidate cache key "${key}":`, err);
    }
  }
};

/**
 * Removes all cache entries matching a prefix or endpoint substring.
 * Useful when mutating collections (e.g. invalidating all patient caches).
 * 
 * @param {string} [pattern] Optional substring to match. Defaults to clearing all smriti_cache:* keys.
 */
export const clearCacheMatching = (pattern = '') => {
  if (typeof window === 'undefined' || !window.localStorage) return;

  try {
    const keysToRemove = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && key.startsWith(CACHE_PREFIX)) {
        if (!pattern || key.includes(pattern)) {
          keysToRemove.push(key);
        }
      }
    }
    keysToRemove.forEach((key) => localStorage.removeItem(key));
  } catch (err) {
    console.warn('[cacheService] Failed to clear matched cache:', err);
  }
};

/**
 * Core Stale-While-Revalidate (SWR) fetch helper.
 * 
 * Behavior:
 * 1. Checks localStorage for a cached value keyed by endpoint + patientId.
 * 2. If present (fresh OR stale):
 *    - Immediately returns cached data to render it without waiting.
 *    - Spawns a background fetch to retrieve fresh data.
 *    - When fresh data arrives, updates localStorage and invokes onUpdate(freshData).
 * 3. If NOT present:
 *    - Awaits fresh data from fetcher.
 *    - Saves to localStorage and returns it.
 * 4. Stale evaluation:
 *    - Entries older than 5 minutes (CACHE_TTL_MS) are treated as stale,
 *      meaning they are returned immediately while fresh data revalidates in the background.
 * 5. Auth / login / OTP endpoints bypass cache entirely.
 * 
 * @param {Object} params
 * @param {string} params.endpoint - API endpoint (e.g., '/api/caregiver/patients')
 * @param {string|number|null} [params.patientId] - Optional patient ID for scoping
 * @param {Function} params.fetcher - Async function performing network call
 * @param {Function} [params.onUpdate] - Callback invoked when fresh background data arrives: (freshData, meta) => void
 * @param {boolean} [params.forceRefresh=false] - If true, ignores cache and fetches fresh
 * @returns {Promise<any>}
 */
export const swrFetch = async ({
  endpoint,
  patientId = null,
  fetcher,
  onUpdate = null,
  forceRefresh = false,
}) => {
  const key = getCacheKey(endpoint, patientId);

  // If endpoint is excluded (e.g. auth), execute fetcher directly
  if (!key) {
    return await fetcher();
  }

  const cached = !forceRefresh ? readCache(key) : null;

  // Background revalidation runner
  const runBackgroundRevalidate = async () => {
    try {
      const freshData = await fetcher();
      if (freshData !== undefined && freshData !== null) {
        writeCache(key, freshData);
        if (typeof onUpdate === 'function') {
          onUpdate(freshData, { fromCache: false, isStale: false });
        }
      }
      return freshData;
    } catch (err) {
      console.warn(`[cacheService] Background fetch failed for "${key}":`, err.message);
      // Notice: we do not overwrite or clear the cached data on background network failure
    }
  };

  // Cache HIT (fresh or stale):
  if (cached && cached.data !== undefined && cached.data !== null) {
    // If onUpdate callback is provided, fire background fetch without blocking and return cached immediately!
    if (typeof onUpdate === 'function') {
      runBackgroundRevalidate();
      return cached.data;
    }

    // If no onUpdate callback is provided:
    // If data is fresh (< 5 min), return immediately and revalidate quietly in background
    if (!cached.isStale) {
      runBackgroundRevalidate();
      return cached.data;
    }

    // If data is stale (> 5 min) and no onUpdate callback was supplied:
    // Try to await fresh data, but fall back to cached data if network fails
    try {
      const fresh = await runBackgroundRevalidate();
      return fresh !== undefined ? fresh : cached.data;
    } catch {
      return cached.data;
    }
  }

  // Cache MISS: must await network fetch
  const freshData = await fetcher();
  if (freshData !== undefined && freshData !== null) {
    writeCache(key, freshData);
  }
  if (typeof onUpdate === 'function') {
    onUpdate(freshData, { fromCache: false, isStale: false });
  }
  return freshData;
};

export default {
  CACHE_TTL_MS,
  CACHE_PREFIX,
  isAuthEndpoint,
  getCacheKey,
  readCache,
  writeCache,
  invalidateCache,
  clearCacheMatching,
  swrFetch,
};
