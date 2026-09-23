import apiClient from './apiClient';

/**
 * Admin Service
 * 
 * Provides administrative management for caregivers and cross-caregiver patient portal.
 * Protected under the Admin role.
 */

export const getCaregivers = async () => {
  try {
    const data = await apiClient('/api/admin/caregivers');
    if (Array.isArray(data)) {
      return data;
    }
    return [];
  } catch (err) {
    console.warn('apiClient /api/admin/caregivers notice:', err.message);
    return [];
  }
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
    return [];
  } catch (err) {
    console.warn('apiClient /api/admin/patients notice:', err.message);
    return [];
  }
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

export const assignPatientCaregivers = async (patientId, caregiverIds) => {
  try {
    const data = await apiClient(`/api/admin/patients/${patientId}/caregivers`, {
      method: 'PUT',
      body: JSON.stringify({ caregiver_ids: caregiverIds }),
    });
    return data;
  } catch (err) {
    console.warn(`apiClient PUT /api/admin/patients/${patientId}/caregivers notice:`, err.message);
    throw err;
  }
};

export const resetCaregiverPassword = async (caregiverId, newPassword = null) => {
  try {
    const payload = newPassword ? { new_password: newPassword } : {};
    const data = await apiClient(`/api/admin/caregivers/${caregiverId}/reset-password`, {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    return data;
  } catch (err) {
    console.warn(`apiClient POST /api/admin/caregivers/${caregiverId}/reset-password notice:`, err.message);
    throw err;
  }
};

export const getAdminAuditLogs = async (limit = 100) => {
  try {
    const data = await apiClient(`/api/admin/audit-logs?limit=${limit}`);
    if (Array.isArray(data)) {
      return data;
    }
    return [];
  } catch (err) {
    console.warn('apiClient /api/admin/audit-logs notice:', err.message);
    return [];
  }
};

export default {
  getCaregivers,
  createCaregiver,
  updateCaregiver,
  deleteCaregiver,
  getAllPatients,
  reassignPatient,
  assignPatientCaregivers,
  resetCaregiverPassword,
  getAdminAuditLogs,
};