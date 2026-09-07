/**
 * Game Session & Analytics Service
 *
 * Provides game session history and cognitive domain trend metrics.
 * Follows schema and parameters defined in docs/GAMES_ANALYTICS_README.md.
 */

import apiClient from './apiClient';

/**
 * Domain & Game Type Metadata definitions
 */
export const DOMAINS = {
  MEMORY: 'memory',
  LANGUAGE: 'language',
  ATTENTION: 'attention',
};

export const GAME_TYPES = {
  PAIR_MATCHING: 'pair_matching',
  WORD_ASSOCIATION: 'word_association',
  VISUAL_SEARCH: 'visual_search',
};

export const DOMAIN_CONFIG = {
  memory: {
    key: 'memory',
    label: 'Episodic Memory',
    gameType: 'pair_matching',
    gameLabel: 'Pair Matching',
    color: '#B5562F', // Terracotta
    bgLight: 'bg-terracotta/10',
    borderLight: 'border-terracotta/30',
    textLight: 'text-terracotta',
    description: 'Visual memory retention, card pair recall & face-name recognition',
    targetParam: 'Correct Match Rate & Latency',
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
    label: 'Attention & Processing',
    gameType: 'visual_search',
    gameLabel: 'Visual Search',
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
 *
 * Uses GET /api/patients/:patientId/game-sessions.
 *
 * @param {string} patientId
 * @returns {Promise<Array>}
 */
export const getGameSessions = async (patientId) => {
  if (!patientId) return [];
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

/**
 * Formats date to concise user-friendly display (e.g. "Aug 24" or "24 Aug, 10:30 AM")
 */
export const formatSessionDate = (isoString, includeTime = false) => {
  if (!isoString) return '—';
  const date = new Date(isoString);
  if (isNaN(date.getTime())) return isoString;

  const options = {
    month: 'short',
    day: 'numeric',
    ...(includeTime ? { hour: '2-digit', minute: '2-digit' } : {}),
  };

  return date.toLocaleDateString(undefined, options);
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
  formatSessionDate,
  formatDuration,
};
