import apiClient from './apiClient';

/**
 * Risk Assessment & ML Inference Service
 *
 * Delegates patient risk evaluation to the FastAPI backend which:
 *   1. Queries the caregiver's real patient records from MongoDB
 *   2. Aggregates live telemetry: accuracy from GameSessions, latency, 7-day
 *      drift slope from DriftMetric, and active alert count from Alerts
 *   3. Runs all 5 features through 'xgboost_patient_risk_model.pkl'
 *   4. Returns graded results with clinical action mappings
 *
 * Falls back to demo benchmark patients only if the backend is unreachable.
 */

export const RISK_LEVEL_CONFIG = {
  0: {
    grade: 0,
    gradeLabel: 'Grade 0',
    level: 'Low Risk',
    badgeColor: '#2ecc71',
    action: 'Routine Check',
    actionDescription: 'Stable cognitive routine check. Continue active monitoring.',
  },
  1: {
    grade: 1,
    gradeLabel: 'Grade 1',
    level: 'Moderate Risk',
    badgeColor: '#f39c12',
    action: 'Adapt Difficulty',
    actionDescription: 'Mild performance deviation or fatigue. Calibrate cognitive task difficulty.',
  },
  2: {
    grade: 2,
    gradeLabel: 'Grade 2',
    level: 'High Risk',
    badgeColor: '#e74c3c',
    action: 'Immediate Intervention',
    actionDescription: 'Significant cognitive drift or high alert density. Clinical intervention recommended.',
  },
};

/**
 * Fetches real-time patient risk evaluations from the backend.
 *
 * Flow:
 *   1. GET /api/risk/patient-overview  (authenticated; DB aggregation + XGBoost inference)
 *   2. GET /api/risk/demo-patients     (unauthenticated; fallback if server up but no patients)
 *
 * @returns {Promise<{ summary: Object, patients: Array }>}
 */
export async function fetchPatientRiskOverview() {
  // Primary: real data path — backend aggregates DB telemetry & runs the model
  try {
    const data = await apiClient('/api/risk/patient-overview');
    if (data && data.summary && Array.isArray(data.patients) && data.patients.length > 0) {
      return data;
    }
  } catch (err) {
    console.warn('[riskService] /api/risk/patient-overview unavailable:', err.message);
  }

  // Secondary: server-provided demo records (backend is up but no real patients yet)
  try {
    const demoData = await apiClient('/api/risk/demo-patients');
    if (demoData && demoData.summary && Array.isArray(demoData.patients)) {
      return demoData;
    }
  } catch (err) {
    console.warn('[riskService] /api/risk/demo-patients unavailable:', err.message);
  }

  // Last resort: empty response so UI shows empty state
  return {
    summary: {
      total_patients: 0,
      high_risk_count: 0,
      moderate_risk_count: 0,
      low_risk_count: 0,
    },
    patients: [],
  };
}

export default {
  fetchPatientRiskOverview,
  RISK_LEVEL_CONFIG,
};
