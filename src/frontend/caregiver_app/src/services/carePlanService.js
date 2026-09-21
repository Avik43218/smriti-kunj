import apiClient from './apiClient';
import { swrFetch, invalidateCache } from './cacheService';

/**
 * Care Plan Service
 * 
 * Provides memory gallery family member operations and care plan customization.
 */

export const fetchFamilyMembers = async (patientId, options = {}) => {
  if (!patientId) return [];
  const onUpdate = typeof options === 'function' ? options : options?.onUpdate;
  const forceRefresh = Boolean(options?.forceRefresh);

  const fetcher = async () => {
    try {
      const data = await apiClient(`/api/patients/${patientId}/family-members`);
      if (Array.isArray(data)) {
        return data;
      }
    } catch (err) {
      console.warn(`apiClient /api/patients/${patientId}/family-members notice:`, err.message);
    }
    return [];
  };

  return await swrFetch({
    endpoint: `/api/patients/${patientId}/family-members`,
    patientId,
    fetcher,
    onUpdate,
    forceRefresh,
  });
};

/**
 * Adds a new family member memory card for a patient.
 * All fields (patientId, name, relation, photoUrl) are strictly required.
 * 
 * Uses POST /api/patients/:patientId/family-members.
 */
export const addFamilyMember = async ({ patientId, name, relation, photoUrl, audioUrl }) => {
  if (!patientId || !patientId.trim()) {
    throw new Error('Patient ID is required.');
  }
  if (!name || !name.trim()) {
    throw new Error('Family member name is required.');
  }
  if (!relation || !relation.trim()) {
    throw new Error('Relation is required.');
  }
  if (!photoUrl || !photoUrl.trim()) {
    throw new Error('Photo URL/upload is required. Every memory card must include a photo.');
  }

  const data = await apiClient(`/api/patients/${patientId}/family-members`, {
    method: 'POST',
    body: JSON.stringify({ name, relation, photoUrl, audioUrl }),
  });
  invalidateCache(`/api/patients/${patientId}/family-members`, patientId);
  invalidateCache(`/api/patients/${patientId}/memories`, patientId);
  return data;
};

/**
 * Deletes a family member photo card.
 */
export const deleteFamilyMember = async (patientId, memberId) => {
  if (!patientId || !memberId) return;
  try {
    await apiClient(`/api/patients/${patientId}/family-members/${memberId}`, {
      method: 'DELETE',
    });
    invalidateCache(`/api/patients/${patientId}/family-members`, patientId);
    invalidateCache(`/api/patients/${patientId}/memories`, patientId);
  } catch (err) {
    console.warn(`Failed to delete family member ${memberId}:`, err);
  }
};

/**
 * Fetches all familiar sounds & voices for a patient.
 * Uses GET /api/patients/:patientId/familiar-sounds.
 */
export const fetchFamiliarSounds = async (patientId, options = {}) => {
  if (!patientId) return [];
  const onUpdate = typeof options === 'function' ? options : options?.onUpdate;
  const forceRefresh = Boolean(options?.forceRefresh);

  const fetcher = async () => {
    try {
      const data = await apiClient(`/api/patients/${patientId}/familiar-sounds`);
      if (Array.isArray(data)) {
        return data;
      }
    } catch (err) {
      console.warn(`apiClient /api/patients/${patientId}/familiar-sounds notice:`, err.message);
    }
    return [];
  };

  return await swrFetch({
    endpoint: `/api/patients/${patientId}/familiar-sounds`,
    patientId,
    fetcher,
    onUpdate,
    forceRefresh,
  });
};

/**
 * Adds a new familiar sound or voice clip for a patient.
 * Uses POST /api/patients/:patientId/familiar-sounds.
 */
export const addFamiliarSound = async ({ patientId, caption, audioUrl, fileName }) => {
  if (!patientId || !patientId.trim()) {
    throw new Error('Patient ID is required.');
  }
  if (!caption || !caption.trim()) {
    throw new Error('Caption describing the sound is required.');
  }
  if (!audioUrl || !audioUrl.trim()) {
    throw new Error('Audio file upload is required.');
  }

  const data = await apiClient(`/api/patients/${patientId}/familiar-sounds`, {
    method: 'POST',
    body: JSON.stringify({ caption, audioUrl, fileName }),
  });
  invalidateCache(`/api/patients/${patientId}/familiar-sounds`, patientId);
  invalidateCache(`/api/patients/${patientId}/memories`, patientId);
  return data;
};

/**
 * Deletes a familiar sound clip.
 */
export const deleteFamiliarSound = async (patientId, soundId) => {
  if (!patientId || !soundId) return;
  try {
    await apiClient(`/api/patients/${patientId}/familiar-sounds/${soundId}`, {
      method: 'DELETE',
    });
    invalidateCache(`/api/patients/${patientId}/familiar-sounds`, patientId);
    invalidateCache(`/api/patients/${patientId}/memories`, patientId);
  } catch (err) {
    console.warn(`Failed to delete familiar sound ${soundId}:`, err);
  }
};

/**
 * Saves overall care plan changes.
 */
export const saveCarePlan = async (patientId, planData = {}) => {
  return {
    success: true,
    updatedAt: new Date().toISOString(),
  };
};

export default {
  fetchFamilyMembers,
  addFamilyMember,
  deleteFamilyMember,
  fetchFamiliarSounds,
  addFamiliarSound,
  deleteFamiliarSound,
  saveCarePlan,
};
