import React from 'react';
import { Navigate, useLocation, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export const ProtectedRoute = ({ children, allowedRoles }) => {
  const { isAuthenticated, loading, role } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="min-h-screen bg-cream dark:bg-ink text-ink dark:text-cream flex flex-col items-center justify-center gap-3 font-sans transition-colors duration-200">
        <div className="w-8 h-8 border-2 border-border dark:border-ink-soft/40 border-t-terracotta dark:border-t-terracotta rounded-full animate-spin" />
        <p className="text-sm font-medium text-ink-soft dark:text-cream/70">
          Verifying session...
        </p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  if (allowedRoles && Array.isArray(allowedRoles) && allowedRoles.length > 0) {
    if (!allowedRoles.includes(role)) {
      if (role === 'admin') {
        return <Navigate to="/admin/dashboard" replace />;
      }
      return <Navigate to="/dashboard" replace />;
    }
  }

  return children ? children : <Outlet />;
};

export default ProtectedRoute;
