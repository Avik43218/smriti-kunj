import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { register } from '../services/authService';
import { LanguageSelector } from '../components/LanguageSelector';
import { LiveBackgroundShader } from '../components/LiveBackgroundShader';
import { PasswordStrengthIndicator } from '../components/PasswordStrengthIndicator';
import {
  HeartHandshake,
  UserPlus,
  AlertCircle,
  Check,
  X,
  Sparkles,
  Sun,
  Moon,
} from 'lucide-react';
import { Footer } from '../components/Footer';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const Register = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();
  const { theme, toggleTheme } = useTheme();

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      navigate('/dashboard', { replace: true });
    }
  }, [isAuthenticated, navigate]);

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
      // 1. Forge the caregiver account in the database 🚀
      await register(name.trim(), email.trim(), password);

      // 2. Kick them over to the login page to do the real 2FA flow! 🛡️
      navigate('/login', { replace: true });
      
    } catch (err) {
      setSubmitError(err?.message || 'Registration failed. Please check your information and try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen w-full relative flex flex-col justify-between overflow-x-hidden font-sans select-none bg-cream dark:bg-ink text-ink dark:text-cream transition-colors duration-300">
      {/* Live Animated Brahmaputra Silk Background Shader */}
      <LiveBackgroundShader />

      {/* Persistent Fixed Top Header: Consistent dark glassmorphic style in both light and dark mode */}
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

          {/* Top Controls Cluster (Language & Theme Toggle): Dark style in both light and dark mode */}
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

      {/* Main 2-Column Hero & Auth Container with Dedicated Top Clearance */}
      <main className="relative z-10 flex-1 flex items-center justify-center w-full max-w-7xl mx-auto px-6 sm:px-10 lg:px-16 pt-24 sm:pt-28 pb-12">
        <div className="w-full grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-14 items-center">
          
          {/* LEFT COLUMN: Logo (hearthandshake), App Name, and Heritage Motto */}
          <div className="lg:col-span-7 flex flex-col items-start text-left space-y-6">
            
            {/* Pill & Icon Header */}
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-12 h-12 rounded-card bg-terracotta/20 border border-terracotta/40 backdrop-blur-md shadow-card">
                <HeartHandshake className="w-6 h-6 text-terracotta" />
              </div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-surface/10 border border-border/30 backdrop-blur-md text-gold text-xs font-semibold tracking-wider uppercase">
                <Sparkles className="w-3.5 h-3.5 text-gold" />
                <span>Caregiver Portal</span>
              </div>
            </div>

            {/* Typography: App Name font size (text-2xl sm:text-3xl) */}
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

            {/* Poetic & Professional Tagline */}
            <div className="relative pl-4 border-l-stripe border-terracotta/60 py-1 max-w-xl">
              <p className="text-xs sm:text-sm md:text-[15px] text-cream/90 leading-relaxed font-normal">
                Every memory is sacred, and every voice carries timeless dignity. You are never defined by what fades, but by the love, wisdom, and heritage that will always remain. Smriti Kunj stands beside you and your family—treasuring your stories, honoring every moment, and keeping the light of your spirit alive.
              </p>
            </div>

            {/* Cultural subtle status tag */}
            <div className="pt-2 flex items-center gap-4 text-xs text-cream/60">
              <span className="flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-sage animate-pulse" />
                Caregiver Network
              </span>
              <span>•</span>
              <span>Encrypted Credentials</span>
            </div>
          </div>

          {/* RIGHT COLUMN: Registration Card */}
          <div className="lg:col-span-5 flex justify-center lg:justify-end w-full">
            <div className="w-full max-w-md bg-surface/95 dark:bg-ink-soft/20 backdrop-blur-2xl border border-border dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-card relative overflow-hidden transition-colors duration-300 text-ink dark:text-cream">
              
              {/* Subtle Heritage Top Trim */}
              <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-terracotta via-gold to-terracotta" />

              {/* Card Title */}
              <div className="mb-5 pt-1">
                <div className="flex items-center justify-between">
                  <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-ink dark:text-cream">
                    Create Account
                  </h2>
                  <div className="w-8 h-8 rounded-card bg-terracotta/10 dark:bg-terracotta/20 flex items-center justify-center">
                    <UserPlus className="w-4 h-4 text-terracotta" />
                  </div>
                </div>
                <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-1">
                  Register as an accredited caregiver to manage patient care
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
                    htmlFor="name"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Full Name
                  </label>
                  <input
                    id="name"
                    type="text"
                    autoComplete="name"
                    value={name}
                    onChange={(e) => {
                      setName(e.target.value);
                      if (errors.name) {
                        setErrors((prev) => ({ ...prev, name: undefined }));
                      }
                    }}
                    placeholder="Dr. Sarah Jenkins"
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
                    htmlFor="email"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
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

                {/* Password Field */}
                <div>
                  <label
                    htmlFor="password"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Password
                  </label>
                  <input
                    id="password"
                    type="password"
                    autoComplete="new-password"
                    value={password}
                    onChange={(e) => {
                      setPassword(e.target.value);
                      if (errors.password) {
                        setErrors((prev) => ({ ...prev, password: undefined }));
                      }
                    }}
                    placeholder="Minimum 8 characters"
                    className={`w-full px-3.5 py-2 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                      errors.password
                        ? 'border-status-urgent dark:border-gold/70'
                        : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                    }`}
                    disabled={isSubmitting}
                  />
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
                    htmlFor="confirmPassword"
                    className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1"
                  >
                    Confirm Password
                  </label>
                  <input
                    id="confirmPassword"
                    type="password"
                    autoComplete="new-password"
                    value={confirmPassword}
                    onChange={(e) => {
                      setConfirmPassword(e.target.value);
                      if (errors.confirmPassword) {
                        setErrors((prev) => ({ ...prev, confirmPassword: undefined }));
                      }
                    }}
                    placeholder="Re-enter your password"
                    className={`w-full px-3.5 py-2 bg-cream/70 dark:bg-ink-soft/20 border rounded-lg text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors ${
                      errors.confirmPassword
                        ? 'border-status-urgent dark:border-gold/70'
                        : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                    }`}
                    disabled={isSubmitting}
                  />

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
                        <span>Creating account...</span>
                      </>
                    ) : (
                      <>
                        <UserPlus className="w-4 h-4" />
                        <span>Create Account</span>
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

      {/* Site Identity Line Design Footer */}
      <Footer variant="dark" />
    </div>
  );
};

export default Register;
