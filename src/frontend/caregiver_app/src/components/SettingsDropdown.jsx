import React, { useState, useEffect, useRef } from 'react';
import {
  Shield,
  FileText,
  X,
  ExternalLink,
  ArrowLeft,
} from 'lucide-react';

const APP_VERSION = 'v0.1.0';

export const SettingsDropdown = ({ isOpen, onClose, onBack }) => {
  const dropdownRef = useRef(null);
  const [activeModal, setActiveModal] = useState(null); // 'privacy' | 'terms' | null

  // Handle outside clicks to close dropdown
  useEffect(() => {
    const handleOutsideClick = (e) => {
      // If clicking the settings toggle trigger button, let the button's own click handler toggle it
      const isClickOnTrigger = e.target.closest && e.target.closest('button[aria-label="Settings menu"]');
      if (dropdownRef.current && !dropdownRef.current.contains(e.target) && !isClickOnTrigger) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleOutsideClick);
    }
    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
    };
  }, [isOpen, onClose]);

  // Handle Escape key to close modal or dropdown
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        if (activeModal) {
          setActiveModal(null);
        } else if (isOpen) {
          onClose();
        }
      }
    };
    if (isOpen || activeModal) {
      document.addEventListener('keydown', handleKeyDown);
    }
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, activeModal, onClose]);

  if (!isOpen && !activeModal) return null;

  return (
    <>
      {/* Standard Relative Dropdown Popover */}
      {isOpen && (
        <div
          ref={dropdownRef}
          className="absolute right-0 top-full mt-2 w-64 bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 rounded-card shadow-card p-3 z-50 transition-all font-sans animate-in fade-in zoom-in-95 duration-150"
        >
          {/* Header Title with Back Button */}
          <div className="px-1 pt-0.5 pb-2 flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 mb-2">
            <div className="flex items-center gap-1.5">
              {onBack && (
                <button
                  type="button"
                  onClick={onBack}
                  aria-label="Back to profile menu"
                  className="p-1 -ml-1 rounded-full text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/20 transition-colors"
                >
                  <ArrowLeft className="w-3.5 h-3.5" />
                </button>
              )}
              <span className="text-xs font-bold uppercase tracking-wider text-ink dark:text-cream">
                Preferences
              </span>
            </div>
            <span className="text-[10px] text-ink-soft dark:text-cream/50 font-medium">
              Smriti Kunj
            </span>
          </div>

          {/* Menu Items */}
          <div className="space-y-0.5">
            {/* 1. Privacy Policy Link */}
            <button
              type="button"
              onClick={() => setActiveModal('privacy')}
              className="w-full text-left px-2.5 py-1.5 rounded-lg text-xs text-ink dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/20 flex items-center justify-between transition-colors group"
            >
              <span className="flex items-center gap-2">
                <Shield className="w-3.5 h-3.5 text-ink-soft dark:text-cream/70 group-hover:text-terracotta transition-colors" />
                <span>Privacy Policy</span>
              </span>
              <ExternalLink className="w-3 h-3 text-ink-soft/50 dark:text-cream/40" />
            </button>

            {/* 2. Terms of Service Link */}
            <button
              type="button"
              onClick={() => setActiveModal('terms')}
              className="w-full text-left px-2.5 py-1.5 rounded-lg text-xs text-ink dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/20 flex items-center justify-between transition-colors group"
            >
              <span className="flex items-center gap-2">
                <FileText className="w-3.5 h-3.5 text-ink-soft dark:text-cream/70 group-hover:text-terracotta transition-colors" />
                <span>Terms of Service</span>
              </span>
              <ExternalLink className="w-3 h-3 text-ink-soft/50 dark:text-cream/40" />
            </button>

            {/* 3. Version Info */}
            <div className="px-2.5 py-1.5 flex items-center justify-between text-xs text-ink-soft dark:text-cream/50">
              <span>App Version</span>
              <span className="font-mono text-xs font-semibold text-ink dark:text-cream">{APP_VERSION}</span>
            </div>
          </div>
        </div>
      )}

      {/* Modal Dialog for Privacy Policy / Terms of Service */}
      {activeModal && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-ink/50 dark:bg-ink/80 backdrop-blur-xs">
          <div className="w-full max-w-md bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 rounded-card p-5 sm:p-6 shadow-card relative animate-in fade-in zoom-in duration-150 font-sans">
            <div className="flex items-center justify-between pb-3 border-b border-border dark:border-ink-soft/30">
              <div>
                <h3 className="text-base font-bold text-ink dark:text-cream">
                  {activeModal === 'privacy' ? 'Privacy Policy' : 'Terms of Service'}
                </h3>
                <p className="text-[11px] text-ink-soft dark:text-cream/60">
                  Smriti Kunj • Cognitive Assist Platform
                </p>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1 rounded-full text-ink-soft dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/20 transition-colors"
                aria-label="Close document modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="py-4 text-xs sm:text-sm text-ink-soft dark:text-cream/80 space-y-2.5 leading-relaxed">
              <p>
                {activeModal === 'privacy'
                  ? 'The Smriti Kunj Privacy Policy outlines how caregiver profiles, patient metrics, and longitudinal clinical data are secured using strict role-based access control and encrypted storage.'
                  : 'The Smriti Kunj Terms of Service govern clinical oversight, device pairing protocols, emergency alert responsibilities, and caregiver delegation.'}
              </p>
              <div className="p-2.5 bg-cream dark:bg-ink-soft/20 border border-border dark:border-ink-soft/30 rounded-lg text-xs">
                <span className="font-semibold text-ink dark:text-cream">Note:</span> Full clinical and legal compliance documentation is active for v0.1.
              </div>
            </div>

            <div className="pt-2 flex justify-end">
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="px-3.5 py-1.5 bg-terracotta hover:bg-terracotta-dark text-surface text-xs font-medium rounded-lg transition-colors shadow-xs"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default SettingsDropdown;
