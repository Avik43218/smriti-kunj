import React, { useState, useEffect, useCallback } from 'react';
import {
  KeyRound,
  X,
  Eye,
  EyeOff,
  AlertCircle,
  CheckCircle2,
  Check,
  Circle,
} from 'lucide-react';
import { Modal } from './Modal';
import { PasswordStrengthIndicator } from './PasswordStrengthIndicator';
import { changePassword as apiChangePassword } from '../services/authService';
import { useAuth } from '../context/AuthContext';

const I18N = {
  en: {
    title: 'Change Password',
    subtitle: "Choose a strong password you haven't used before",
    currentPasswordLabel: 'Current Password',
    currentPasswordPlaceholder: '••••••••••••',
    newPasswordLabel: 'New Password (min 10 characters)',
    newPasswordPlaceholder: '••••••••••••',
    confirmPasswordLabel: 'Confirm New Password',
    confirmPasswordPlaceholder: '••••••••••••',
    reqHeader: 'Password requirements:',
    reqLength: 'At least 10 characters',
    reqCasing: 'Uppercase & lowercase letters',
    reqNumber: 'At least one number (0-9)',
    reqSymbol: 'At least one symbol (!@#$%...)',
    errCurrentRequired: 'Current password is required',
    errMin10: 'New password must be at least 10 characters long',
    errDiffFromCurrent: 'Must differ from your current password',
    errMismatch: 'Passwords do not match',
    errFallback: 'Failed to update password. Please check your credentials.',
    btnCancel: 'Cancel',
    btnUpdate: 'Update Password',
    btnUpdating: 'Updating...',
    msgSuccess: 'Password changed successfully! Session updated.',
    showPass: 'Show password',
    hidePass: 'Hide password',
    closeDialog: 'Close dialog',
  },
  as: {
    title: 'পাছৱৰ্ড সলনি কৰক',
    subtitle: 'পূৰ্বে ব্যৱহাৰ নকৰা এটা শক্তিশালী পাছৱৰ্ড বাছনি কৰক',
    currentPasswordLabel: 'বৰ্তমানৰ পাছৱৰ্ড',
    currentPasswordPlaceholder: '••••••••••••',
    newPasswordLabel: 'নতুন পাছৱৰ্ড (নূন্যতম ১০ টা বৰ্ণ)',
    newPasswordPlaceholder: '••••••••••••',
    confirmPasswordLabel: 'নতুন পাছৱৰ্ড নিশ্চিত কৰক',
    confirmPasswordPlaceholder: '••••••••••••',
    reqHeader: 'পাছৱৰ্ডৰ প্ৰয়োজনীয়তা:',
    reqLength: 'নূন্যতম ১০ টা বৰ্ণ',
    reqCasing: 'ডাঙৰ আৰু সৰু ফলাৰ বৰ্ণ (A-Z, a-z)',
    reqNumber: 'নূন্যতম এটা সংখ্যা (০-৯)',
    reqSymbol: 'নূন্যতম এটা বিশেষ চিহ্ন (!@#$%...)',
    errCurrentRequired: 'বৰ্তমানৰ পাছৱৰ্ড প্ৰয়োজন',
    errMin10: 'পাছৱৰ্ড নূন্যতম ১০ টা বৰ্ণৰ হ’ব লাগিব',
    errDiffFromCurrent: 'বৰ্তমানৰ পাছৱৰ্ডৰ সৈতে একে হ’ব নোৱাৰে',
    errMismatch: 'পাছৱৰ্ড দুটাৰ মিল নাই',
    errFallback: 'পাছৱৰ্ড সলনি কৰিব পৰা নগ’ল। অনুগ্ৰহ কৰি পুনৰ চেষ্টা কৰক।',
    btnCancel: 'বাতিল কৰক',
    btnUpdate: 'পাছৱৰ্ড আপডেট কৰক',
    btnUpdating: 'আপডেট হৈ আছে...',
    msgSuccess: 'পাছৱৰ্ড সফলতাৰে সলনি কৰা হ’ল!',
    showPass: 'পাছৱৰ্ড দেখুৱাওক',
    hidePass: 'পাছৱৰ্ড লুকুৱাওক',
    closeDialog: 'ডায়লগ বন্ধ কৰক',
  },
  bn: {
    title: 'পাসওয়ার্ড পরিবর্তন করুন',
    subtitle: 'পূর্বে ব্যবহার করেননি এমন একটি শক্তিশালী পাসওয়ার্ড বেছে নিন',
    currentPasswordLabel: 'বর্তমান পাসওয়ার্ড',
    currentPasswordPlaceholder: '••••••••••••',
    newPasswordLabel: 'নতুন পাসওয়ার্ড (নূন্যতম ১০ টি অক্ষর)',
    newPasswordPlaceholder: '••••••••••••',
    confirmPasswordLabel: 'নতুন পাসওয়ার্ড নিশ্চিত করুন',
    confirmPasswordPlaceholder: '••••••••••••',
    reqHeader: 'পাসওয়ার্ডের প্রয়োজনীয়তা:',
    reqLength: 'কমপক্ষে ১০ টি অক্ষর',
    reqCasing: 'বড় ও ছোট হাতের অক্ষর (A-Z, a-z)',
    reqNumber: 'কমপক্ষে একটি সংখ্যা (০-৯)',
    reqSymbol: 'কমপক্ষে একটি প্রতীক (!@#$%...)',
    errCurrentRequired: 'বর্তমান পাসওয়ার্ড প্রয়োজন',
    errMin10: 'পাসওয়ার্ড কমপক্ষে ১০ টি অক্ষরের হতে হবে',
    errDiffFromCurrent: 'বর্তমান পাসওয়ার্ড থেকে ভিন্ন হতে হবে',
    errMismatch: 'পাসওয়ার্ড দুটি মেলেনি',
    errFallback: 'পাসওয়ার্ড পরিবর্তন ব্যর্থ হয়েছে। অনুগ্রহ করে পুনরায় চেষ্টা করুন।',
    btnCancel: 'বাতিল করুন',
    btnUpdate: 'পাসওয়ার্ড পরিবর্তন করুন',
    btnUpdating: 'পরিবর্তন হচ্ছে...',
    msgSuccess: 'পাসওয়ার্ড সফলভাবে পরিবর্তন করা হয়েছে!',
    showPass: 'পাসওয়ার্ড দেখুন',
    hidePass: 'পাসওয়ার্ড লুকান',
    closeDialog: 'ডায়ালগ বন্ধ করুন',
  },
};

