import { apiClient } from './apiClient';

export const register = async (name, email, password) => {
  return await apiClient('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify({ name, email, password }),
  });
};

// BACKEND-TODO: see ../../docs/API_ENDPOINTS_NEEDED.md §1 Admin Registration
export const registerAdmin = async (name, email, password, adminCode) => {
  return await apiClient('/api/auth/register-admin', {
    method: 'POST',
    body: JSON.stringify({ name, email, password, admin_code: adminCode }),
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

// Changes password for currently authenticated user
export const changePassword = async (arg1, arg2) => {
  const payload = {};
  if (arg2 !== undefined) {
    if (arg1) payload.current_password = arg1;
    payload.new_password = arg2;
  } else {
    payload.new_password = arg1;
  }

  const data = await apiClient('/api/auth/change-password', {
    method: 'POST',
    body: JSON.stringify(payload),
  });

  if (data?.token) {
    localStorage.setItem('token', data.token);
  }

  // Update cached user data if present
  try {
    const cached = localStorage.getItem('caregiver_user_data');
    if (cached) {
      const parsed = JSON.parse(cached);
      parsed.must_change_password = false;
      localStorage.setItem('caregiver_user_data', JSON.stringify(parsed));
    }
  } catch (e) {
    // Ignore cache parsing errors
  }

  return data;
};

// Requests an OTP challenge for forgot-password
export const forgotPassword = async (email) => {
  return await apiClient('/api/auth/forgot-password', {
    method: 'POST',
    body: JSON.stringify({ email }),
  });
};

// Resets password using OTP challenge
export const resetPassword = async (email, otp, newPassword) => {
  return await apiClient('/api/auth/reset-password', {
    method: 'POST',
    body: JSON.stringify({
      email,
      otp,
      new_password: newPassword,
    }),
  });
};

export default {
  register,
  registerAdmin,
  requestOtp,
  verifyOtp,
  login,
  logout,
  changePassword,
  forgotPassword,
  resetPassword,
};

