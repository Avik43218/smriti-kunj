import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { LanguageSelector } from '../components/LanguageSelector';
import {
  HeartHandshake,
  LogIn,
  AlertCircle,
  ShieldCheck,
  ArrowLeft,
  Sparkles,
  Sun,
  Moon,
  User,
  Eye,
  EyeOff,
  Lock,
  KeyRound,
  CheckCircle2,
} from 'lucide-react';
import { OtpInput } from '../components/OtpInput';
import { changePassword as apiChangePassword } from '../services/authService';
import loginBg from '../assets/regional/image1a.avif';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const Login = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { login, requestOtp, verifyOtp, logout, updateUserData, isAuthenticated, loading, role, isAdmin } = useAuth();
  const { theme, toggleTheme } = useTheme();

  // Multi-step authentication state: 'credentials' | 'otp' | 'force_password_change'
  const [step, setStep] = useState('credentials');

  // ROLE TRACKER: 'caregiver' | 'admin'
  const [loginRole, setLoginRole] = useState('caregiver');

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [otp, setOtp] = useState('');

  // Password rotation state (for temporary passwords)
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showNewPassword, setShowNewPassword] = useState(false);

  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState('');
  const [resendNotice, setResendNotice] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isResending, setIsResending] = useState(false);

  // Redirect if already authenticated and not in forced password change
  useEffect(() => {
    if (isAuthenticated && step !== 'force_password_change') {
      const defaultDest = isAdmin || role === 'admin' ? '/admin/dashboard' : '/dashboard';
      const origin = location.state?.from?.pathname || defaultDest;
      navigate(origin, { replace: true });
    }
  }, [isAuthenticated, step, navigate, location, role, isAdmin]);

  const validateCredentials = () => {
    const nextErrors = {};

    if (!email.trim()) {
      nextErrors.email = 'Email is required';
    } else if (!EMAIL_REGEX.test(email.trim())) {
      nextErrors.email = 'Please enter a valid email address';
    }

    if (!password) {
      nextErrors.password = 'Password is required';
    }

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const handleCredentialsSubmit = async (e) => {
    e.preventDefault();
    setSubmitError('');
    setResendNotice('');

    if (!validateCredentials()) {
      return;
    }

    setIsSubmitting(true);
    try {
      const loginRes = await login(email.trim(), password, loginRole);
      setStep('otp');
      if (loginRes?.debug_otp) {
        setOtp(loginRes.debug_otp);
        setResendNotice(`Testing code: ${loginRes.debug_otp}`);
      } else {
        setOtp('');
      }
    } catch (err) {
      setSubmitError(err.message || 'Unable to sign in. Please check your credentials and try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleOtpSubmit = async (e) => {
    if (e) e.preventDefault();
    setSubmitError('');
    setResendNotice('');

    if (!otp || otp.length !== 6) {
      setErrors({ otp: 'Please enter all 6 digits of the code' });
      return;
    }

    setIsSubmitting(true);
    try {
      const response = await verifyOtp(email.trim(), otp);
      const mustChange = Boolean(
        response?.must_change_password ||
        response?.caregiver?.must_change_password ||
        response?.user?.must_change_password
      );

      if (mustChange) {
        setStep('force_password_change');
        setNewPassword('');
        setConfirmPassword('');
        setErrors({});
        return;
      }

      const userRole = response?.user?.role || response?.caregiver?.role || loginRole;
      if (userRole === 'admin') {
        const fromPath = location.state?.from?.pathname;
        const destination = fromPath && fromPath.startsWith('/admin') ? fromPath : '/admin/dashboard';
        navigate(destination, { replace: true });
      } else {
        const fromPath = location.state?.from?.pathname;
        const destination = fromPath && !fromPath.startsWith('/admin') ? fromPath : '/dashboard';
        navigate(destination, { replace: true });
      }
    } catch (err) {
      setSubmitError(err.message || 'Invalid verification code. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handlePasswordChangeSubmit = async (e) => {
    e.preventDefault();
    setSubmitError('');
    const nextErrors = {};

    if (!newPassword || newPassword.length < 8) {
      nextErrors.newPassword = 'New password must be at least 8 characters long';
    }
    if (newPassword !== confirmPassword) {
      nextErrors.confirmPassword = 'Passwords do not match';
    }

    if (Object.keys(nextErrors).length > 0) {
      setErrors(nextErrors);
      return;
    }

    setIsSubmitting(true);
    try {
      await apiChangePassword(password, newPassword);
      if (updateUserData) {
        updateUserData({ must_change_password: false });
      }
      const userRole = role || loginRole;
      if (userRole === 'admin' || isAdmin) {
        navigate('/admin/dashboard', { replace: true });
      } else {
        navigate('/dashboard', { replace: true });
      }
    } catch (err) {
      setSubmitError(err.message || 'Failed to update password. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleCancelPasswordChange = async () => {
    await logout();
    setStep('credentials');
    setPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setOtp('');
    setSubmitError('');
    setErrors({});
  };

  const handleResendOtp = async () => {
    setSubmitError('');
    setResendNotice('');
    setIsResending(true);
    try {
      const res = await requestOtp(email.trim());
      if (res?.debug_otp) {
        setOtp(res.debug_otp);
        setResendNotice(`Testing code: ${res.debug_otp}`);
      } else {
        setResendNotice('A fresh verification code has been sent to your email.');
      }
    } catch (err) {
      setSubmitError(err.message || 'Failed to resend code. Please try again.');
    } finally {
      setIsResending(false);
    }
  };

  const handleBackToCredentials = () => {
    setStep('credentials');
    setOtp('');
    setSubmitError('');
    setResendNotice('');
    setErrors({});
  };

  return (
    <div className="min-h-screen w-full relative flex flex-col overflow-x-hidden font-sans select-none">
      {/* ── Full-bleed regional background image ── */}
      <div
        className="absolute inset-0 z-0 bg-cover bg-center bg-no-repeat"
        style={{ backgroundImage: `url(${loginBg})` }}
        aria-hidden="true"
      >
        {/* Warm duotone scrim — left lighter, right darker for card legibility */}
        <div className="absolute inset-0 bg-gradient-to-r from-ink/60 via-ink/45 to-ink/70" />
        {/* Subtle terracotta tone wash */}
        <div className="absolute inset-0 bg-terracotta/10 mix-blend-multiply" />
      </div>

      {/* ── Floating top-left logo pill ── */}
      <div className="fixed top-4 left-4 z-50">
        <div className="flex items-center gap-2.5 px-3 py-2 bg-cream/85 dark:bg-ink/50 backdrop-blur-md border border-border/80 dark:border-ink-soft/30 rounded-full shadow-card transition-colors">
          <div className="flex items-center justify-center w-7 h-7 rounded-full bg-terracotta/15 dark:bg-terracotta/30 border border-terracotta/30 dark:border-terracotta/50">
            <HeartHandshake className="w-4 h-4 text-terracotta" />
          </div>
          <span className="text-sm font-bold text-ink dark:text-cream tracking-tight">Smriti Kunj</span>
        </div>
      </div>

      {/* ── Floating top-right frosted controls pill ── */}
      <div className="fixed top-4 right-4 z-50">
        <div className="flex items-center gap-2 p-1.5 bg-cream/85 dark:bg-ink/50 backdrop-blur-md border border-border/80 dark:border-ink-soft/30 rounded-full shadow-card transition-colors">
          <LanguageSelector variant="default" />
          <button
            type="button"
            onClick={toggleTheme}
            aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
            className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-cream/70 dark:bg-ink-soft/20 hover:bg-cream dark:hover:bg-ink-soft/35 border border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream transition-all duration-200 active:scale-95 focus:outline-none shadow-xs"
          >
            {theme === 'dark' ? (
              <Sun className="w-4 h-4 text-gold animate-in spin-in-90 duration-200" />
            ) : (
              <Moon className="w-4 h-4 text-terracotta animate-in spin-in-90 duration-200" />
            )}
          </button>
        </div>
      </div>

      {/* ── Main content ── */}
      <main className="relative z-10 flex-1 flex items-center justify-center w-full max-w-7xl mx-auto px-6 sm:px-10 lg:px-16 py-24">
        <div className="w-full grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-14 items-center">

          {/* LEFT: Hero — directly over image */}
          <div className="lg:col-span-7 flex flex-col items-start text-left space-y-6">

            {/* Role pill + icon */}
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-12 h-12 rounded-card bg-terracotta/25 border border-terracotta/50 backdrop-blur-md shadow-card">
                {loginRole === 'admin'
                  ? <ShieldCheck className="w-6 h-6 text-terracotta" />
                  : <HeartHandshake className="w-6 h-6 text-terracotta" />}
              </div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-ink/40 border border-ink-soft/30 backdrop-blur-md text-gold text-xs font-semibold tracking-wider uppercase">
                <Sparkles className="w-3.5 h-3.5 text-gold" />
                <span>{loginRole === 'admin' ? 'Tier 1 Administration' : 'Caregiver Portal'}</span>
              </div>
            </div>

            {/* Trilingual static wordmark */}
            <div className="space-y-1">
              <h1 className="text-4xl sm:text-5xl font-bold tracking-tight text-cream drop-shadow-md leading-tight font-sans">
                Smriti Kunj
              </h1>
              <p className="text-2xl sm:text-3xl font-semibold text-cream/85 drop-shadow tracking-wide">
                স্মৃতি কুঞ্জ
              </p>
              <p className="text-xl sm:text-2xl font-medium text-cream/75 drop-shadow tracking-wide">
                स्मृति कुञ्ज
              </p>
            </div>

            <p className="text-xs text-gold/90 font-semibold uppercase tracking-widest">
              Cognitive Assist &amp; Dignified Memory Preservation Platform
            </p>

            {/* Description */}
            <div className="relative pl-4 border-l-[3px] border-terracotta/70 py-1 max-w-xl">
              <p className="text-sm sm:text-[15px] text-cream/90 leading-relaxed font-normal drop-shadow-sm">
                {loginRole === 'admin'
                  ? "Access the administrative console to provision staff credentials, oversee cross-caregiver portals, and manage platform synchronization securely."
                  : "Every memory is sacred, and every voice carries timeless dignity. You are never defined by what fades, but by the love, wisdom, and heritage that will always remain. Smriti Kunj stands beside you and your family."
                }
              </p>
            </div>

            {/* Trust indicators */}
            <div className="flex items-center gap-4 text-xs text-cream/65">
              <span className="flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-sage animate-pulse" />
                Encrypted Session: TLS 1.3
              </span>
              <span>•</span>
              <span>{loginRole === 'admin' ? 'Admin Verification Required' : 'Dedicated Care Support'}</span>
            </div>
          </div>

          {/* RIGHT: Auth Card */}
          <div className="lg:col-span-5 flex justify-center lg:justify-end w-full">
            <div className="w-full max-w-md bg-surface/95 dark:bg-ink-soft/20 backdrop-blur-2xl border border-border dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-card relative overflow-hidden transition-colors duration-300 text-ink dark:text-cream">

              {/* Terracotta–gold accent edge */}
              <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-terracotta via-gold to-terracotta" />

              <div className="mb-6 pt-1">
                <div className="flex items-center justify-between">
                  <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-ink dark:text-cream">
                    {step === 'credentials'
                      ? (loginRole === 'admin' ? 'Sign In to Admin Center' : 'Sign In to Portal')
                      : 'Two-Factor Verification'}
                  </h2>
                  <div className="w-8 h-8 rounded-card bg-terracotta/10 dark:bg-terracotta/20 flex items-center justify-center">
                    {step === 'credentials'
                      ? <LogIn className="w-4 h-4 text-terracotta" />
                      : <ShieldCheck className="w-4 h-4 text-terracotta" />}
                  </div>
                </div>
                <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-1">
                  {step === 'credentials'
                    ? `Enter your credentials to access the ${loginRole === 'admin' ? 'administrative console' : 'caregiver console'}`
                    : 'Enter the 6-digit security code sent to your email'}
                </p>
              </div>

              {submitError && (
                <div className="mb-5 p-3.5 bg-status-urgent/10 dark:bg-gold/15 border border-status-urgent/30 dark:border-gold/30 rounded-lg flex items-start gap-2.5">
                  <AlertCircle className="w-5 h-5 text-status-urgent dark:text-gold shrink-0 mt-0.5" />
                  <p className="text-xs sm:text-sm text-status-urgent dark:text-gold font-medium leading-relaxed">
                    {submitError}
                  </p>
                </div>
              )}

              {resendNotice && (
                <div className="mb-5 p-3.5 bg-sage/15 border border-sage/40 rounded-lg flex items-start gap-2.5">
                  <ShieldCheck className="w-5 h-5 text-sage shrink-0 mt-0.5" />
                  <p className="text-xs sm:text-sm text-ink dark:text-cream font-medium leading-relaxed">
                    {resendNotice}
                  </p>
                </div>
              )}

              {/* STEP 1: Credentials */}
              {step === 'credentials' && (
                <form onSubmit={handleCredentialsSubmit} noValidate className="space-y-4">

                  {/* Role toggle */}
                  <div className="flex bg-cream/40 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/20 rounded-lg p-1 mb-6">
                    <button
                      type="button"
                      onClick={() => setLoginRole('caregiver')}
                      className={`flex-1 flex items-center justify-center gap-1.5 py-2 text-[11px] uppercase tracking-wide font-bold rounded-md transition-all ${loginRole === 'caregiver'
                        ? 'bg-surface dark:bg-ink-soft/40 text-terracotta shadow-sm'
                        : 'text-ink-soft dark:text-cream/50 hover:text-ink dark:hover:text-cream/80'
                        }`}
                    >
                      <User className="w-3.5 h-3.5" />
                      Caregiver
                    </button>
                    <button
                      type="button"
                      onClick={() => setLoginRole('admin')}
                      className={`flex-1 flex items-center justify-center gap-1.5 py-2 text-[11px] uppercase tracking-wide font-bold rounded-md transition-all ${loginRole === 'admin'
                        ? 'bg-surface dark:bg-ink-soft/40 text-terracotta shadow-sm'
                        : 'text-ink-soft dark:text-cream/50 hover:text-ink dark:hover:text-cream/80'
                        }`}
                    >
                      <ShieldCheck className="w-3.5 h-3.5" />
                      Admin
                    </button>
                  </div>

                  {/* Email */}
                  <div>
                    <label htmlFor="email" className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1.5">
                      Email Address
                    </label>
                    <input
                      id="email"
                      type="email"
                      autoComplete="email"
                      value={email}
                      onChange={(e) => {
                        setEmail(e.target.value);
                        if (errors.email) setErrors((prev) => ({ ...prev, email: undefined }));
                      }}
                      placeholder={loginRole === 'admin' ? 'admin@smritikunj.org' : 'caregiver@example.com'}
                      className={`w-full px-3.5 py-2.5 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${errors.email
                        ? 'border-status-urgent'
                        : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                        }`}
                      disabled={isSubmitting || loading}
                    />
                    {errors.email && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1.5 flex items-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5" />
                        {errors.email}
                      </p>
                    )}
                  </div>

                  {/* Password */}
                  <div>
                    <label htmlFor="password" className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1.5">
                      Password
                    </label>
                    <div className="relative">
                      <input
                        id="password"
                        type={showPassword ? 'text' : 'password'}
                        autoComplete="current-password"
                        value={password}
                        onChange={(e) => {
                          setPassword(e.target.value);
                          if (errors.password) setErrors((prev) => ({ ...prev, password: undefined }));
                        }}
                        placeholder="••••••••"
                        className={`w-full pl-3.5 pr-10 py-2.5 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${errors.password
                          ? 'border-status-urgent'
                          : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                          }`}
                        disabled={isSubmitting || loading}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword((prev) => !prev)}
                        className="absolute right-2.5 top-1/2 -translate-y-1/2 p-1 text-terracotta/75 hover:text-terracotta dark:text-terracotta/80 dark:hover:text-terracotta transition-colors rounded-md focus:outline-none focus:ring-0 border-0 cursor-pointer"
                        title={showPassword ? 'Hide password' : 'Show password'}
                        aria-label={showPassword ? 'Hide password' : 'Show password'}
                      >
                        {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                    {errors.password && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1.5 flex items-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5" />
                        {errors.password}
                      </p>
                    )}
                  </div>

                  {/* Submit */}
                  <div className="pt-2">
                    <button
                      type="submit"
                      disabled={isSubmitting || loading}
                      className="w-full py-3 px-4 bg-terracotta hover:bg-terracotta-dark text-surface font-medium text-sm rounded-lg transition-colors flex items-center justify-center gap-2 focus:outline-none focus:ring-2 focus:ring-terracotta/40 disabled:opacity-60 disabled:cursor-not-allowed shadow-card"
                    >
                      {isSubmitting || loading ? (
                        <>
                          <div className="w-4 h-4 border-2 border-surface border-t-transparent rounded-full animate-spin" />
                          <span>Signing in...</span>
                        </>
                      ) : (
                        <>
                          <LogIn className="w-4 h-4" />
                          <span>Sign In</span>
                        </>
                      )}
                    </button>
                  </div>

                  {/* Managed accounts notice */}
                  <div className="text-center pt-3 mt-1 border-t border-border/60 dark:border-ink-soft/30">
                    <p className="text-xs text-ink-soft dark:text-cream/70 leading-relaxed">
                      Caregiver and admin accounts are managed by facility administrators.
                      {loginRole === 'admin' && (
                        <span className="block mt-1 font-mono text-[11px] text-terracotta dark:text-gold/90 font-medium">
                          Demo Admin: admin@smritikunj.org &bull; admin123
                        </span>
                      )}
                    </p>
                  </div>
                </form>
              )}

              {/* STEP 2: OTP */}
              {step === 'otp' && (
                <form onSubmit={handleOtpSubmit} noValidate className="space-y-5">
                  <div className="text-center">
                    <p className="text-xs sm:text-sm text-ink dark:text-cream leading-relaxed">
                      Enter the 6-digit security code sent to
                    </p>
                    <p className="text-xs sm:text-sm font-semibold text-ink dark:text-cream truncate mt-0.5">
                      {email}
                    </p>
                  </div>

                  <div className="py-2">
                    <OtpInput
                      value={otp}
                      onChange={(val) => {
                        setOtp(val);
                        if (errors.otp) setErrors((prev) => ({ ...prev, otp: undefined }));
                      }}
                      onComplete={() => { }}
                      disabled={isSubmitting || loading}
                      hasError={Boolean(errors.otp)}
                    />
                    {errors.otp && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-2 flex items-center justify-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5" />
                        {errors.otp}
                      </p>
                    )}
                  </div>

                  <div>
                    <button
                      type="submit"
                      disabled={isSubmitting || loading || otp.length !== 6}
                      className="w-full py-3 px-4 bg-terracotta hover:bg-terracotta-dark text-surface font-medium text-sm rounded-lg transition-colors flex items-center justify-center gap-2 focus:outline-none focus:ring-2 focus:ring-terracotta/40 disabled:opacity-60 disabled:cursor-not-allowed shadow-card"
                    >
                      {isSubmitting || loading ? (
                        <>
                          <div className="w-4 h-4 border-2 border-surface border-t-transparent rounded-full animate-spin" />
                          <span>Verifying...</span>
                        </>
                      ) : (
                        <>
                          <ShieldCheck className="w-4 h-4" />
                          <span>Verify Code</span>
                        </>
                      )}
                    </button>
                  </div>

                  <div className="flex items-center justify-between pt-1 text-xs">
                    <button
                      type="button"
                      onClick={handleBackToCredentials}
                      disabled={isSubmitting || loading}
                      className="text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream font-medium transition-colors flex items-center gap-1 focus:outline-none"
                    >
                      <ArrowLeft className="w-3.5 h-3.5" />
                      <span>Change email</span>
                    </button>
                    <button
                      type="button"
                      onClick={handleResendOtp}
                      disabled={isResending || isSubmitting || loading}
                      className="text-terracotta hover:text-terracotta-dark font-medium transition-colors disabled:opacity-50 focus:outline-none"
                    >
                      {isResending ? 'Sending...' : 'Resend code'}
                    </button>
                  </div>
                </form>
              )}

              {/* STEP 3: Forced Password Change on Temporary Password */}
              {step === 'force_password_change' && (
                <form onSubmit={handlePasswordChangeSubmit} noValidate className="space-y-4">
                  <div className="text-center pb-1">
                    <div className="w-10 h-10 rounded-full bg-gold/15 text-gold border border-gold/30 flex items-center justify-center mx-auto mb-2">
                      <KeyRound className="w-5 h-5" />
                    </div>
                    <h3 className="text-base font-bold text-ink dark:text-cream">
                      Create Permanent Password
                    </h3>
                    <p className="text-xs text-ink-soft dark:text-cream/70 mt-1 leading-relaxed">
                      You are logging in with a temporary password. Please choose a new secure password to activate your account.
                    </p>
                  </div>

                  {/* New Password */}
                  <div>
                    <label htmlFor="newPassword" className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1.5">
                      New Password (min 8 characters)
                    </label>
                    <div className="relative">
                      <input
                        id="newPassword"
                        type={showNewPassword ? 'text' : 'password'}
                        value={newPassword}
                        onChange={(e) => {
                          setNewPassword(e.target.value);
                          if (errors.newPassword) setErrors((prev) => ({ ...prev, newPassword: undefined }));
                        }}
                        placeholder="••••••••••••"
                        className={`w-full px-3.5 py-2.5 pr-10 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                          errors.newPassword ? 'border-status-urgent' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                        }`}
                        disabled={isSubmitting}
                      />
                      <button
                        type="button"
                        onClick={() => setShowNewPassword((prev) => !prev)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-soft dark:text-cream/60 hover:text-ink dark:hover:text-cream focus:outline-none"
                      >
                        {showNewPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                    {errors.newPassword && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1.5 flex items-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5" />
                        {errors.newPassword}
                      </p>
                    )}
                  </div>

                  {/* Confirm Password */}
                  <div>
                    <label htmlFor="confirmPassword" className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1.5">
                      Confirm New Password
                    </label>
                    <input
                      id="confirmPassword"
                      type={showNewPassword ? 'text' : 'password'}
                      value={confirmPassword}
                      onChange={(e) => {
                        setConfirmPassword(e.target.value);
                        if (errors.confirmPassword) setErrors((prev) => ({ ...prev, confirmPassword: undefined }));
                      }}
                      placeholder="••••••••••••"
                      className={`w-full px-3.5 py-2.5 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                        errors.confirmPassword ? 'border-status-urgent' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                      }`}
                      disabled={isSubmitting}
                    />
                    {errors.confirmPassword && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1.5 flex items-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5" />
                        {errors.confirmPassword}
                      </p>
                    )}
                  </div>

                  {/* Submit Button */}
                  <div className="pt-2">
                    <button
                      type="submit"
                      disabled={isSubmitting || !newPassword || !confirmPassword}
                      className="w-full py-3 px-4 bg-terracotta hover:bg-terracotta-dark text-surface font-medium text-sm rounded-lg transition-colors flex items-center justify-center gap-2 focus:outline-none focus:ring-2 focus:ring-terracotta/40 disabled:opacity-60 disabled:cursor-not-allowed shadow-card"
                    >
                      {isSubmitting ? (
                        <>
                          <div className="w-4 h-4 border-2 border-surface border-t-transparent rounded-full animate-spin" />
                          <span>Updating password...</span>
                        </>
                      ) : (
                        <>
                          <CheckCircle2 className="w-4 h-4" />
                          <span>Save Password &amp; Continue</span>
                        </>
                      )}
                    </button>
                  </div>

                  <div className="text-center pt-2">
                    <button
                      type="button"
                      onClick={handleCancelPasswordChange}
                      disabled={isSubmitting}
                      className="text-xs text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream font-medium transition-colors focus:outline-none"
                    >
                      Cancel and sign out
                    </button>
                  </div>
                </form>
              )}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

export default Login;