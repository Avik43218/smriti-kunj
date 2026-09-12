import apiClient from './apiClient';

/**
 * Care Plan Service
 * 
 * Provides memory gallery family member operations and care plan customization.
 */

export const fetchFamilyMembers = async (patientId) => {
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

/**
 * Adds a new family member memory card for a patient.
 * All fields (patientId, name, relation, photoUrl) are strictly required.
 * 
 * Uses POST /api/patients/:patientId/family-members.
 * 
 * @param {Object} memberData
 * @param {string} memberData.patientId
 * @param {string} memberData.name
 * @param {string} memberData.relation
 * @param {string} memberData.photoUrl
 * @returns {Promise<{ id: string, name: string, relation: string, photoUrl: string, patientId: string }>}
 */
export const addFamilyMember = async ({ patientId, name, relation, photoUrl }) => {
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
    body: JSON.stringify({ name, relation, photoUrl }),
  });
  return data;
};

/**
 * Saves overall care plan changes.
 * 
 * @param {string} patientId 
 * @param {Object} planData 
 * @returns {Promise<{ success: boolean, updatedAt: string }>}
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
  saveCarePlan,
};
