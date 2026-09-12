import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { LanguageSelector } from '../components/LanguageSelector';
import { LiveBackgroundShader } from '../components/LiveBackgroundShader';
import {
  HeartHandshake,
  LogIn,
  AlertCircle,
  ShieldCheck,
  ArrowLeft,
  Sparkles,
  Sun,
  Moon,
  User, // Added User icon for the toggle
} from 'lucide-react';
import { OtpInput } from '../components/OtpInput';
import { Footer } from '../components/Footer';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const Login = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { login, requestOtp, verifyOtp, isAuthenticated, loading } = useAuth();
  const { theme, toggleTheme } = useTheme();

  // Multi-step authentication state: 'credentials' | 'otp'
  const [step, setStep] = useState('credentials');

  // ROLE TRACKER ADDED HERE
  const [loginRole, setLoginRole] = useState('caregiver');

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');

  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState('');
  const [resendNotice, setResendNotice] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isResending, setIsResending] = useState(false);

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      const origin = location.state?.from?.pathname || '/dashboard';
      navigate(origin, { replace: true });
    }
  }, [isAuthenticated, navigate, location]);

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
      // Pass the loginRole to your auth context
      const res = await login(email.trim(), password, loginRole);

      // DEV MOCK BYPASS: If the mock returns the user immediately, skip OTP and route them
      if (res && res.role) {
        if (res.role === 'admin') navigate('/admin/dashboard', { replace: true });
        else navigate('/dashboard', { replace: true });
        return;
      }

      // Normal Live Backend Flow
      await requestOtp(email.trim());
      setStep('otp');
      setOtp('');
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
      // Step 2: Verify OTP and finalize session
      await verifyOtp(email.trim(), otp);
      const destination = location.state?.from?.pathname || '/dashboard';
      navigate(destination, { replace: true });
    } catch (err) {
      setSubmitError(err.message || 'Invalid verification code. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleResendOtp = async () => {
    setSubmitError('');
    setResendNotice('');
    setIsResending(true);
    try {
      await requestOtp(email.trim());
      setResendNotice('A fresh verification code has been sent to your email.');
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
    <div className="min-h-screen w-full relative flex flex-col justify-between overflow-x-hidden font-sans select-none bg-cream dark:bg-ink text-ink dark:text-cream transition-colors duration-300">
      {/* Live Animated Brahmaputra Silk Background Shader */}
      <LiveBackgroundShader />

      {/* Persistent Fixed Top Header */}
      <header className="fixed top-0 left-0 w-full z-40 bg-ink/85 backdrop-blur-xl border-b border-ink-soft/40 shadow-card transition-colors duration-300">
        <div className="h-16 sm:h-20 w-full px-4 sm:px-8 max-w-[1600px] mx-auto flex items-center justify-between gap-4">

          {/* Header Brand */}
          <div className="flex items-center gap-3">
            <div className="flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 rounded-card bg-terracotta/20 border border-terracotta/40">
              <HeartHandshake className="w-4 h-4 sm:w-5 sm:h-5 text-terracotta" />
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-base sm:text-lg font-bold text-cream tracking-tight">Smriti Kunj</span>
              <span className="text-xs sm:text-sm text-cream/70 font-sans hidden sm:inline">(স্মৃতি কুঞ্জ)</span>
            </div>
          </div>

          {/* Top Controls Cluster */}
          <div className="flex items-center gap-2 p-1 bg-ink-soft/30 backdrop-blur-md border border-ink-soft/40 rounded-full shadow-card">
            <LanguageSelector variant="dark" />
            <button
              type="button"
              onClick={toggleTheme}
              aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
              className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-ink-soft/20 hover:bg-ink-soft/35 border border-ink-soft/40 text-cream/80 hover:text-cream transition-all duration-200 active:scale-95"
            >
              {theme === 'dark' ? (
                <Sun className="w-4 h-4 text-gold animate-in spin-in-90 duration-200" />
              ) : (
                <Moon className="w-4 h-4 text-cream animate-in spin-in-90 duration-200" />
              )}
            </button>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="relative z-10 flex-1 flex items-center justify-center w-full max-w-7xl mx-auto px-6 sm:px-10 lg:px-16 pt-24 sm:pt-28 pb-12">
        <div className="w-full grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-14 items-center">

          {/* LEFT COLUMN */}
          <div className="lg:col-span-7 flex flex-col items-start text-left space-y-6">

            {/* Pill & Icon Header - Updates dynamically based on role */}
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-12 h-12 rounded-card bg-terracotta/20 border border-terracotta/40 backdrop-blur-md shadow-card">
                {loginRole === 'admin' ? <ShieldCheck className="w-6 h-6 text-terracotta" /> : <HeartHandshake className="w-6 h-6 text-terracotta" />}
              </div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-surface/10 border border-border/30 backdrop-blur-md text-gold text-xs font-semibold tracking-wider uppercase">
                <Sparkles className="w-3.5 h-3.5 text-gold" />
                <span>{loginRole === 'admin' ? 'Tier 1 Administration' : 'Caregiver Portal'}</span>
              </div>
            </div>

            <div className="space-y-2">
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-cream drop-shadow-sm flex flex-wrap items-baseline gap-2 font-sans">
                <span className="text-cream font-bold">স্মৃতি কুঞ্জ</span>
                <span className="text-terracotta/70 font-light">|</span>
                <span className="text-cream font-bold">Smriti Kunj</span>
              </h1>
              <p className="text-xs sm:text-sm text-amber-100/80 font-medium tracking-wide">
                Cognitive Assist & Dignified Memory Preservation Platform
              </p>
            </div>

            <div className="relative pl-4 border-l-stripe border-terracotta/60 py-1 max-w-xl">
              <p className="text-xs sm:text-sm md:text-[15px] text-cream/90 leading-relaxed font-normal">
                {loginRole === 'admin'
                  ? "Access the administrative console to provision staff credentials, oversee cross-caregiver rosters, and manage platform synchronization securely."
                  : "Every memory is sacred, and every voice carries timeless dignity. You are never defined by what fades, but by the love, wisdom, and heritage that will always remain. Smriti Kunj stands beside you and your family—treasuring your stories, honoring every moment, and keeping the light of your spirit alive."
                }
              </p>
            </div>

            <div className="pt-2 flex items-center gap-4 text-xs text-cream/60">
              <span className="flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-sage animate-pulse" />
                Encrypted Session: TLS 1.3
              </span>
              <span>•</span>
              <span>{loginRole === 'admin' ? 'Admin Verification Required' : 'Dedicated Care Support'}</span>
            </div>
          </div>

          {/* RIGHT COLUMN: Auth Card */}
          <div className="lg:col-span-5 flex justify-center lg:justify-end w-full">
            <div className="w-full max-w-md bg-surface/95 dark:bg-ink-soft/20 backdrop-blur-2xl border border-border dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-card relative overflow-hidden transition-colors duration-300 text-ink dark:text-cream">

              <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-terracotta via-gold to-terracotta" />

              <div className="mb-6 pt-1">
                <div className="flex items-center justify-between">
                  <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-ink dark:text-cream">
                    {step === 'credentials' ? (loginRole === 'admin' ? 'Sign In to Admin Center' : 'Sign In to Portal') : 'Two-Factor Verification'}
                  </h2>
                  <div className="w-8 h-8 rounded-card bg-terracotta/10 dark:bg-terracotta/20 flex items-center justify-center">
                    {step === 'credentials' ? (
                      <LogIn className="w-4 h-4 text-terracotta" />
                    ) : (
                      <ShieldCheck className="w-4 h-4 text-terracotta" />
                    )}
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

              {/* STEP 1: Credentials Form */}
              {step === 'credentials' && (
                <form onSubmit={handleCredentialsSubmit} noValidate className="space-y-4">

                  {/* ROLE SELECTION TOGGLE INJECTED HERE */}
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
                  {/* END ROLE TOGGLE */}

                  {/* Email Field */}
                  <div>
                    <label
                      htmlFor="email"
                      className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1.5"
                    >
                      Email Address
                    </label>
                    <input
                      id="email"
                      type="email"
                      autoComplete="email"
                      value={email}
                      onChange={(e) => {
                        setEmail(e.target.value);
                        if (errors.email) {
                          setErrors((prev) => ({ ...prev, email: undefined }));
                        }
                      }}
                      placeholder={loginRole === 'admin' ? "admin@smritikunj.org" : "caregiver@example.com"}
                      className={`w-full px-3.5 py-2.5 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${errors.email
                        ? 'border-status-urgent'
                        : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                        }`}
                      disabled={isSubmitting || loading}
                    />
                    {errors.email && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1.5 flex items-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                        {errors.email}
                      </p>
                    )}
                  </div>

                  {/* Password Field */}
                  <div>
                    <label
                      htmlFor="password"
                      className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1.5"
                    >
                      Password
                    </label>
                    <input
                      id="password"
                      type="password"
                      autoComplete="current-password"
                      value={password}
                      onChange={(e) => {
                        setPassword(e.target.value);
                        if (errors.password) {
                          setErrors((prev) => ({ ...prev, password: undefined }));
                        }
                      }}
                      placeholder="••••••••"
                      className={`w-full px-3.5 py-2.5 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${errors.password
                        ? 'border-status-urgent'
                        : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                        }`}
                      disabled={isSubmitting || loading}
                    />
                    {errors.password && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1.5 flex items-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                        {errors.password}
                      </p>
                    )}
                  </div>

                  {/* Submit Button */}
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

                  {/* Link to Register - Only shown for caregivers */}
                  {loginRole === 'caregiver' && (
                    <div className="text-center pt-3 mt-1 border-t border-border/60 dark:border-ink-soft/30">
                      <p className="text-xs text-ink-soft dark:text-cream/70">
                        Don't have an account?{' '}
                        <Link
                          to="/register"
                          className="text-terracotta hover:text-terracotta-dark font-semibold transition-colors focus:outline-none focus:underline"
                        >
                          Register
                        </Link>
                      </p>
                    </div>
                  )}
                </form>
              )}

              {/* STEP 2: OTP Verification Form */}
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

                  {/* 6-Digit OTP Input */}
                  <div className="py-2">
                    <OtpInput
                      value={otp}
                      onChange={(val) => {
                        setOtp(val);
                        if (errors.otp) {
                          setErrors((prev) => ({ ...prev, otp: undefined }));
                        }
                      }}
                      onComplete={() => { }}
                      disabled={isSubmitting || loading}
                      hasError={Boolean(errors.otp)}
                    />
                    {errors.otp && (
                      <p className="text-xs text-status-urgent dark:text-gold font-medium mt-2 flex items-center justify-center gap-1">
                        <AlertCircle className="w-3.5 h-3.5 text-status-urgent dark:text-gold" />
                        {errors.otp}
                      </p>
                    )}
                  </div>

                  {/* Verify Button */}
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

                  {/* Step 2 Footer Navigation & Resend */}
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
            </div>
          </div>

        </div>
      </main>

      {/* Traditional Decorative Gamusa Weave Motif Footer */}
      <footer className="relative z-10 w-full bg-ink/85 backdrop-blur-md py-4 border-t border-ink-soft/30 flex flex-col items-center justify-center space-y-2 transition-colors duration-300">
        <div className="w-full max-w-xl px-4 flex items-center justify-center gap-4 opacity-80">
          <div className="flex-1 h-[1px] bg-gradient-to-r from-transparent via-terracotta/40 to-gold/70" />
          <div className="flex items-center gap-1.5 text-gold text-xs font-semibold tracking-widest uppercase">
            ❖ ✦ ❖
          </div>
          <div className="flex-1 h-[1px] bg-gradient-to-l from-transparent via-terracotta/40 to-gold/70" />
        </div>

        {/* Gamusa Geometric Weave SVG Strip */}
        <div className="w-full max-w-xl px-4 overflow-hidden flex items-center justify-center">
          <svg className="w-full h-5 text-terracotta opacity-85" preserveAspectRatio="repeat" viewBox="0 0 480 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern id="gamusaPatternLogin" width="60" height="32" patternUnits="userSpaceOnUse">
                <line x1="0" y1="2" x2="60" y2="2" stroke="#B5562F" strokeWidth="1.5" strokeDasharray="3 2" />
                <line x1="0" y1="5" x2="60" y2="5" stroke="#C9962C" strokeWidth="0.75" />
                <line x1="0" y1="27" x2="60" y2="27" stroke="#C9962C" strokeWidth="0.75" />
                <line x1="0" y1="30" x2="60" y2="30" stroke="#B5562F" strokeWidth="1.5" strokeDasharray="3 2" />
                <path d="M15 16L30 6L45 16L30 26Z" fill="#B5562F" fillOpacity="0.2" stroke="#B5562F" strokeWidth="1.5" />
                <polygon points="30,10 40,16 30,22 20,16" fill="#C9962C" fillOpacity="0.25" stroke="#C9962C" strokeWidth="1" />
                <circle cx="30" cy="16" r="2.5" fill="#B5562F" />
                <path d="M0 16L15 6V10L6 16L15 22V26Z" fill="#B5562F" fillOpacity="0.8" />
                <path d="M60 16L45 6V10L54 16L45 22V26Z" fill="#B5562F" fillOpacity="0.8" />
              </pattern>
            </defs>
            <rect width="100%" height="32" fill="url(#gamusaPatternLogin)" />
          </svg>
        </div>

        <p className="text-[11px] text-cream/60 tracking-wider">
          স্মৃতি কুঞ্জ • Smriti Kunj • Cognitive Assist Platform
        </p>
      </footer>
    </div>
  );
};

export default Login;