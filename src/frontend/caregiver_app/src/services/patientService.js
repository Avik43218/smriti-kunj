import { getTodayComplianceSummary } from './reminderService';
import apiClient from './apiClient';

/**
 * Patient Service
 * 
 * Provides patient roster retrieval and profile inspection for the caregiver portal.
 * Derives patient careStatus dynamically from live reminder compliance data.
 */

export const CARE_STATUS = {
  NORMAL: 'normal',
  REMINDER_MISSED: 'reminder_missed',
  ALERT: 'alert',
};

/**
 * Returns canonical visual tokens and descriptions for patient care status.
 * Single source of truth used across PatientCard and PatientDetails.
 * 
 * @param {'normal' | 'reminder_missed' | 'alert'} status 
 */
export const getCareStatusConfig = (status) => {
  switch (status) {
    case 'reminder_missed':
      return {
        key: 'reminder_missed',
        label: 'Reminder missed today',
        dotColor: 'bg-gold',
        ringColor: 'ring-gold/40',
        badgeBg: 'bg-gold/15',
        badgeText: 'text-gold',
        badgeBorder: 'border-gold/30',
        shortLabel: 'Reminder Missed',
      };
    case 'alert':
      return {
        key: 'alert',
        label: 'Active alert',
        dotColor: 'bg-alert',
        ringColor: 'ring-alert/40',
        badgeBg: 'bg-alert/15',
        badgeText: 'text-alert',
        badgeBorder: 'border-alert/30',
        shortLabel: 'Active Alert',
      };
    case 'normal':
    default:
      return {
        key: 'normal',
        label: 'All normal',
        dotColor: 'bg-sage',
        ringColor: 'ring-sage/40',
        badgeBg: 'bg-sage/15',
        badgeText: 'text-sage',
        badgeBorder: 'border-sage/30',
        shortLabel: 'All Normal',
      };
  }
};

const getStoredPatients = () => {
  try {
    const raw = localStorage.getItem('smriti_registered_patients');
    if (raw) {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.length > 0) {
        return parsed;
      }
    }
    return [];
  } catch (err) {
    return [];
  }
};

/**
 * Fetches all patients assigned to the active caregiver with derived live careStatus.
 * 
 * Uses GET /api/caregiver/patients.
 * 
 * @returns {Promise<Array>}
 */
export const fetchPatients = async () => {
  try {
    const data = await apiClient('/api/caregiver/patients');
    if (Array.isArray(data)) {
      return data.map((patient) => {
        const compliance = getTodayComplianceSummary(patient.id);
        return {
          ...patient,
          careStatus: patient.status || patient.careStatus || compliance.careStatus,
          complianceSummary: compliance,
        };
      });
    }
  } catch (err) {
    console.warn('apiClient /api/caregiver/patients notice, checking stored:', err.message);
  }

  const stored = getStoredPatients();
  return stored.map((patient) => {
    const compliance = getTodayComplianceSummary(patient.id);
    return {
      ...patient,
      careStatus: patient.careStatus || compliance.careStatus,
      complianceSummary: compliance,
    };
  });
};

/**
 * Registers a new patient with backend and local storage.
 * 
 * @param {Object} newPatient 
 * @returns {Promise<Object>}
 */
export const registerPatient = async (newPatient) => {
  try {
    const data = await apiClient('/api/caregiver/patients', {
      method: 'POST',
      body: JSON.stringify(newPatient),
    });
    if (data && data.id) {
      newPatient = { ...newPatient, ...data };
    }
  } catch (err) {
    console.warn('apiClient POST /api/caregiver/patients notice:', err.message);
  }

  const stored = getStoredPatients();
  const filtered = stored.filter((p) => p.id !== newPatient.id);
  filtered.unshift(newPatient);
  try {
    localStorage.setItem('smriti_registered_patients', JSON.stringify(filtered));
  } catch (err) {
    console.warn('Could not save patient to localStorage:', err);
  }
  return newPatient;
};

/**
 * Fetches details for a single patient by ID with derived live careStatus.
 * 
 * Uses GET /api/caregiver/patients/:id with local cache fallback.
 * 
 * @param {string} id
 * @returns {Promise<Object|null>}
 */
export const getPatientById = async (id) => {
  const stored = getStoredPatients();
  const cachedPatient = stored.find((p) => p.id === id);

  try {
    const data = await apiClient(`/api/caregiver/patients/${id}`);
    if (data && data.id) {
      const compliance = getTodayComplianceSummary(id);
      return {
        ...cachedPatient,
        ...data,
        weight: data.weight || cachedPatient?.weight,
        diabetic: data.diabetic || cachedPatient?.diabetic,
        nutritionDiet: data.nutritionDiet || cachedPatient?.nutritionDiet,
        alcoholLevel: data.alcoholLevel || cachedPatient?.alcoholLevel,
        smokingStatus: data.smokingStatus || cachedPatient?.smokingStatus,
        careStatus: data.status || compliance.careStatus,
        complianceSummary: compliance,
      };
    }
  } catch (err) {
    console.warn(`apiClient /api/caregiver/patients/${id} notice, checking stored:`, err.message);
  }

  if (cachedPatient) {
    const compliance = getTodayComplianceSummary(id);
    return {
      ...cachedPatient,
      careStatus: cachedPatient.careStatus || compliance.careStatus,
      complianceSummary: compliance,
    };
  }

  return null;
};

/**
 * Deletes a patient from backend and local cache.
 * 
 * @param {string} id 
 * @returns {Promise<boolean>}
 */
export const deletePatient = async (id) => {
  try {
    await apiClient(`/api/caregiver/patients/${id}`, {
      method: 'DELETE',
    });
  } catch (err) {
    console.warn(`apiClient DELETE /api/caregiver/patients/${id} notice:`, err.message);
  }

  const stored = getStoredPatients();
  const updated = stored.filter((p) => p.id !== id);
  try {
    localStorage.setItem('smriti_registered_patients', JSON.stringify(updated));
    localStorage.removeItem(`smriti_pairing_token_${id}`);
  } catch (err) {
    console.warn('Could not update localStorage after patient deletion:', err);
  }
  return true;
};

/**
 * Updates an existing patient record in local storage and attempts API sync.
 * 
 * @param {string} id 
 * @param {Object} updatedFields 
 * @returns {Promise<Object>}
 */
export const updatePatient = async (id, updatedFields) => {
  const stored = getStoredPatients();
  const index = stored.findIndex((p) => p.id === id);
  let updatedPatient;

  if (index !== -1) {
    updatedPatient = {
      ...stored[index],
      ...updatedFields,
      id,
    };
    stored[index] = updatedPatient;
  } else {
    updatedPatient = { id, ...updatedFields };
    stored.unshift(updatedPatient);
  }

  try {
    localStorage.setItem('smriti_registered_patients', JSON.stringify(stored));
  } catch (err) {
    console.warn('Could not update patient in localStorage:', err);
  }

  try {
    await apiClient('/api/caregiver/patients', {
      method: 'POST',
      body: JSON.stringify(updatedPatient),
    });
  } catch (err) {
    console.warn('apiClient update notice:', err.message);
  }

  return updatedPatient;
};

export default {
  fetchPatients,
  getPatientById,
  registerPatient,
  updatePatient,
  deletePatient,
  getCareStatusConfig,
  CARE_STATUS,
};

