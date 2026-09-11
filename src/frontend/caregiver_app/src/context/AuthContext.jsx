import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import {
  login as apiLogin,
  logout as apiLogout,
  verifyOtp as apiVerifyOtp,
  requestOtp as apiRequestOtp,
} from '../services/authService';

const AuthContext = createContext(null);

const STORAGE_KEYS = {
  TOKEN: 'token',
  USER: 'caregiver_user_data',
};

export const AuthProvider = ({ children }) => {
  // Pulls from the vault on first load
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

  // useEffect(() => {
  //   if (!token) {
  //     const fakeToken = 'dev-bypass-token';
  //     const fakeCaregiver = { id: 'dev1', name: 'Dev Caregiver', email: 'dev@test.com' };
  //     setToken(fakeToken);
  //     setCaregiver(fakeCaregiver);
  //   }
  // }, []);

  //  ===== END DEV BYPASS =====

  // Syncs the User data whenever it changes
  useEffect(() => {
    if (caregiver) {
      localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(caregiver));
    } else {
      localStorage.removeItem(STORAGE_KEYS.USER);
    }
  }, [caregiver]);

  // Syncs the Token to keep it aligned with authService
  useEffect(() => {
    if (token) {
      localStorage.setItem(STORAGE_KEYS.TOKEN, token);
    } else {
      localStorage.removeItem(STORAGE_KEYS.TOKEN);
    }
  }, [token]);

  const login = useCallback(async (email, password) => {
    setLoading(true);
    try {
      return await apiLogin(email, password);
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
      setToken(response.token);
      setCaregiver(response.caregiver);
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

  const value = {
    caregiver,
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
