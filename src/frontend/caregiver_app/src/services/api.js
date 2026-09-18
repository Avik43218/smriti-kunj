/**
 * Primary API Gateway for Caregiver App
 * 
 * Routes all API calls through a centralized service structure.
 */

import apiClient from './apiClient';
import authService from './authService';
import carePlanService from './carePlanService';
import reminderService from './reminderService';

export { apiClient };
export * from './authService';
export * from './carePlanService';
export * from './reminderService';

export default {
  apiClient,
  auth: authService,
  carePlan: carePlanService,
  reminder: reminderService,
};
