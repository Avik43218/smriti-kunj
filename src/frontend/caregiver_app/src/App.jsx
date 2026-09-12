import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import { ProtectedRoute } from './components/ProtectedRoute';
import { DashboardLayout } from './layouts/DashboardLayout';
import { PatientLayout } from './layouts/PatientLayout';
import { Login } from './pages/Login';
import { Register } from './pages/Register';
import { Dashboard } from './pages/Dashboard';
import { RegisterPatient } from './pages/RegisterPatient';
import { Analytics } from './pages/Analytics';
import { CarePlan } from './pages/CarePlan';
import { PatientDetails } from './pages/PatientDetails';
import { AdminDashboard } from './pages/admin/AdminDashboard';
import { ManageCaregivers } from './pages/admin/ManageCaregivers';
import { AllPatients } from './pages/admin/AllPatients';

import { useAuth } from './context/AuthContext';

const RootRedirect = () => {
  const { role, isAuthenticated, isAdmin } = useAuth();
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  if (isAdmin || role === 'admin') {
    return <Navigate to="/admin/dashboard" replace />;
  }
  return <Navigate to="/dashboard" replace />;
};

export const App = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ThemeProvider>
          <Routes>
            {/* Public Authentication Routes */}
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />

            {/* Admin Management Routes wrapped in DashboardLayout */}
            <Route
              element={
                <ProtectedRoute allowedRoles={['admin']}>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route path="/admin" element={<Navigate to="/admin/dashboard" replace />} />
              <Route path="/admin/dashboard" element={<AdminDashboard />} />
              <Route path="/admin/caregivers" element={<ManageCaregivers />} />
              <Route path="/admin/patients" element={<AllPatients />} />
            </Route>

            {/* Main Caregiver Dashboard Routes wrapped in DashboardLayout */}
            <Route
              element={
                <ProtectedRoute allowedRoles={['caregiver']}>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/patients/new" element={<RegisterPatient />} />
              <Route path="/care-plan" element={<CarePlan />} />
              <Route path="/customization" element={<CarePlan />} />
            </Route>

            {/* Patient Context Routes wrapped in PatientLayout */}
            <Route
              element={
                <ProtectedRoute allowedRoles={['caregiver']}>
                  <PatientLayout />
                </ProtectedRoute>
              }
            >
              <Route path="/patients/:id" element={<Navigate to="details" replace />} />
              <Route path="/patients/:id/details" element={<PatientDetails />} />
              <Route path="/patients/:id/care-plan" element={<CarePlan />} />
              <Route path="/patients/:id/analytics" element={<Analytics />} />
            </Route>

            {/* Role-aware default redirect */}
            <Route path="/" element={<RootRedirect />} />
            <Route path="*" element={<RootRedirect />} />
          </Routes>
        </ThemeProvider>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;
