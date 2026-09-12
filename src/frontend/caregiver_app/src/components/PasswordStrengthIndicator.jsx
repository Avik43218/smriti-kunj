import React from 'react';

/**
 * PasswordStrengthIndicator Component
 * 
 * Evaluates password strength. Displays a 5-segment visual meter and text label:
 * 1. Very Weak (passwordStrength.1: #E2A48E)
 * 2. Weak (passwordStrength.2: #D47D5C)
 * 3. Fair (passwordStrength.3: #C55F35)
 * 4. Strong (passwordStrength.4: #A8441F)
 * 5. Very Strong (passwordStrength.5: #7E2D11)
 * 
 * Criteria:
 * - Length: 8+ chars (base requirement for Fair+), 12+ chars bonus, 16+ chars bonus
 * - Character variety: Uppercase, Lowercase, Number, Special character
 */
export const PasswordStrengthIndicator = ({ password = '' }) => {
  if (!password) return null;

  const length = password.length;
  const hasMinLength = length >= 8;
  const hasLength12 = length >= 12;
  const hasLength16 = length >= 16;

  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecial = /[^A-Za-z0-9]/.test(password);

  // Variety count (out of 4 character types)
  const varietyCount = [hasUpper, hasLower, hasNumber, hasSpecial].filter(Boolean).length;

  let score = 1; // Default: 1 (Very Weak)

  if (length < 6) {
    // Under 6 chars is always Very Weak
    score = 1;
  } else if (length < 8) {
    // 6-7 characters: Weak if mixed, otherwise Very Weak
    score = varietyCount >= 2 ? 2 : 1;
  } else {
    // 8+ chars base requirement satisfied
    if (varietyCount === 1) {
      // 8+ chars but single character type (e.g. "aaaaaaaa" or "12345678")
      score = 2; // Weak
    } else if (
      (length >= 14 && varietyCount >= 3) ||
      (length >= 12 && varietyCount === 4) ||
      (length >= 16 && varietyCount >= 2)
    ) {
      // Long passphrase with good variety or full 4-type 12+ char password
      score = 5; // Very Strong
    } else if (
      (length >= 12 && varietyCount >= 2) ||
      (length >= 10 && varietyCount >= 3) ||
      varietyCount === 4
    ) {
      // 10+ chars with 3 types, or 8+ chars with all 4 types (symbols included)
      score = 4; // Strong
    } else {
      // Standard 8-9 chars with 2-3 types (e.g. "Password", "Pass1234") or 10-11 chars with 2 types
      score = 3; // Fair
    }
  }

  // Tier configuration based on score (1 to 5)
  // Uses dedicated passwordStrength terracotta monochromatic gradient tokens from tailwind.config.js
  const TIERS = {
    1: {
      label: 'Very Weak',
      barCount: 1,
      color: 'bg-passwordStrength-1',
      textColor: 'text-passwordStrength-2 dark:text-passwordStrength-1',
    },
    2: {
      label: 'Weak',
      barCount: 2,
      color: 'bg-passwordStrength-2',
      textColor: 'text-passwordStrength-3 dark:text-passwordStrength-2',
    },
    3: {
      label: 'Fair',
      barCount: 3,
      color: 'bg-passwordStrength-3',
      textColor: 'text-passwordStrength-3 dark:text-passwordStrength-2',
    },
    4: {
      label: 'Strong',
      barCount: 4,
      color: 'bg-passwordStrength-4',
      textColor: 'text-passwordStrength-4 dark:text-passwordStrength-2',
    },
    5: {
      label: 'Very Strong',
      barCount: 5,
      color: 'bg-passwordStrength-5',
      textColor: 'text-passwordStrength-5 dark:text-passwordStrength-1',
    },
  };

  const currentTier = TIERS[score];

  return (
    <div className="mt-2 space-y-1.5 font-sans" aria-live="polite">
      {/* 5-bar segment visual meter */}
      <div className="flex items-center gap-1.5 h-1.5 w-full">
        {[1, 2, 3, 4, 5].map((step) => {
          const isFilled = step <= currentTier.barCount;
          return (
            <div
              key={step}
              className={`h-full flex-1 rounded-full transition-colors duration-200 ${
                isFilled ? currentTier.color : 'bg-border/60 dark:bg-ink-soft/30'
              }`}
            />
          );
        })}
      </div>

      {/* Text label */}
      <div className="flex items-center justify-between text-[11px]">
        <span className="text-ink-soft dark:text-cream/60">
          Password strength:
        </span>
        <span className={`font-semibold ${currentTier.textColor}`}>
          {currentTier.label}
        </span>
      </div>
    </div>
  );
};

export default PasswordStrengthIndicator;
