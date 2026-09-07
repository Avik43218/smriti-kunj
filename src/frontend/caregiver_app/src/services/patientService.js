import { getTodayComplianceSummary } from './reminderService';

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

const MOCK_PATIENTS = [
  {
    id: 'p101',
    name: 'Aarav Sharma',
    age: 72,
    gender: 'Male',
    dateOfBirth: 'March 14, 1954',
    diagnosis: 'Mild Cognitive Impairment (MCI)',
    healthIssue: 'Mild Cognitive Impairment (MCI) • Early-stage memory recall decline • Hypertension',
    avatarUrl: null,
    lastCheckIn: 'Today, 10:30 AM',
    notes: 'Morning memory recall exercise completed with 92% accuracy.',
    emergencyContact: {
      name: 'Priya Sharma',
      relationship: 'Daughter (Primary Guardian)',
      phone: '+91 98765 43210',
    },
    deviceStatus: {
      linked: true,
      deviceName: 'Lenovo Tab M10 Plus (Patient Unit 1)',
      deviceId: 'DEV-M10-8842',
      lastSynced: 'Today, 10:30 AM',
    },
  },
  {
    id: 'p102',
    name: 'Maya Sen',
    age: 68,
    gender: 'Female',
    dateOfBirth: 'November 22, 1957',
    diagnosis: "Early Stage Alzheimer's",
    healthIssue: "Early Stage Alzheimer's Disease • Mild spatial disorientation",
    avatarUrl: null,
    lastCheckIn: 'Yesterday, 6:15 PM',
    notes: 'Evening reminder acknowledged. Next routine scheduled at 8:00 AM.',
    emergencyContact: {
      name: 'Rohan Sen',
      relationship: 'Son',
      phone: '+91 98123 45678',
    },
    deviceStatus: {
      linked: true,
      deviceName: 'Samsung Galaxy Tab A9 (Patient Unit 2)',
      deviceId: 'DEV-SGT-3319',
      lastSynced: 'Yesterday, 6:15 PM',
    },
  },
];

const getStoredPatients = () => {
  try {
    const raw = localStorage.getItem('smriti_registered_patients');
    return raw ? JSON.parse(raw) : [];
  } catch (err) {
    return [];
  }
};

/**
 * Fetches all patients assigned to the active caregiver with derived live careStatus.
 * 
 * // BACKEND-TODO: see docs/API_ENDPOINTS_NEEDED.md (GET /api/caregiver/patients)
 * 
 * @returns {Promise<Array>}
 */
export const fetchPatients = async () => {
  return new Promise((resolve) => {
    setTimeout(() => {
      const stored = getStoredPatients();
      const combined = [...stored, ...MOCK_PATIENTS];
      const seen = new Set();
      const uniquePatients = combined.filter((p) => {
        if (!p.id || seen.has(p.id)) return false;
        seen.add(p.id);
        return true;
      });

      const enrichedPatients = uniquePatients.map((patient) => {
        const compliance = getTodayComplianceSummary(patient.id);
        return {
          ...patient,
          careStatus: patient.careStatus || compliance.careStatus,
          complianceSummary: compliance,
        };
      });
      resolve(enrichedPatients);
    }, 350); // Simulated latency
  });
};

/**
 * Registers a new patient into local storage and patient roster.
 * 
 * @param {Object} newPatient 
 * @returns {Promise<Object>}
 */
export const registerPatient = async (newPatient) => {
  return new Promise((resolve) => {
    setTimeout(() => {
      const stored = getStoredPatients();
      stored.unshift(newPatient);
      try {
        localStorage.setItem('smriti_registered_patients', JSON.stringify(stored));
      } catch (err) {
        console.warn('Could not save patient to localStorage:', err);
      }
      resolve(newPatient);
    }, 250);
  });
};

/**
 * Fetches details for a single patient by ID with derived live careStatus.
 * 
 * // BACKEND-TODO: see docs/API_ENDPOINTS_NEEDED.md (GET /api/caregiver/patients/:id)
 * 
 * @param {string} id
 * @returns {Promise<Object>}
 */
export const getPatientById = async (id) => {
  return new Promise((resolve) => {
    setTimeout(() => {
      const stored = getStoredPatients();
      const patient = stored.find((p) => p.id === id) || MOCK_PATIENTS.find((p) => p.id === id);
      const compliance = getTodayComplianceSummary(id);

      if (patient) {
        resolve({
          ...patient,
          careStatus: patient.careStatus || compliance.careStatus,
          complianceSummary: compliance,
        });
      } else {
        // Realistic fallback record if arbitrary ID entered in route
        resolve({
          id,
          name: `Patient ${id}`,
          age: 70,
          gender: 'Not specified',
          dateOfBirth: 'January 15, 1956',
          diagnosis: 'Cognitive Care Monitoring',
          healthIssue: 'Cognitive monitoring routine active',
          avatarUrl: null,
          careStatus: compliance.careStatus,
          complianceSummary: compliance,
          lastCheckIn: 'Today, 11:00 AM',
          notes: 'Standard cognitive support routine.',
          emergencyContact: {
            name: 'Primary Contact',
            relationship: 'Guardian',
            phone: '+91 90000 00000',
          },
          deviceStatus: {
            linked: true,
            deviceName: `Assist Tablet (${id})`,
            deviceId: `DEV-${id}`,
            lastSynced: 'Today, 11:00 AM',
          },
        });
      }
    }, 250);
  });
};

export default {
  fetchPatients,
  getPatientById,
  registerPatient,
  getCareStatusConfig,
  CARE_STATUS,
};

