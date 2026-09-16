import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import {
  logout as apiLogout,
  login as apiLogin,
  verifyOtp as apiVerifyOtp,
  requestOtp as apiRequestOtp,
} from '../services/authService';
import { apiClient } from '../services/apiClient';

const AuthContext = createContext(null);

const STORAGE_KEYS = {
  TOKEN: 'token',
  USER: 'caregiver_user_data',
};

export const AuthProvider = ({ children }) => {
  const [token, setToken] = useState(() => {
    try {
      return localStorage.getItem(STORAGE_KEYS.TOKEN) || null;
    } catch (err) {
      return null;
    }
  });

  const [caregiver, setCaregiver] = useState(() => {
    try {
      const savedUser = localStorage.getItem(STORAGE_KEYS.USER);
      return savedUser ? JSON.parse(savedUser) : null;
    } catch (err) {
      return null;
    }
  });

  const [loading, setLoading] = useState(false);

  // ===== DEV BYPASS — REMOVE/COMMENT BEFORE BACKEND INTEGRATION =====
  //  Uncomment this block to skip login during frontend-only development.
  //  Comment it out (or delete) once the real backend login flow is being tested.
  
  useEffect(() => {
    if (!token) {
      const fakeToken = 'dev-bypass-token';
      const fakeCaregiver = { id: 'dev1', name: 'Dev Caregiver', email: 'dev@test.com' };
      setToken(fakeToken);
      setCaregiver(fakeCaregiver);
    }
  }, []);
  
  //  ===== END DEV BYPASS =====

  // Validate session against /api/auth/me on mount if token is present
  useEffect(() => {
    let isMounted = true;
    const verifyExistingSession = async () => {
      if (!token) return;
      try {
        const me = await apiClient('/api/auth/me');
        if (isMounted && me && me.id) {
          setCaregiver((prev) => ({ ...prev, ...me }));
        }
      } catch (err) {
        console.warn('Session expired or invalid:', err.message);
        if (isMounted) {
          setToken(null);
          setCaregiver(null);
          localStorage.removeItem(STORAGE_KEYS.TOKEN);
          localStorage.removeItem(STORAGE_KEYS.USER);
        }
      }
    };
    verifyExistingSession();
    return () => {
      isMounted = false;
    };
  }, []);

  // Syncs the User data whenever it changes
  useEffect(() => {
    if (caregiver) {
      localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(caregiver));
    } else {
      localStorage.removeItem(STORAGE_KEYS.USER);
    }
  }, [caregiver]);

  useEffect(() => {
    if (token) {
      localStorage.setItem(STORAGE_KEYS.TOKEN, token);
    } else {
      localStorage.removeItem(STORAGE_KEYS.TOKEN);
    }
  }, [token]);

  // Real backend credential submission (triggers OTP)
  const login = useCallback(async (email, password, roleType = 'caregiver') => {
    setLoading(true);
    try {
      return await apiLogin(email, password, roleType);
    } finally {
      setLoading(false);
    }
  }, []);

  const requestOtp = useCallback(async (email) => {
    return await apiRequestOtp(email);
  }, []);

  const verifyOtp = useCallback(async (email, otp) => {
    setLoading(true);
    try {
      const response = await apiVerifyOtp(email, otp);
      const userObj = response.caregiver || response.user;
      setToken(response.token);
      setCaregiver(userObj);
      return response;
    } finally {
      setLoading(false);
    }
  }, []);

  const logout = useCallback(async () => {
    setLoading(true);
    try {
      await apiLogout();
    } catch (err) {
      console.error('Logout error:', err);
    } finally {
      setToken(null);
      setCaregiver(null);
      setLoading(false);
    }
  }, []);

  const isAuthenticated = Boolean(token && caregiver);
  const role = caregiver?.role || 'caregiver';
  const isAdmin = role === 'admin';

  const value = {
    user: caregiver,
    caregiver,
    role,
    isAdmin,
    token,
    login,
    requestOtp,
    verifyOtp,
    logout,
    isAuthenticated,
    loading,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export default AuthContext;