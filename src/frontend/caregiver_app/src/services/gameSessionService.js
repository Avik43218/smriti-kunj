/**
 * Game Session & Analytics Service
 *
 * Provides game session history and cognitive domain trend metrics.
 * Follows schema and parameters defined in docs/GAMES_ANALYTICS_README.md.
 */

import apiClient from './apiClient';
import { swrFetch } from './cacheService';

/**
 * Domain & Game Type Metadata definitions
 */
export const DOMAINS = {
  MEMORY: 'memory',
  WORKING_MEMORY: 'working_memory',
  LANGUAGE: 'language',
  ATTENTION: 'attention',
};

export const GAME_TYPES = {
  PAIR_MATCHING: 'pair_matching',
  MARKET_TRIP: 'market_trip',
  WORD_ASSOCIATION: 'word_association',
  VISUAL_SEARCH: 'visual_search',
  TAP_TARGET: 'tap_target',
};

export const DOMAIN_CONFIG = {
  memory: {
    key: 'memory',
    label: 'Working & Episodic Memory',
    gameType: 'pair_matching',
    gameLabel: 'Pair Matching & Market Trip',
    color: '#B5562F', // Terracotta
    bgLight: 'bg-terracotta/10',
    borderLight: 'border-terracotta/30',
    textLight: 'text-terracotta',
    description: 'Visual memory retention, card pair recall & shopping list delayed recall',
    targetParam: 'Correct Match Rate & Latency',
  },
  working_memory: {
    key: 'working_memory',
    label: 'Working Memory',
    gameType: 'market_trip',
    gameLabel: 'Market Trip',
    color: '#B5562F', // Terracotta
    bgLight: 'bg-terracotta/10',
    borderLight: 'border-terracotta/30',
    textLight: 'text-terracotta',
    description: 'Shopping list recall, short-term holding & distractor resistance',
    targetParam: 'Recall Accuracy & Latency',
  },
  language: {
    key: 'language',
    label: 'Language & Semantic',
    gameType: 'word_association',
    gameLabel: 'Word Association',
    color: '#6E8C6A', // Sage
    bgLight: 'bg-sage/10',
    borderLight: 'border-sage/30',
    textLight: 'text-sage',
    description: 'Vocabulary retrieval speed, category naming & verbal fluency',
    targetParam: 'Words Recalled & Fluency Latency',
  },
  attention: {
    key: 'attention',
    label: 'Attention & Processing Speed',
    gameType: 'tap_target',
    gameLabel: 'Tap the Target',
    color: '#C9962C', // Gold
    bgLight: 'bg-gold/10',
    borderLight: 'border-gold/30',
    textLight: 'text-gold',
    description: 'Target detection speed, reaction consistency & distractor resistance',
    targetParam: 'Reaction Time & Variability',
  },
};

/**
 * Fetches all game sessions for a given patient from the backend.
 * Backed by lightweight SWR cache: checks localStorage, renders cached value
 * immediately, and fetches fresh sessions in the background.
 *
 * Uses GET /api/patients/:patientId/game-sessions.
 *
 * @param {string} patientId
 * @param {Object|Function} [options] - Options or onUpdate callback
 * @param {Function} [options.onUpdate] - Callback when fresh data arrives
 * @param {boolean} [options.forceRefresh] - Force network fetch
 * @returns {Promise<Array>}
 */
export const getGameSessions = async (patientId, options = {}) => {
  if (!patientId) return [];
  const onUpdate = typeof options === 'function' ? options : options?.onUpdate;
  const forceRefresh = Boolean(options?.forceRefresh);

  const fetcher = async () => {
    try {
      const data = await apiClient(`/api/patients/${patientId}/game-sessions`);
      if (Array.isArray(data)) {
        return data;
      }
    } catch (err) {
      console.warn(`apiClient /api/patients/${patientId}/game-sessions notice:`, err.message);
    }
    return [];
  };

  return await swrFetch({
    endpoint: `/api/patients/${patientId}/game-sessions`,
    patientId,
    fetcher,
    onUpdate,
    forceRefresh,
  });
};

/**
/**
 * Resolves the client's display timezone. If the environment or browser defaults to
 * UTC (common in privacy browsers, webviews, or headless containers), defaults to
 * Indian Standard Time ('Asia/Kolkata') to match patient device time.
 */
export const resolveDisplayTimeZone = () => {
  try {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (tz && tz !== 'UTC' && tz !== 'Etc/UTC') {
      return tz;
    }
  } catch (_) {}
  return 'Asia/Kolkata';
};

/**
 * Safely parses any ISO date string, SQL date string, or timestamp into a Date object.
 * If the string has date and time ('T') but lacks a timezone indicator ('Z' or '+/-HH:MM'),
 * it treats it as UTC, matching backend MongoDB UTC storage.
 */
export const parseSessionDate = (raw) => {
  if (!raw) return null;
  if (raw instanceof Date) return isNaN(raw.getTime()) ? null : raw;
  if (typeof raw === 'number') {
    const ms = raw < 1e11 ? raw * 1000 : raw;
    return new Date(ms);
  }

  let str = String(raw).trim();
  if (!str) return null;

  // Replace space separator between date and time with 'T' (e.g. '2026-09-19 10:53:00' -> '2026-09-19T10:53:00')
  if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(str)) {
    str = str.replace(/\s+/, 'T');
  }

  // If it's a date-time string without any timezone indicator (no 'Z' and no '+/-HH:mm'),
  // treat it as UTC because all session records in the database are stored in UTC.
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(str)) {
    if (!str.endsWith('Z') && !/[+-]\d{2}(:?\d{2})?$/.test(str)) {
      str += 'Z';
    }
  }

  const date = new Date(str);
  return isNaN(date.getTime()) ? null : date;
};

/**
 * Formats date to concise user-friendly display in user's local timezone (e.g. "Sep 19" or "Sep 19, 4:10 PM")
 */
export const formatSessionDate = (isoString, includeTime = false, customTimeZone = null) => {
  if (!isoString) return '—';
  const date = parseSessionDate(isoString);
  if (!date) return String(isoString);

  const tz = customTimeZone || resolveDisplayTimeZone();

  if (includeTime) {
    const datePart = date.toLocaleDateString('en-US', {
      timeZone: tz,
      month: 'short',
      day: 'numeric',
    });
    const timePart = date.toLocaleTimeString('en-US', {
      timeZone: tz,
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
    return `${datePart}, ${timePart}`;
  }

  return date.toLocaleDateString('en-US', {
    timeZone: tz,
    month: 'short',
    day: 'numeric',
  });
};

/**
 * Formats duration in seconds to "Xm Ys"
 */
export const formatDuration = (seconds) => {
  if (!seconds || seconds <= 0) return '0s';
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins === 0) return `${secs}s`;
  if (secs === 0) return `${mins}m`;
  return `${mins}m ${secs}s`;
};

export default {
  DOMAINS,
  GAME_TYPES,
  DOMAIN_CONFIG,
  getGameSessions,
  parseSessionDate,
  formatSessionDate,
  formatDuration,
  resolveDisplayTimeZone,
};
