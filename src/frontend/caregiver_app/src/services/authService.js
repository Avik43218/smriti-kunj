import { apiClient } from './apiClient';

export const register = async (name, email, password) => {
  return await apiClient('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify({ name, email, password }),
  });
};

export const requestOtp = async (email) => {
  return await apiClient('/api/auth/request-otp', {
    method: 'POST',
    body: JSON.stringify({ email }),
  });
};

// Verifies the code and saves the token
export const verifyOtp = async (email, otp) => {
  const data = await apiClient('/api/auth/verify-otp', {
    method: 'POST',
    body: JSON.stringify({ email, otp }),
  });

  if (data.token) {
    localStorage.setItem('token', data.token);
  }

  return data; // Usually returns { token, caregiver }
};

// Validates credentials and sends OTP
export const login = async (email, password, role) => {
  const payload = { email, password };
  if (role) {
    payload.role = role;
  }
  return await apiClient('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
};

// Kills the session on the backend
export const logout = async () => {
  try {
    await apiClient('/api/auth/logout', { method: 'POST' });
  } catch (error) {
    console.warn("Backend logout notice:", error.message);
  }

  localStorage.removeItem('token');
  localStorage.removeItem('caregiver_user_data');
  return { success: true };
};

export default {
  register,
  requestOtp,
  verifyOtp,
  login,
  logout,
};
