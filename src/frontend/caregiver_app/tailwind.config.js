/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        cream: '#FBF5EA',
        surface: '#FFFDF8',
        ink: '#2E2A24',
        'ink-soft': '#6B625A',
        terracotta: { DEFAULT: '#B5562F', dark: '#8C3F20' },
        gold: '#C9962C',
        sage: '#6E8C6A',
        alert: '#C1272D', // SOS only — do not reuse elsewhere
        border: '#E4D9C4',
        'status-urgent': '#8C2C24',
        'status-info': '#2C4A6E',
        // Functional exception: 5-step monochromatic terracotta progression for password meter (not part of core brand tokens)
        passwordStrength: {
          1: '#E2A48E', // Level 1 (Very Weak): Muted pale terracotta
          2: '#D47D5C', // Level 2 (Weak): Soft warm terracotta
          3: '#C55F35', // Level 3 (Fair): Vibrant mid-tone terracotta
          4: '#A8441F', // Level 4 (Strong): Rich deep terracotta
          5: '#7E2D11', // Level 5 (Very Strong): Intense roasted terracotta
        },
      },
      fontFamily: {
        sans: ['"Noto Sans"', '"Noto Sans Bengali"', '"Noto Sans Devanagari"', 'sans-serif'],
      },
      borderWidth: {
        stripe: '3px',
      },
      borderRadius: { card: '16px' },
      boxShadow: {
        card: '0 2px 4px rgba(46,42,36,0.08)',
        'card-soft': '0 1px 3px rgba(46,42,36,0.05)',
      },
    },
  },
  plugins: [],
};