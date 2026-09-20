import React, { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';

/**
 * Modal
 * 
 * Reusable accessible modal dialog wrapper rendered through a React Portal into document.body.
 * 
 * Features:
 * - Full-screen fixed overlay with dimmed, blurred backdrop (z-[100] above top controls and navbars)
 * - Trapped focus inside the modal with auto-focus on first focusable element
 * - Restores focus to trigger element on close
 * - Closes on Escape key or backdrop click (unless isSubmitting or preventClose is true)
 * - Locks background page scroll while open and cleanly restores on close
 * - Card centered vertically and horizontally with max-height: calc(100dvh - 2rem) and overflow-y-auto
 * - Respects mobile safe-area insets
 * - Respects prefers-reduced-motion
 */
export const Modal = ({
  isOpen,
  onClose,
  children,
  titleId = 'modal-title',
  descriptionId = 'modal-description',
  ariaLabel,
  maxWidth = 'max-w-md',
  isSubmitting = false,
  preventClose = false,
}) => {
  const overlayRef = useRef(null);
  const cardRef = useRef(null);
  const triggerElementRef = useRef(null);

  // Keep latest callbacks/flags in stable refs so effects don't depend on them
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;
  const isSubmittingRef = useRef(isSubmitting);
  isSubmittingRef.current = isSubmitting;
  const preventCloseRef = useRef(preventClose);
  preventCloseRef.current = preventClose;

  // Initial focus on card or first interactive element ONCE on open, and restore focus on close
  useEffect(() => {
    if (!isOpen) return;

    // Capture the element that had focus before opening the modal
    triggerElementRef.current = document.activeElement;

    const timer = setTimeout(() => {
      if (cardRef.current) {
        const firstInput =
          cardRef.current.querySelector('input:not([disabled]):not([type="hidden"])') ||
          cardRef.current.querySelector(
            'button:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
          );
        if (firstInput) {
          firstInput.focus();
        } else {
          cardRef.current.focus();
        }
      }
    }, 50);

    return () => {
      clearTimeout(timer);
      if (triggerElementRef.current && typeof triggerElementRef.current.focus === 'function') {
        triggerElementRef.current.focus();
      }
    };
  }, [isOpen]);

  // Lock body scroll while modal is active
  useEffect(() => {
    if (!isOpen) return;

    const originalOverflow = document.body.style.overflow;
    const originalPaddingRight = document.body.style.paddingRight;
    const scrollBarWidth = window.innerWidth - document.documentElement.clientWidth;

    document.body.style.overflow = 'hidden';
    if (scrollBarWidth > 0) {
      document.body.style.paddingRight = `${scrollBarWidth}px`;
    }

    return () => {
      document.body.style.overflow = originalOverflow;
      document.body.style.paddingRight = originalPaddingRight;
    };
  }, [isOpen]);

  // Escape key handler & focus trap - only mounted while isOpen is true
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e) => {
      // Escape key to close
      if (e.key === 'Escape') {
        if (!isSubmittingRef.current && !preventCloseRef.current) {
          e.preventDefault();
          onCloseRef.current?.();
        }
        return;
      }

      // Focus trap on Tab
      if (e.key === 'Tab' && cardRef.current) {
        const focusableElements = cardRef.current.querySelectorAll(
          'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
        );

        if (focusableElements.length === 0) return;

        const firstElement = focusableElements[0];
        const lastElement = focusableElements[focusableElements.length - 1];

        if (e.shiftKey) {
          if (document.activeElement === firstElement) {
            e.preventDefault();
            lastElement.focus();
          }
        } else {
          if (document.activeElement === lastElement) {
            e.preventDefault();
            firstElement.focus();
          }
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen]);

  if (!isOpen || typeof document === 'undefined') return null;

  const handleBackdropClick = (e) => {
    if (e.target === overlayRef.current && !isSubmittingRef.current && !preventCloseRef.current) {
      onCloseRef.current?.();
    }
  };

  return createPortal(
    <div
      ref={overlayRef}
      onClick={handleBackdropClick}
      className="fixed inset-0 z-[100] flex items-center justify-center p-3 sm:p-5 pb-[max(1rem,env(safe-area-inset-bottom))] bg-ink/60 dark:bg-ink/80 backdrop-blur-xs transition-opacity duration-200 animate-in fade-in"
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      aria-describedby={descriptionId}
      aria-label={ariaLabel}
    >
      <div
        ref={cardRef}
        tabIndex={-1}
        onClick={(e) => e.stopPropagation()}
        className={`w-full ${maxWidth} max-h-[calc(100dvh-2rem)] overflow-y-auto custom-scrollbar bg-surface dark:bg-ink border border-border/80 dark:border-ink-soft/40 rounded-card sm:rounded-2xl shadow-2xl p-5 sm:p-7 space-y-4 text-ink dark:text-cream relative transition-all duration-200 animate-in zoom-in-95 outline-none motion-reduce:animate-none`}
      >
        {children}
      </div>
    </div>,
    document.body
  );
};

export default Modal;
