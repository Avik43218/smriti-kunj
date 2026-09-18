/**
 * Core HTTP Client API Wrapper
 * 
 * Separated to eliminate circular dependencies between api.js gateway and individual service modules.
 */

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

export const apiClient = async (endpoint, options = {}) => {
  let token = localStorage.getItem('token') || localStorage.getItem('caregiver_auth_token'); 
  if (token && (token.startsWith('mock-') || token.startsWith('dev-') || token === 'null')) {
    localStorage.removeItem('token');
    localStorage.removeItem('caregiver_user_data');
    localStorage.removeItem('caregiver_auth_token');
    token = null;
  }

  // Fast abort signal to prevent long hanging when running frontend-only
  const controller = new AbortController();
  // const timeoutId = setTimeout(() => controller.abort(), 1200);

  const config = {
    ...options,
    signal: options.signal || controller.signal,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  };

  try {
    const response = await fetch(`${BASE_URL}${endpoint}`, config);
    // clearTimeout(timeoutId);
    
    if (!response.ok) {
      if (response.status === 401) {
        localStorage.removeItem('token');
        localStorage.removeItem('caregiver_user_data');
        localStorage.removeItem('caregiver_auth_token');
        if (typeof window !== 'undefined' && !window.location.pathname.includes('/login') && !window.location.pathname.includes('/register')) {
          window.location.href = '/login';
        }
      }
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.detail || errorData.message || 'Backend error');
    }
    
    return await response.json();
  } catch (error) {
    // clearTimeout(timeoutId);
    console.warn("API Call Notice (Mock Fallback):", error.message);
    throw error;
  }
};

export default apiClient;
