import React, { useRef, useEffect } from 'react';

/**
 * OtpInput Component
 * 
 * 6-digit segmented numeric input using design system tokens.
 * Supports light and dark mode with terracotta focus states.
 * 
 * @param {string} value - The 6-digit OTP string
 * @param {function} onChange - Callback receiving the updated OTP string
 * @param {function} [onComplete] - Callback fired when all 6 digits are entered
 * @param {boolean} [disabled] - Whether inputs are disabled
 * @param {boolean} [hasError] - Error indicator for styling borders
 */
export const OtpInput = ({
  value = '',
  onChange,
  onComplete,
  disabled = false,
  hasError = false,
}) => {
  const inputRefs = useRef([]);

  // Ensure digits array always has 6 items
  const digits = Array.from({ length: 6 }, (_, i) => value[i] || '');

  useEffect(() => {
    // Auto focus first input on mount if empty and not disabled
    if (!value && inputRefs.current[0] && !disabled) {
      inputRefs.current[0].focus();
    }
  }, [disabled]);

  const handleChange = (index, e) => {
    const rawVal = e.target.value;
    // Only accept numeric input
    const numericVal = rawVal.replace(/\D/g, '');

    if (!numericVal) {
      // Empty/deleted
      const newDigits = [...digits];
      newDigits[index] = '';
      const newVal = newDigits.join('');
      onChange(newVal);
      return;
    }

    // Handle single character typed
    const digitToSet = numericVal.slice(-1);
    const newDigits = [...digits];
    newDigits[index] = digitToSet;
    const newVal = newDigits.join('');
    onChange(newVal);

    // If 6 digits complete, trigger onComplete
    if (newVal.length === 6 && onComplete) {
      onComplete(newVal);
    }

    // Move focus to next input
    if (index < 5 && inputRefs.current[index + 1]) {
      inputRefs.current[index + 1].focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace') {
      if (!digits[index] && index > 0 && inputRefs.current[index - 1]) {
        // Move back and clear previous
        inputRefs.current[index - 1].focus();
        const newDigits = [...digits];
        newDigits[index - 1] = '';
        const newVal = newDigits.join('');
        onChange(newVal);
      }
    } else if (e.key === 'ArrowLeft' && index > 0) {
      inputRefs.current[index - 1]?.focus();
    } else if (e.key === 'ArrowRight' && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handlePaste = (e) => {
    e.preventDefault();
    const pasteData = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (pasteData) {
      onChange(pasteData);
      if (pasteData.length === 6 && onComplete) {
        onComplete(pasteData);
      }
      const focusIndex = Math.min(pasteData.length, 5);
      inputRefs.current[focusIndex]?.focus();
    }
  };

  return (
    <div className="flex items-center justify-center gap-2 sm:gap-3" onPaste={handlePaste}>
      {digits.map((digit, index) => (
        <input
          key={index}
          ref={(el) => (inputRefs.current[index] = el)}
          type="text"
          inputMode="numeric"
          pattern="[0-9]*"
          maxLength={1}
          value={digit}
          disabled={disabled}
          onChange={(e) => handleChange(index, e)}
          onKeyDown={(e) => handleKeyDown(index, e)}
          className={`w-10 h-12 sm:w-12 sm:h-12 text-center text-lg font-bold text-ink dark:text-cream bg-cream dark:bg-ink-soft/20 border rounded-lg transition-colors focus:outline-none focus:ring-1 focus:ring-terracotta disabled:opacity-60 disabled:cursor-not-allowed ${
            hasError
              ? 'border-terracotta'
              : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
          }`}
        />
      ))}
    </div>
  );
};

export default OtpInput;