export const ChangePasswordModal = ({ isOpen, onClose }) => {
  const { updateUserData, setSession, caregiver } = useAuth();

  const [currentLanguage, setCurrentLanguage] = useState(() => {
    try {
      return localStorage.getItem('caregiver_language') || 'en';
    } catch {
      return 'en';
    }
  });

  useEffect(() => {
    const handleLangChange = (e) => {
      const newLang = e?.detail?.language || localStorage.getItem('caregiver_language') || 'en';
      setCurrentLanguage(newLang);
    };
    window.addEventListener('languagechange', handleLangChange);
    return () => window.removeEventListener('languagechange', handleLangChange);
  }, []);

  const t = I18N[currentLanguage] || I18N.en;

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [showCurrent, setShowCurrent] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);

  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Live checklist evaluations
  const reqChecks = {
    length: newPassword.length >= 10,
    casing: /[A-Z]/.test(newPassword) && /[a-z]/.test(newPassword),
    number: /[0-9]/.test(newPassword),
    symbol: /[^A-Za-z0-9]/.test(newPassword),
  };

  const isFormValid =
    currentPassword.trim().length > 0 &&
    reqChecks.length &&
    newPassword !== currentPassword &&
    newPassword === confirmPassword;

  const handleClose = useCallback(() => {
    if (isSubmitting) return;
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setShowCurrent(false);
    setShowNew(false);
    setShowConfirm(false);
    setErrors({});
    setSubmitError('');
    setSuccessMessage('');
    onClose();
  }, [isSubmitting, onClose]);

  const validate = () => {
    const errs = {};
    if (!currentPassword.trim()) {
      errs.currentPassword = t.errCurrentRequired;
    }
    if (!newPassword || newPassword.length < 10) {
      errs.newPassword = t.errMin10;
    } else if (currentPassword && newPassword === currentPassword) {
      errs.newPassword = t.errDiffFromCurrent;
    }

    if (!confirmPassword) {
      errs.confirmPassword = t.errMismatch;
    } else if (newPassword !== confirmPassword) {
      errs.confirmPassword = t.errMismatch;
    }

    setErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitError('');
    setSuccessMessage('');

    if (!validate()) return;

    setIsSubmitting(true);
    try {
      const res = await apiChangePassword(currentPassword, newPassword);

      if (updateUserData) {
        updateUserData({ must_change_password: false });
      }
      if (res?.token && setSession) {
        setSession(res.token, { ...(caregiver || {}), must_change_password: false });
      }

      setSuccessMessage(t.msgSuccess);
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setErrors({});

      setTimeout(() => {
        handleClose();
      }, 1400);
    } catch (err) {
      setSubmitError(err.message || t.errFallback);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={handleClose}
      titleId="change-password-title"
      descriptionId="change-password-desc"
      ariaLabel={t.title}
      isSubmitting={isSubmitting}
      maxWidth="max-w-md"
    >
      {/* Subtle brand gradient accent bar */}
      <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-terracotta via-gold to-terracotta" />

      {/* Header */}
      <div className="flex items-start justify-between border-b border-border/70 dark:border-ink-soft/40 pb-3.5 pt-1">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-terracotta/15 dark:bg-terracotta/25 flex items-center justify-center text-terracotta shrink-0 border border-terracotta/20">
            <KeyRound className="w-5 h-5" aria-hidden="true" />
          </div>
          <div>
            <h3
              id="change-password-title"
              className="text-base sm:text-lg font-bold text-ink dark:text-cream leading-tight"
            >
              {t.title}
            </h3>
            <p
              id="change-password-desc"
              className="text-xs text-ink-soft dark:text-cream/70 mt-0.5 leading-snug"
            >
              {t.subtitle}
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={handleClose}
          disabled={isSubmitting}
          className="min-w-[44px] min-h-[44px] flex items-center justify-center text-ink-soft hover:text-ink dark:text-cream/70 dark:hover:text-cream transition-colors rounded-lg hover:bg-cream dark:hover:bg-ink-soft/30 focus:outline-none focus-visible:ring-2 focus-visible:ring-terracotta"
          aria-label={t.closeDialog}
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      {/* Error Alert Banner */}
      {submitError && (
        <div
          role="alert"
          className="p-3 rounded-lg bg-status-urgent/10 dark:bg-gold/15 border border-status-urgent/30 dark:border-gold/30 text-status-urgent dark:text-gold text-xs flex items-center gap-2.5 animate-in fade-in"
        >
          <AlertCircle className="w-4 h-4 shrink-0" aria-hidden="true" />
          <span className="font-medium">{submitError}</span>
        </div>
      )}

      {/* Success Alert Banner */}
      {successMessage && (
        <div
          role="status"
          className="p-3 rounded-lg bg-sage/15 border border-sage/40 text-ink dark:text-cream text-xs flex items-center gap-2.5 animate-in fade-in"
        >
          <CheckCircle2 className="w-4 h-4 text-sage shrink-0" aria-hidden="true" />
          <span className="font-medium">{successMessage}</span>
        </div>
      )}

      {/* Form */}
      <form onSubmit={handleSubmit} className="space-y-4 text-xs sm:text-sm">
        {/* Field 1: Current Password */}
        <div>
          <label
            htmlFor="change-current-password"
            className="block text-xs font-semibold uppercase tracking-wider text-ink dark:text-cream/90 mb-1"
          >
            {t.currentPasswordLabel}
          </label>
          <div className="relative">
            <input
              id="change-current-password"
              name="current-password"
              type={showCurrent ? 'text' : 'password'}
              autoComplete="current-password"
              required
              value={currentPassword}
              onChange={(e) => {
                setCurrentPassword(e.target.value);
                if (errors.currentPassword) {
                  setErrors((prev) => ({ ...prev, currentPassword: undefined }));
                }
              }}
              placeholder={t.currentPasswordPlaceholder}
              className={`w-full pl-3.5 pr-12 py-2.5 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors ${
                errors.currentPassword
                  ? 'border-status-urgent dark:border-status-urgent'
                  : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
              }`}
              disabled={isSubmitting}
            />
            <button
              type="button"
              onClick={() => setShowCurrent((prev) => !prev)}
              className="absolute right-1 top-1/2 -translate-y-1/2 min-w-[44px] min-h-[44px] flex items-center justify-center text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta rounded"
              aria-label={showCurrent ? t.hidePass : t.showPass}
            >
              {showCurrent ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
          {errors.currentPassword && (
            <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
              <AlertCircle className="w-3.5 h-3.5 shrink-0" aria-hidden="true" />
              <span>{errors.currentPassword}</span>
            </p>
          )}
        </div>

        {/* Field 2: New Password */}
        <div>
          <label
            htmlFor="change-new-password"
            className="block text-xs font-semibold uppercase tracking-wider text-ink dark:text-cream/90 mb-1"
          >
            {t.newPasswordLabel}
          </label>
          <div className="relative">
            <input
              id="change-new-password"
              name="new-password"
              type={showNew ? 'text' : 'password'}
              autoComplete="new-password"
              required
              value={newPassword}
              onChange={(e) => {
                setNewPassword(e.target.value);
                if (errors.newPassword) {
                  setErrors((prev) => ({ ...prev, newPassword: undefined }));
                }
              }}
              placeholder={t.newPasswordPlaceholder}
              className={`w-full pl-3.5 pr-12 py-2.5 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors ${
                errors.newPassword
                  ? 'border-status-urgent dark:border-status-urgent'
                  : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
              }`}
              disabled={isSubmitting}
            />
            <button
              type="button"
              onClick={() => setShowNew((prev) => !prev)}
              className="absolute right-1 top-1/2 -translate-y-1/2 min-w-[44px] min-h-[44px] flex items-center justify-center text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta rounded"
              aria-label={showNew ? t.hidePass : t.showPass}
            >
              {showNew ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
          {errors.newPassword && (
            <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
              <AlertCircle className="w-3.5 h-3.5 shrink-0" aria-hidden="true" />
              <span>{errors.newPassword}</span>
            </p>
          )}

          {/* Password Strength Indicator */}
          <PasswordStrengthIndicator password={newPassword} />

          {/* Live Requirements Checklist */}
          <div className="mt-2.5 p-2.5 rounded-lg bg-cream/50 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 space-y-1 text-[11px]">
            <span className="font-semibold text-ink-soft dark:text-cream/75 block mb-1">
              {t.reqHeader}
            </span>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-1">
              <div
                className={`flex items-center gap-1.5 ${
                  reqChecks.length
                    ? 'text-sage font-medium'
                    : 'text-ink-soft/70 dark:text-cream/50'
                }`}
              >
                {reqChecks.length ? (
                  <Check className="w-3.5 h-3.5 text-sage shrink-0" />
                ) : (
                  <Circle className="w-3 h-3 shrink-0 opacity-40" />
                )}
                <span>{t.reqLength}</span>
              </div>
              <div
                className={`flex items-center gap-1.5 ${
                  reqChecks.casing
                    ? 'text-sage font-medium'
                    : 'text-ink-soft/70 dark:text-cream/50'
                }`}
              >
                {reqChecks.casing ? (
                  <Check className="w-3.5 h-3.5 text-sage shrink-0" />
                ) : (
                  <Circle className="w-3 h-3 shrink-0 opacity-40" />
                )}
                <span>{t.reqCasing}</span>
              </div>
              <div
                className={`flex items-center gap-1.5 ${
                  reqChecks.number
                    ? 'text-sage font-medium'
                    : 'text-ink-soft/70 dark:text-cream/50'
                }`}
              >
                {reqChecks.number ? (
                  <Check className="w-3.5 h-3.5 text-sage shrink-0" />
                ) : (
                  <Circle className="w-3 h-3 shrink-0 opacity-40" />
                )}
                <span>{t.reqNumber}</span>
              </div>
              <div
                className={`flex items-center gap-1.5 ${
                  reqChecks.symbol
                    ? 'text-sage font-medium'
                    : 'text-ink-soft/70 dark:text-cream/50'
                }`}
              >
                {reqChecks.symbol ? (
                  <Check className="w-3.5 h-3.5 text-sage shrink-0" />
                ) : (
                  <Circle className="w-3 h-3 shrink-0 opacity-40" />
                )}
                <span>{t.reqSymbol}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Field 3: Confirm New Password */}
        <div>
          <label
            htmlFor="change-confirm-password"
            className="block text-xs font-semibold uppercase tracking-wider text-ink dark:text-cream/90 mb-1"
          >
            {t.confirmPasswordLabel}
          </label>
          <div className="relative">
            <input
              id="change-confirm-password"
              name="confirm-password"
              type={showConfirm ? 'text' : 'password'}
              autoComplete="new-password"
              required
              value={confirmPassword}
              onChange={(e) => {
                setConfirmPassword(e.target.value);
                if (errors.confirmPassword) {
                  setErrors((prev) => ({ ...prev, confirmPassword: undefined }));
                }
              }}
              placeholder={t.confirmPasswordPlaceholder}
              className={`w-full pl-3.5 pr-12 py-2.5 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors ${
                errors.confirmPassword
                  ? 'border-status-urgent dark:border-status-urgent'
                  : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
              }`}
              disabled={isSubmitting}
            />
            <button
              type="button"
              onClick={() => setShowConfirm((prev) => !prev)}
              className="absolute right-1 top-1/2 -translate-y-1/2 min-w-[44px] min-h-[44px] flex items-center justify-center text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta rounded"
              aria-label={showConfirm ? t.hidePass : t.showPass}
            >
              {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
          {errors.confirmPassword && (
            <p className="text-xs text-status-urgent dark:text-gold font-medium mt-1 flex items-center gap-1">
              <AlertCircle className="w-3.5 h-3.5 shrink-0" aria-hidden="true" />
              <span>{errors.confirmPassword}</span>
            </p>
          )}
        </div>

        {/* Footer Actions */}
        <div className="flex flex-col-reverse sm:flex-row sm:items-center sm:justify-end gap-2.5 pt-3.5 border-t border-border/70 dark:border-ink-soft/40">
          <button
            type="button"
            onClick={handleClose}
            disabled={isSubmitting}
            className="w-full sm:w-auto min-h-[44px] px-5 py-2.5 rounded-full border border-border/80 dark:border-ink-soft/40 text-xs font-semibold text-ink-soft dark:text-cream/80 hover:bg-cream dark:hover:bg-ink-soft/30 hover:text-ink dark:hover:text-cream transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-terracotta text-center"
          >
            {t.btnCancel}
          </button>
          <button
            type="submit"
            disabled={isSubmitting || !isFormValid}
            className="w-full sm:w-auto min-h-[44px] px-6 py-2.5 rounded-full bg-terracotta hover:bg-terracotta-dark text-cream text-xs font-bold shadow-sm transition-all focus:outline-none focus-visible:ring-2 focus-visible:ring-terracotta/50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 active:scale-95 disabled:active:scale-100 text-center"
          >
            {isSubmitting ? (
              <>
                <div
                  className="w-4 h-4 border-2 border-cream border-t-transparent rounded-full animate-spin"
                  aria-hidden="true"
                />
                <span>{t.btnUpdating}</span>
              </>
            ) : (
              <span>{t.btnUpdate}</span>
            )}
          </button>
        </div>
      </form>
    </Modal>
  );
};

export default ChangePasswordModal;
