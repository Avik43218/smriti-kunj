import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { registerAdmin } from '../../services/authService';
import { LanguageSelector } from '../../components/LanguageSelector';
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator';
import registerBg from '../../assets/regional/image1a.avif';
import {
  ShieldCheck,
  UserPlus,
  AlertCircle,
  Check,
  X,
  Sparkles,
  Sun,
  Moon,
  KeyRound,
  Eye,
  EyeOff,
} from 'lucide-react';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const RegisterAdmin = () => {
  const navigate = useNavigate();
  const { isAuthenticated, user } = useAuth();
  const { theme, toggleTheme } = useTheme();

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [adminCode, setAdminCode] = useState('');
  const [showAdminCode, setShowAdminCode] = useState(false);
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      if (user?.role === 'admin') {
        navigate('/admin/dashboard', { replace: true });
      } else {
        navigate('/dashboard', { replace: true });
      }
    }
  }, [isAuthenticated, user, navigate]);

  const validateForm = () => {
    const nextErrors = {};

    if (!name.trim()) {
      nextErrors.name = 'Full name is required';
    }

    if (!email.trim()) {
      nextErrors.email = 'Email address is required';
    } else if (!EMAIL_REGEX.test(email.trim())) {
      nextErrors.email = 'Please enter a valid email address';
    }

    if (!adminCode.trim()) {
      nextErrors.adminCode = 'Admin authorization key is required';
    } else if (adminCode.trim().length < 4) {
      nextErrors.adminCode = 'Please enter a valid authorization key';
    }

    if (!password) {
      nextErrors.password = 'Password is required';
    } else if (password.length < 8) {
      nextErrors.password = 'Password must be at least 8 characters long';
    }

    if (!confirmPassword) {
      nextErrors.confirmPassword = 'Please confirm your password';
    } else if (password !== confirmPassword) {
      nextErrors.confirmPassword = 'Passwords do not match';
    }

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const handleRegisterSubmit = async (e) => {
    e.preventDefault();
    setSubmitError('');

    if (!validateForm()) {
      return;
    }

    setIsSubmitting(true);
    try {
      // BACKEND-TODO: see ../../docs/API_ENDPOINTS_NEEDED.md §1 Admin Registration
      await registerAdmin(name.trim(), email.trim(), password, adminCode.trim());

      // Redirect to login page with admin role pre-selected
      navigate('/login', { state: { role: 'admin' }, replace: true });
    } catch (err) {
      setSubmitError(
        err?.message || 'Admin registration failed. Please verify your authorization key and credentials.'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen w-full relative flex flex-col justify-center overflow-x-hidden font-sans select-none">
      {/* ── Full-bleed regional background image ── */}
      <div
        className="absolute inset-0 z-0 bg-cover bg-center bg-no-repeat"
        style={{ backgroundImage: `url(${registerBg})` }}
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
            <ShieldCheck className="w-4 h-4 text-terracotta" />
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
          {/* LEFT COLUMN: Hero — directly over image */}
          <div className="lg:col-span-7 flex flex-col items-start text-left space-y-6">
            {/* Pill & Icon Header */}
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-12 h-12 rounded-card bg-terracotta/25 border border-terracotta/50 backdrop-blur-md shadow-card">
                <ShieldCheck className="w-6 h-6 text-terracotta" />
              </div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-ink/40 border border-ink-soft/30 backdrop-blur-md text-gold text-xs font-semibold tracking-wider uppercase">
                <Sparkles className="w-3.5 h-3.5 text-gold" />
                <span>Tier 1 Administration</span>
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

            {/* Administrative Tagline */}
            <div className="relative pl-4 border-l-[3px] border-terracotta/70 py-1 max-w-xl">
              <p className="text-sm sm:text-[15px] text-cream/90 leading-relaxed font-normal drop-shadow-sm">
                Access the administrative console to provision staff credentials, oversee cross-caregiver portals, and manage platform synchronization securely.
              </p>
            </div>

            {/* Cultural subtle status tag */}
            <div className="pt-1 flex items-center gap-4 text-xs text-cream/70 font-medium">
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-sage animate-pulse" />
                Encrypted Session: TLS 1.3
              </span>
              <span>•</span>
              <span>Admin Verification Required</span>
            </div>
          </div>

          {/* RIGHT COLUMN: Admin Registration Card */}
          <div className="lg:col-span-5 flex justify-center lg:justify-end w-full">
            <div className="w-full max-w-md bg-surface/95 dark:bg-ink-soft/20 backdrop-blur-2xl border border-border dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-card relative overflow-hidden transition-colors duration-300 text-ink dark:text-cream">
              {/* Subtle Heritage Top Trim */}
              <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-terracotta via-gold to-terracotta" />

              {/* Card Title */}
              <div className="mb-5 pt-1">
                <div className="flex items-center justify-between">
                  <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-ink dark:text-cream">
                    Register Admin
                  </h2>
                  <div className="w-8 h-8 rounded-card bg-terracotta/10 dark:bg-terracotta/20 flex items-center justify-center">
                    <ShieldCheck className="w-4 h-4 text-terracotta" />
                  </div>
                </div>
                <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-1">
                  Create an accredited administrator account to manage clinical staff
                </p>
              </div>

              {/* Error Alert */}
              {submitError && (
                <div className="mb-4 p-3.5 bg-status-urgent/10 dark:bg-gold/15 border border-status-urgent/30 dark:border-gold/30 rounded-lg flex items-start gap-2.5">
                  <AlertCircle className="w-5 h-5 text-status-urgent dark:text-gold shrink-0 mt-0.5" />
                  <p className="text-xs sm:text-sm text-status-urgent dark:text-gold font-medium leading-relaxed">
                    {submitError}
                  </p>
                </div>
              )}

              <form onSubmit={handleRegisterSubmit} noValidate className="space-y-3.5">
                {/* Full Name Field */}
                <div>
                  <label
                    htmlFor="admin-name"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Full Name
                  </label>
                  <input
                    id="admin-name"
                    type="text"
                    autoComplete="name"
                    value={name}
                    onChange={(e) => {
                      setName(e.target.value);
                      if (errors.name) {
                        setErrors((prev) => ({ ...prev, name: undefined }));
                      }
                    }}
                    placeholder="Admin Dr. Sarah Jenkins"
                    className={`w-full px-3.5 py-2 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                      errors.name
                        ? 'border-status-urgent dark:border-gold/70'
                        : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                    }`}
                    disabled={isSubmitting}
                  />
                  {errors.name && (
                    <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
                      <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                      {errors.name}
                    </p>
                  )}
                </div>

                {/* Email Field */}
                <div>
                  <label
                    htmlFor="admin-email"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Email Address
                  </label>
                  <input
                    id="admin-email"
                    type="email"
                    autoComplete="email"
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value);
                      if (errors.email) {
                        setErrors((prev) => ({ ...prev, email: undefined }));
                      }
                    }}
                    placeholder="admin@smritikunj.org"
                    className={`w-full px-3.5 py-2 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                      errors.email
                        ? 'border-status-urgent dark:border-gold/70'
                        : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                    }`}
                    disabled={isSubmitting}
                  />

                  {/* Real-time Email Validity Indicator */}
                  {email.length > 0 && (
                    <div className="mt-1 flex items-center gap-1 text-xs">
                      {EMAIL_REGEX.test(email.trim()) ? (
                        <span className="text-sage flex items-center gap-1 font-medium">
                          <Check className="w-3.5 h-3.5" />
                          <span>Valid email format</span>
                        </span>
                      ) : (
                        <span className="text-status-urgent dark:text-gold flex items-center gap-1 font-medium">
                          <X className="w-3.5 h-3.5" />
                          <span>Invalid email format</span>
                        </span>
                      )}
                    </div>
                  )}

                  {errors.email && email.length === 0 && (
                    <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
                      <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                      {errors.email}
                    </p>
                  )}
                </div>

                {/* Admin Authorization Code */}
                <div>
                  <label
                    htmlFor="admin-code"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Admin Authorization Key
                  </label>
                  <div className="relative">
                    <input
                      id="admin-code"
                      type={showAdminCode ? 'text' : 'password'}
                      autoComplete="off"
                      value={adminCode}
                      onChange={(e) => {
                        setAdminCode(e.target.value);
                        if (errors.adminCode) {
                          setErrors((prev) => ({ ...prev, adminCode: undefined }));
                        }
                      }}
                      placeholder="e.g. SM-ADMIN-AUTH-KEY"
                      className={`w-full pl-9 pr-10 py-2 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                        errors.adminCode
                          ? 'border-status-urgent dark:border-gold/70'
                          : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                      }`}
                      disabled={isSubmitting}
                    />
                    <KeyRound className="w-4 h-4 text-ink-soft/60 dark:text-cream/40 absolute left-3 top-2.5 pointer-events-none" />
                    <button
                      type="button"
                      onClick={() => setShowAdminCode((prev) => !prev)}
                      className="absolute right-2.5 top-1/2 -translate-y-1/2 p-1 text-terracotta/75 hover:text-terracotta dark:text-[#D47D5C] dark:hover:text-[#E2A48E] transition-colors rounded-md focus:outline-none focus:ring-0 border-0 cursor-pointer"
                      title={showAdminCode ? 'Hide authorization key' : 'Show authorization key'}
                      aria-label={showAdminCode ? 'Hide authorization key' : 'Show authorization key'}
                    >
                      {showAdminCode ? (
                        <EyeOff className="w-4 h-4" />
                      ) : (
                        <Eye className="w-4 h-4" />
                      )}
                    </button>
                  </div>
                  {errors.adminCode && (
                    <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
                      <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                      {errors.adminCode}
                    </p>
                  )}
                </div>

                {/* Password Field */}
                <div>
                  <label
                    htmlFor="admin-password"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Password
                  </label>
                  <div className="relative">
                    <input
                      id="admin-password"
                      type={showPassword ? 'text' : 'password'}
                      autoComplete="new-password"
                      value={password}
                      onChange={(e) => {
                        setPassword(e.target.value);
                        if (errors.password) {
                          setErrors((prev) => ({ ...prev, password: undefined }));
                        }
                      }}
                      placeholder="Minimum 8 characters"
                      className={`w-full pl-3.5 pr-10 py-2 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                        errors.password
                          ? 'border-status-urgent dark:border-gold/70'
                          : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                      }`}
                      disabled={isSubmitting}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword((prev) => !prev)}
                      className="absolute right-2.5 top-1/2 -translate-y-1/2 p-1 text-terracotta/75 hover:text-terracotta dark:text-[#D47D5C] dark:hover:text-[#E2A48E] transition-colors rounded-md focus:outline-none focus:ring-0 border-0 cursor-pointer"
                      title={showPassword ? 'Hide password' : 'Show password'}
                      aria-label={showPassword ? 'Hide password' : 'Show password'}
                    >
                      {showPassword ? (
                        <EyeOff className="w-4 h-4" />
                      ) : (
                        <Eye className="w-4 h-4" />
                      )}
                    </button>
                  </div>
                  <PasswordStrengthIndicator password={password} />

                  {errors.password && (
                    <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
                      <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                      {errors.password}
                    </p>
                  )}
                </div>

                {/* Confirm Password Field */}
                <div>
                  <label
                    htmlFor="admin-confirm-password"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Confirm Password
                  </label>
                  <div className="relative">
                    <input
                      id="admin-confirm-password"
                      type={showConfirmPassword ? 'text' : 'password'}
                      autoComplete="new-password"
                      value={confirmPassword}
                      onChange={(e) => {
                        setConfirmPassword(e.target.value);
                        if (errors.confirmPassword) {
                          setErrors((prev) => ({ ...prev, confirmPassword: undefined }));
                        }
                      }}
                      placeholder="Re-enter your password"
                      className={`w-full pl-3.5 pr-10 py-2 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                        errors.confirmPassword
                          ? 'border-status-urgent dark:border-gold/70'
                          : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                      }`}
                      disabled={isSubmitting}
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword((prev) => !prev)}
                      className="absolute right-2.5 top-1/2 -translate-y-1/2 p-1 text-terracotta/75 hover:text-terracotta dark:text-[#D47D5C] dark:hover:text-[#E2A48E] transition-colors rounded-md focus:outline-none focus:ring-0 border-0 cursor-pointer"
                      title={showConfirmPassword ? 'Hide password' : 'Show password'}
                      aria-label={showConfirmPassword ? 'Hide password' : 'Show password'}
                    >
                      {showConfirmPassword ? (
                        <EyeOff className="w-4 h-4" />
                      ) : (
                        <Eye className="w-4 h-4" />
                      )}
                    </button>
                  </div>

                  {/* Real-time Match Indicator */}
                  {confirmPassword.length > 0 && (
                    <div className="mt-1 flex items-center gap-1 text-xs">
                      {password === confirmPassword ? (
                        <span className="text-sage flex items-center gap-1 font-medium">
                          <Check className="w-3.5 h-3.5" />
                          <span>Passwords match</span>
                        </span>
                      ) : (
                        <span className="text-status-urgent dark:text-gold flex items-center gap-1 font-medium">
                          <X className="w-3.5 h-3.5" />
                          <span>Passwords do not match</span>
                        </span>
                      )}
                    </div>
                  )}

                  {errors.confirmPassword && confirmPassword.length === 0 && (
                    <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
                      <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                      {errors.confirmPassword}
                    </p>
                  )}
                </div>

                {/* Submit Button */}
                <div className="pt-2">
                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className="w-full py-2.5 px-4 bg-terracotta hover:bg-terracotta-dark text-surface font-medium text-sm rounded-lg transition-colors flex items-center justify-center gap-2 focus:outline-none focus:ring-2 focus:ring-terracotta/40 disabled:opacity-60 disabled:cursor-not-allowed shadow-card"
                  >
                    {isSubmitting ? (
                      <>
                        <div className="w-4 h-4 border-2 border-surface border-t-transparent rounded-full animate-spin" />
                        <span>Registering administrator...</span>
                      </>
                    ) : (
                      <>
                        <UserPlus className="w-4 h-4" />
                        <span>Create Admin Account</span>
                      </>
                    )}
                  </button>
                </div>

                {/* Link to Login */}
                <div className="text-center pt-2.5 mt-1 border-t border-border/60 dark:border-ink-soft/30">
                  <p className="text-xs text-ink-soft dark:text-cream/70">
                    Already have an account?{' '}
                    <Link
                      to="/login"
                      state={{ role: 'admin' }}
                      className="text-terracotta hover:text-terracotta-dark font-semibold transition-colors focus:outline-none focus:underline"
                    >
                      Log in
                    </Link>
                  </p>
                </div>
              </form>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

export default RegisterAdmin;
