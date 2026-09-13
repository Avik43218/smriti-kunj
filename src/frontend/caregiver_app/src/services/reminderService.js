import apiClient from './apiClient';

/**
 * Reminder & Compliance Service
 * 
 * Manages Health & Wellness reminders and daily patient compliance tracking.
 * Acts as the canonical single source of truth for patient reminder status ('normal' vs 'reminder_missed').
 */

// In-memory store for active session
let remindersStore = {};
let complianceStore = {};

/**
 * Normalizes patient ID string
 */
const normalizePatientId = (patientId) => {
  return patientId ? String(patientId).trim() : '';
};

/**
 * Helper to get or initialize reminders for a patient
 */
const getPatientRemindersRaw = (patientId) => {
  const normId = normalizePatientId(patientId);
  if (!remindersStore[normId]) {
    remindersStore[normId] = {
      medication: [],
      hydration: {},
      meals: [],
      custom: [],
    };
  }
  return remindersStore[normId];
};

/**
 * Helper to get or initialize compliance status for a patient
 */
const getPatientComplianceRaw = (patientId) => {
  const normId = normalizePatientId(patientId);
  if (!complianceStore[normId]) {
    complianceStore[normId] = {
      today: {},
      pastDays: [],
    };
  }
  return complianceStore[normId];
};

/**
 * Fetches all Health & Wellness reminders for a specific patient.
 * 
 * Uses GET /api/patients/:patientId/reminders with local fallback.
 * 
 * @param {string} patientId 
 * @returns {Promise<{ medication: Array, hydration: Object, meals: Array, custom: Array }>}
 */
export const fetchReminders = async (patientId) => {
  try {
    const data = await apiClient(`/api/patients/${patientId}/reminders`);
    if (data && (data.medication || data.hydration || data.meals || data.custom)) {
      const normId = normalizePatientId(patientId);
      remindersStore[normId] = data;
      return JSON.parse(JSON.stringify(data));
    }
  } catch (err) {
    console.warn(`apiClient /api/patients/${patientId}/reminders notice, using local cache:`, err.message);
  }

  return new Promise((resolve) => {
    setTimeout(() => {
      const data = getPatientRemindersRaw(patientId);
      resolve(JSON.parse(JSON.stringify(data)));
    }, 250);
  });
};

/**
 * Updates existing labels/times for a fixed category (medication, hydration, or meals).
 * 
 * Uses PUT /api/patients/:patientId/reminders/:category with local fallback.
 * 
 * @param {string} patientId 
 * @param {'medication' | 'hydration' | 'meals'} category 
 * @param {Array|Object} updatedData 
 * @returns {Promise<{ success: boolean, data: any }>}
 */
export const updateCategoryReminders = async (patientId, category, updatedData) => {
  try {
    const data = await apiClient(`/api/patients/${patientId}/reminders/${category}`, {
      method: 'PUT',
      body: JSON.stringify(updatedData),
    });
    if (data !== undefined) {
      const normId = normalizePatientId(patientId);
      const patientReminders = getPatientRemindersRaw(normId);
      patientReminders[category] = data;
      return { success: true, data };
    }
  } catch (err) {
    console.warn(`apiClient PUT /api/patients/${patientId}/reminders/${category} notice, using local cache:`, err.message);
  }

  return new Promise((resolve, reject) => {
    setTimeout(() => {
      const normId = normalizePatientId(patientId);
      const patientReminders = getPatientRemindersRaw(normId);

      if (!['medication', 'hydration', 'meals'].includes(category)) {
        reject(new Error(`Invalid reminder category: ${category}`));
        return;
      }

      patientReminders[category] = updatedData;
      resolve({ success: true, data: patientReminders[category] });
    }, 300);
  });
};

/**
 * Adds a new custom reminder for a patient.
 * 
 * Uses POST /api/patients/:patientId/reminders/custom with local fallback.
 * 
 * @param {Object} reminderData
 * @param {string} reminderData.patientId
 * @param {string} reminderData.label
 * @param {string} reminderData.time
 * @param {string} reminderData.frequency
 * @returns {Promise<{ id: string, label: string, time: string, frequency: string }>}
 */
