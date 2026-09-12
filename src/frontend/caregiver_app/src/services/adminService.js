import apiClient from './apiClient';

/**
 * Admin Service
 * 
 * Provides administrative management for caregivers and cross-caregiver patient roster.
 * Protected under the Admin role.
 */

const DEFAULT_MOCK_CAREGIVERS = [
  {
    id: 'c101-uuid-placeholder-1',
    name: 'Dr. Sarah Jenkins',
    email: 'sarah.jenkins@smritikunj.org',
    region_language: 'bn',
    role: 'caregiver',
    status: 'active',
    patient_count: 2,
    created_at: new Date(Date.now() - 30 * 86400000).toISOString(),
    created_by: null,
  },
  {
    id: 'c102-uuid-placeholder-2',
    name: 'Nurse Ananya Roy',
    email: 'ananya.roy@smritikunj.org',
    region_language: 'as',
    role: 'caregiver',
    status: 'active',
    patient_count: 1,
    created_at: new Date(Date.now() - 14 * 86400000).toISOString(),
    created_by: null,
  },
];

const DEFAULT_MOCK_ALL_PATIENTS = [
  {
    id: 'p101',
    uuid_id: 'p101-uuid-placeholder-1',
    patient_code: 'p101',
    name: 'Aarav Sharma',
    age: 72,
    gender: 'Male',
    diagnosis: 'Mild Cognitive Impairment (MCI)',
    status: 'stable',
    status_label: 'Active • Tablet synced',
    caregiver_id: 'c101-uuid-placeholder-1', // Assigned to Dr. Sarah Jenkins
    caregiver_name: 'Dr. Sarah Jenkins',
    caregiver_email: 'sarah.jenkins@smritikunj.org',
    device_id: 'DEV-M10-8492',
    pairing_token: 'PAIR-101742',
    created_at: new Date(Date.now() - 25 * 86400000).toISOString(),
  },
  {
    id: 'p102',
    uuid_id: 'p102-uuid-placeholder-2',
    patient_code: 'p102',
    name: 'Sunita Das',
    age: 68,
    gender: 'Female',
    diagnosis: "Early Stage Alzheimer's",
    status: 'stable',
    status_label: 'Medication pending',
    caregiver_id: 'c101-uuid-placeholder-1', // Assigned to Dr. Sarah Jenkins
    caregiver_name: 'Dr. Sarah Jenkins',
    caregiver_email: 'sarah.jenkins@smritikunj.org',
    device_id: 'DEV-A8-3190',
    pairing_token: 'PAIR-204918',
    created_at: new Date(Date.now() - 20 * 86400000).toISOString(),
  },
  {
    id: 'p103',
    uuid_id: 'p103-uuid-placeholder-3',
    patient_code: 'p103',
    name: 'Protima Devi',
    age: 69,
    gender: 'Female',
    diagnosis: "Early Alzheimer's",
    status: 'alert',
    status_label: 'Reminder Missed',
    caregiver_id: 'c102-uuid-placeholder-2', // Assigned to Nurse Ananya Roy
    caregiver_name: 'Nurse Ananya Roy',
    caregiver_email: 'ananya.roy@smritikunj.org',
    device_id: 'DEV-X5-9921',
    pairing_token: 'PAIR-339182',
    created_at: new Date(Date.now() - 10 * 86400000).toISOString(),
  },
];

export const getCaregivers = async () => {
  try {
    const data = await apiClient('/api/admin/caregivers');
    if (Array.isArray(data)) {
      return data;
    }
  } catch (err) {
    console.warn('apiClient /api/admin/caregivers fallback notice:', err.message);
  }

  const stored = localStorage.getItem('smriti_admin_caregivers');
  if (stored) {
    try {
      return JSON.parse(stored);
    } catch {
      // fallback to mock
    }
  }
  return DEFAULT_MOCK_CAREGIVERS;
};

export const createCaregiver = async (caregiverData) => {
  try {
    const data = await apiClient('/api/admin/caregivers', {
      method: 'POST',
      body: JSON.stringify(caregiverData),
    });
    if (data && data.id) {
      return data;
    }
  } catch (err) {
    console.warn('apiClient POST /api/admin/caregivers notice:', err.message);
    throw err;
  }
};

export const updateCaregiver = async (id, updateFields) => {
  try {
    const data = await apiClient(`/api/admin/caregivers/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(updateFields),
    });
    return data;
  } catch (err) {
    console.warn(`apiClient PATCH /api/admin/caregivers/${id} notice:`, err.message);
    throw err;
  }
};

export const deleteCaregiver = async (id) => {
  try {
    const data = await apiClient(`/api/admin/caregivers/${id}`, {
      method: 'DELETE',
    });
    return data;
  } catch (err) {
    console.warn(`apiClient DELETE /api/admin/caregivers/${id} notice:`, err.message);
    throw err;
  }
};

export const getAllPatients = async () => {
  try {
    const data = await apiClient('/api/admin/patients');
    if (Array.isArray(data)) {
      return data;
    }
  } catch (err) {
    console.warn('apiClient /api/admin/patients fallback notice:', err.message);
  }

  const stored = localStorage.getItem('smriti_admin_all_patients');
  if (stored) {
    try {
      return JSON.parse(stored);
    } catch {
      // fallback to mock
    }
  }
  return DEFAULT_MOCK_ALL_PATIENTS;
};

export const reassignPatient = async (patientId, newCaregiverId) => {
  try {
    const data = await apiClient(`/api/admin/patients/${patientId}/reassign`, {
      method: 'PATCH',
      body: JSON.stringify({ new_caregiver_id: newCaregiverId }),
    });
    return data;
  } catch (err) {
    console.warn(`apiClient PATCH /api/admin/patients/${patientId}/reassign notice:`, err.message);
    throw err;
  }
};

export default {
  getCaregivers,
  createCaregiver,
  updateCaregiver,
  deleteCaregiver,
  getAllPatients,
  reassignPatient,
};