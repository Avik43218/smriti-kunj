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
        // Functional password meter tokens: progressive palette across Terracotta, Gold, and Sage
        passwordStrength: {
          1: '#B5562F', // Level 1 (Very Weak): Terracotta
          2: '#D47D5C', // Level 2 (Weak): Soft warm terracotta
          3: '#C9962C', // Level 3 (Fair): Brand Gold
          4: '#6E8C6A', // Level 4 (Strong): Brand Sage
          5: '#4E7A4A', // Level 5 (Very Strong): Deep Sage
          // High-contrast text tokens calibrated for light (#FFFDF8) and dark (#2E2A24) modes
          '1-text': '#A8441F',
          '1-text-dark': '#EAA68F',
          '2-text': '#B5562F',
          '2-text-dark': '#E8A07A',
          '3-text': '#986E12',
          '3-text-dark': '#E8BA55',
          '4-text': '#486944',
          '4-text-dark': '#A2C99D',
          '5-text': '#32592D',
          '5-text-dark': '#A6E09F',
        },
        imageOverlay: {
          dark: 'rgba(46,42,36,0.55)',
          warm: 'rgba(181,86,47,0.18)',
          scrim: 'rgba(46,42,36,0.72)',
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