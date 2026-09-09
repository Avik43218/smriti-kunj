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

const DEFAULT_PATIENTS = [
  {
    id: 'p101',
    name: 'Aarav Sharma',
    age: 72,
    gender: 'Male',
    dateOfBirth: 'March 14, 1954',
    diagnosis: 'Mild Cognitive Impairment (MCI)',
    healthIssue: 'Mild Cognitive Impairment (MCI) • Early-stage memory recall decline • Hypertension',
    avatarUrl: null,
    lastCheckIn: '10 mins ago',
    notes: 'Morning memory recall exercise completed with 92% accuracy. Best response times before noon.',
    preferredLanguage: 'Assamese',
    pairingToken: 'PAIR-101742',
    careStatus: 'normal',
    statusLabel: 'Tablet active • Synced',
    emergencyContact: {
      name: 'Priya Sharma',
      relationship: 'Daughter (Primary Guardian)',
      phone: '+91 98765 43210',
    },
    deviceStatus: {
      linked: true,
      deviceName: "Lenovo Tab M10 Plus (Aarav's Unit)",
      deviceId: 'DEV-M10-8492',
      lastSynced: 'Today, 10:30 AM',
    },
  },
  {
    id: 'p102',
    name: 'Sunita Das',
    age: 68,
    gender: 'Female',
    dateOfBirth: 'August 22, 1958',
    diagnosis: "Early Stage Alzheimer's",
    healthIssue: "Early Stage Alzheimer's • Needs audio prompts for daily medication adherence",
    avatarUrl: null,
    lastCheckIn: '1 hour ago',
    notes: 'Word association exercises show gradual improvement in recall latency.',
    preferredLanguage: 'Bengali',
    pairingToken: 'PAIR-204918',
    careStatus: 'reminder_missed',
    statusLabel: 'Medication pending',
    emergencyContact: {
      name: 'Rohan Das',
      relationship: 'Son (Primary Guardian)',
      phone: '+91 98123 45678',
    },
    deviceStatus: {
      linked: true,
      deviceName: "Samsung Galaxy Tab A8 (Sunita's Unit)",
      deviceId: 'DEV-A8-3190',
      lastSynced: 'Today, 09:15 AM',
    },
  },
];

const getStoredPatients = () => {
  try {
    const raw = localStorage.getItem('smriti_registered_patients');
    if (raw) {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.length > 0) {
        return parsed;
      }
    }
    return DEFAULT_PATIENTS;
  } catch (err) {
    return DEFAULT_PATIENTS;
  }
};

/**
 * Fetches all patients assigned to the active caregiver with derived live careStatus.
 * 
 * Uses GET /api/caregiver/patients with local cache fallback.
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
  try {
    const data = await apiClient(`/api/caregiver/patients/${id}`);
    if (data && data.id) {
      const compliance = getTodayComplianceSummary(id);
      return {
        ...data,
        careStatus: data.status || compliance.careStatus,
        complianceSummary: compliance,
      };
    }
  } catch (err) {
    console.warn(`apiClient /api/caregiver/patients/${id} notice, checking stored:`, err.message);
  }

  const stored = getStoredPatients();
  const patient = stored.find((p) => p.id === id);
  if (patient) {
    const compliance = getTodayComplianceSummary(id);
    return {
      ...patient,
      careStatus: patient.careStatus || compliance.careStatus,
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

export default {
  fetchPatients,
  getPatientById,
  registerPatient,
  deletePatient,
  getCareStatusConfig,
  CARE_STATUS,
};

