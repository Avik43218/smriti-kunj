import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { TopControls } from '../components/TopControls';
import {
  HeartHandshake,
  LogIn,
  AlertCircle,
  ShieldCheck,
  ArrowLeft,
} from 'lucide-react';
import { OtpInput } from '../components/OtpInput';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const Login = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { login, requestOtp, verifyOtp, isAuthenticated, loading } = useAuth();

  // Multi-step authentication state: 'credentials' | 'otp'
  const [step, setStep] = useState('credentials');

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
      // Step 1: Validate credentials and trigger OTP request
      await login(email.trim(), password);
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
    <div className="min-h-screen bg-cream dark:bg-ink text-ink dark:text-cream flex flex-col justify-center items-center p-4 font-sans relative transition-colors duration-200">
      {/* Top-Right Controls: Theme Toggle Only (no settings) */}
      <TopControls showSettings={false} />

      <div className="w-full max-w-md my-auto pt-6 pb-8">
        {/* Header Branding with Smriti Kunj */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-card bg-surface dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 shadow-xs mb-3">
            <HeartHandshake className="w-8 h-8 text-terracotta" />
          </div>
          
          <div className="space-y-1">
            <div className="inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full bg-cream dark:bg-ink-soft/40 border border-border/80 dark:border-ink-soft/40 text-terracotta text-[11px] font-semibold uppercase tracking-wider mb-1">
              Caregiver Portal
            </div>
            <h1 className="text-2xl sm:text-3xl font-bold text-ink dark:text-cream tracking-tight font-sans">
              Smriti Kunj
            </h1>
            <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-1 max-w-sm mx-auto leading-relaxed">
              {step === 'credentials'
                ? 'Cognitive Assist Platform • Sign in to your caregiver dashboard'
                : 'Two-factor authentication • Enter your verification code'}
            </p>
          </div>
        </div>

        {/* Login Card */}
        <div className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-sm transition-colors">
          {submitError && (
            <div className="mb-5 p-3.5 bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-lg flex items-start gap-2.5">
              <AlertCircle className="w-5 h-5 text-terracotta shrink-0 mt-0.5" />
              <p className="text-xs sm:text-sm text-ink dark:text-cream font-medium leading-relaxed">
                {submitError}
              </p>
            </div>
          )}

          {resendNotice && (
            <div className="mb-5 p-3.5 bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-lg flex items-start gap-2.5">
              <ShieldCheck className="w-5 h-5 text-sage shrink-0 mt-0.5" />
              <p className="text-xs sm:text-sm text-ink dark:text-cream font-medium leading-relaxed">
                {resendNotice}
              </p>
            </div>
          )}

          {/* STEP 1: Credentials Form */}
          {step === 'credentials' && (
            <form onSubmit={handleCredentialsSubmit} noValidate className="space-y-4">
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
                  placeholder="caregiver@example.com"
                  className={`w-full px-3.5 py-2.5 bg-cream dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                    errors.email
                      ? 'border-terracotta'
                      : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  disabled={isSubmitting || loading}
                />
                {errors.email && (
                  <p className="text-xs text-terracotta font-medium mt-1.5 flex items-center gap-1">
                    <AlertCircle className="w-3.5 h-3.5" />
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
                  className={`w-full px-3.5 py-2.5 bg-cream dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                    errors.password
                      ? 'border-terracotta'
                      : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  disabled={isSubmitting || loading}
                />
                {errors.password && (
                  <p className="text-xs text-terracotta font-medium mt-1.5 flex items-center gap-1">
                    <AlertCircle className="w-3.5 h-3.5" />
                    {errors.password}
                  </p>
                )}
              </div>

              {/* Submit Action */}
              <div className="pt-2">
                <button
                  type="submit"
                  disabled={isSubmitting || loading}
                  className="w-full py-3 px-4 bg-terracotta hover:bg-terracotta-dark text-surface font-medium text-sm rounded-lg transition-colors flex items-center justify-center gap-2 focus:outline-none focus:ring-2 focus:ring-terracotta/40 disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
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

              {/* Link to Register */}
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
                  onComplete={() => {
                    // Optional auto-submit
                  }}
                  disabled={isSubmitting || loading}
                  hasError={Boolean(errors.otp)}
                />
                {errors.otp && (
                  <p className="text-xs text-terracotta font-medium mt-2 flex items-center justify-center gap-1">
                    <AlertCircle className="w-3.5 h-3.5" />
                    {errors.otp}
                  </p>
                )}
              </div>

              {/* Verify Button */}
              <div>
                <button
                  type="submit"
                  disabled={isSubmitting || loading || otp.length !== 6}
                  className="w-full py-3 px-4 bg-terracotta hover:bg-terracotta-dark text-surface font-medium text-sm rounded-lg transition-colors flex items-center justify-center gap-2 focus:outline-none focus:ring-2 focus:ring-terracotta/40 disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
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

        {/* Footer info with Smriti Kunj branding */}
        <p className="text-center text-xs text-ink-soft dark:text-cream/60 mt-6 font-sans">
          Smriti Kunj • Cognitive Assist Platform
        </p>
      </div>
    </div>
  );
};

export default Login;