export const addCustomReminder = async ({ patientId, label, time, frequency = 'Daily' }) => {
  try {
    const data = await apiClient(`/api/patients/${patientId}/reminders/custom`, {
      method: 'POST',
      body: JSON.stringify({ label, time, frequency }),
    });
    if (data && data.id) {
      const normId = normalizePatientId(patientId);
      const patientReminders = getPatientRemindersRaw(normId);
      if (!Array.isArray(patientReminders.custom)) {
        patientReminders.custom = [];
      }
      patientReminders.custom.push(data);
      return data;
    }
  } catch (err) {
    console.warn(`apiClient POST /api/patients/${patientId}/reminders/custom notice, using local cache:`, err.message);
  }

  return new Promise((resolve, reject) => {
    setTimeout(() => {
      if (!label || !label.trim()) {
        reject(new Error('Reminder label is required.'));
        return;
      }
      if (!time || !time.trim()) {
        reject(new Error('Reminder time is required.'));
        return;
      }

      const normId = normalizePatientId(patientId);
      const patientReminders = getPatientRemindersRaw(normId);

      const newCustomItem = {
        id: `cust_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        label: label.trim(),
        time: time.trim(),
        frequency: frequency || 'Daily',
        active: true,
      };

      if (!Array.isArray(patientReminders.custom)) {
        patientReminders.custom = [];
      }
      patientReminders.custom.push(newCustomItem);
      resolve(newCustomItem);
    }, 350);
  });
};

/**
 * Computes live compliance summary for a patient for today.
 * Synchronously derived to serve as canonical source of truth for patientService.
 *
 * @param {string} patientId
 * @returns {{
 *   hasMissedToday: boolean,
 *   careStatus: 'normal' | 'reminder_missed',
 *   completedCount: number,
 *   missedCount: number,
 *   pendingCount: number,
 *   totalCount: number,
 *   summaryText: string,
 *   completionRate: number
 * }}
 */
export const getTodayComplianceSummary = (patientId) => {
  const normId = normalizePatientId(patientId);
  const reminders = getPatientRemindersRaw(normId);
  const compliance = getPatientComplianceRaw(normId);

  // Flatten all active reminders
  const allItems = [];
  if (Array.isArray(reminders.medication)) {
    reminders.medication.forEach((m) => allItems.push({ id: m.id, label: m.label, type: 'medication' }));
  }
  if (reminders.hydration && reminders.hydration.label) {
    allItems.push({ id: reminders.hydration.id, label: reminders.hydration.label, type: 'hydration' });
  }
  if (Array.isArray(reminders.meals)) {
    reminders.meals.forEach((m) => allItems.push({ id: m.id, label: m.label, type: 'meals' }));
  }
  if (Array.isArray(reminders.custom)) {
    reminders.custom.forEach((c) => allItems.push({ id: c.id, label: c.label, type: 'custom' }));
  }

  let completedCount = 0;
  let missedCount = 0;
  let pendingCount = 0;

  allItems.forEach((item) => {
    const status = compliance.today[item.id] || 'pending';
    if (status === 'completed') completedCount += 1;
    else if (status === 'missed') missedCount += 1;
    else pendingCount += 1;
  });

  const totalCount = allItems.length;
  const hasMissedToday = missedCount > 0;
  const careStatus = hasMissedToday ? 'reminder_missed' : 'normal';
  const completionRate = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 100;

  return {
    hasMissedToday,
    careStatus,
    completedCount,
    missedCount,
    pendingCount,
    totalCount,
    summaryText: totalCount > 0 ? `${completedCount} of ${totalCount} completed today` : 'No reminders scheduled today',
    completionRate,
  };
};

/**
 * Fetches detailed compliance items for today and the 5-day history for the Care Plan page.
 *
 * @param {string} patientId
 * @returns {Promise<{
 *   summary: Object,
 *   todayItems: Array<{ id: string, label: string, time: string, category: string, status: 'completed'|'missed'|'pending' }>,
 *   pastDays: Array<{ dateLabel: string, completed: number, total: number, missed: number, rate: number }>
 * }>}
 */
export const getPatientComplianceDetails = async (patientId) => {
  return new Promise((resolve) => {
    setTimeout(() => {
      const normId = normalizePatientId(patientId);
      const reminders = getPatientRemindersRaw(normId);
      const compliance = getPatientComplianceRaw(normId);
      const summary = getTodayComplianceSummary(normId);

      // Build today items list
      const todayItems = [];

      if (Array.isArray(reminders.medication)) {
        reminders.medication.forEach((med) => {
          todayItems.push({
            id: med.id,
            label: med.label,
            time: med.time,
            category: 'Medication',
            categoryKey: 'medication',
            status: compliance.today[med.id] || 'pending',
          });
        });
      }

      if (reminders.hydration && reminders.hydration.label) {
        todayItems.push({
          id: reminders.hydration.id,
          label: reminders.hydration.label,
          time: reminders.hydration.schedule || '8 AM – 8 PM',
          category: 'Hydration',
          categoryKey: 'hydration',
          status: compliance.today[reminders.hydration.id] || 'pending',
        });
      }

      if (Array.isArray(reminders.meals)) {
        reminders.meals.forEach((meal) => {
          todayItems.push({
            id: meal.id,
            label: meal.label,
            time: meal.time,
            category: 'Meal',
            categoryKey: 'meals',
            status: compliance.today[meal.id] || 'pending',
          });
        });
      }

      if (Array.isArray(reminders.custom)) {
        reminders.custom.forEach((cust) => {
          todayItems.push({
            id: cust.id,
            label: cust.label,
            time: cust.time,
            category: 'Custom Routine',
            categoryKey: 'custom',
            status: compliance.today[cust.id] || 'pending',
          });
        });
      }

      const pastDaysWithRate = (compliance.pastDays || []).map((day) => ({
        ...day,
        rate: day.total > 0 ? Math.round((day.completed / day.total) * 100) : 100,
      }));

      resolve({
        summary,
        todayItems,
        pastDays: pastDaysWithRate,
      });
    }, 300);
  });
};

/**
 * Updates or toggles a reminder status for today (useful for simulation / testing)
 *
 * @param {string} patientId
 * @param {string} reminderId
 * @param {'completed' | 'missed' | 'pending'} newStatus
 */
export const setReminderComplianceStatus = async (patientId, reminderId, newStatus) => {
  return new Promise((resolve) => {
    setTimeout(() => {
      const normId = normalizePatientId(patientId);
      const compliance = getPatientComplianceRaw(normId);
      compliance.today[reminderId] = newStatus;
      resolve(getTodayComplianceSummary(normId));
    }, 200);
  });
};

export default {
  fetchReminders,
  updateCategoryReminders,
  addCustomReminder,
  getTodayComplianceSummary,
  getPatientComplianceDetails,
  setReminderComplianceStatus,
};
