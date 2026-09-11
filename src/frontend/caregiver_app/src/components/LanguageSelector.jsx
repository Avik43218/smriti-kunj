import React, { useState, useEffect, useRef } from 'react';
import { Globe, ChevronDown, Check } from 'lucide-react';

const LANGUAGE_OPTIONS = [
  { code: 'en', label: 'English', native: 'English' },
  { code: 'as', label: 'Assamese', native: 'অসমীয়া' },
];

export const LanguageSelector = ({ variant = 'default' }) => {
  const [selectedLanguage, setSelectedLanguage] = useState(() => {
    try {
      return localStorage.getItem('caregiver_language') || 'en';
    } catch {
      return 'en';
    }
  });

  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef(null);

  useEffect(() => {
    const handleOutsideClick = (e) => {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setIsOpen(false);
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleOutsideClick);
    }
    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
    };
  }, [isOpen]);

  const handleLanguageSelect = (langCode) => {
    setSelectedLanguage(langCode);
    setIsOpen(false);
    try {
      localStorage.setItem('caregiver_language', langCode);
    } catch (err) {
      console.error('Failed to save language preference:', err);
    }
  };

  const currentLanguageObj =
    LANGUAGE_OPTIONS.find((l) => l.code === selectedLanguage) || LANGUAGE_OPTIONS[0];

  const isDarkVariant = variant === 'dark';

  const buttonClassNames = isDarkVariant
    ? isOpen
      ? 'bg-ink-soft/40 border border-terracotta/50 text-terracotta'
      : 'bg-ink-soft/20 border border-ink-soft/40 text-cream/80 hover:text-cream hover:bg-ink-soft/35 hover:border-ink-soft/60 shadow-xs'
    : isOpen
      ? 'bg-cream dark:bg-ink-soft/40 border border-terracotta/50 dark:border-terracotta/50 text-terracotta'
      : 'bg-cream/70 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 hover:border-border dark:hover:border-ink-soft/60 shadow-xs';

  return (
    <div className="relative" ref={containerRef}>
      <button
        type="button"
        onClick={() => setIsOpen((prev) => !prev)}
        aria-label="Change application language"
        aria-expanded={isOpen}
        className={`inline-flex items-center gap-1.5 px-2.5 py-1.5 sm:px-3 sm:py-1.5 rounded-full text-xs font-medium transition-all duration-200 outline-none select-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:border-terracotta focus-visible:ring-2 focus-visible:ring-terracotta/30 active:scale-95 ${buttonClassNames}`}
      >
        <Globe className="w-3.5 h-3.5 text-terracotta shrink-0" />
        <span className="hidden sm:inline font-semibold">{currentLanguageObj.code.toUpperCase()}</span>
        <span className="text-[11px] opacity-80 hidden md:inline">({currentLanguageObj.label})</span>
        <ChevronDown
          className={`w-3 h-3 ${isDarkVariant ? 'text-cream/60' : 'text-ink-soft dark:text-cream/60'} transition-transform duration-200 ${
            isOpen ? 'rotate-180 text-terracotta' : ''
          }`}
        />
      </button>

      {/* Language Options Dropdown Menu */}
      {isOpen && (
        <div className={`absolute right-0 top-full mt-2 w-48 ${isDarkVariant ? 'bg-[#1D1614] border-ink-soft/40 text-cream' : 'bg-surface dark:bg-ink border-border dark:border-ink-soft/40 text-ink dark:text-cream'} border rounded-card shadow-card p-1.5 z-50 font-sans animate-in fade-in zoom-in-95 duration-150`}>
          <div className={`px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider ${isDarkVariant ? 'text-cream/60 border-ink-soft/30' : 'text-ink-soft dark:text-cream/60 border-border/60 dark:border-ink-soft/30'} border-b mb-1`}>
            Language • ভাষা
          </div>
          {LANGUAGE_OPTIONS.map((lang) => {
            const isSelected = selectedLanguage === lang.code;
            return (
              <button
                key={lang.code}
                type="button"
                onClick={() => handleLanguageSelect(lang.code)}
                className={`w-full px-2.5 py-1.5 rounded-lg text-xs flex items-center justify-between transition-colors ${
                  isSelected
                    ? 'bg-terracotta/20 text-terracotta font-semibold'
                    : isDarkVariant
                      ? 'text-cream hover:bg-ink-soft/20 font-medium'
                      : 'text-ink dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/20 font-medium'
                }`}
              >
                <div className="flex items-center gap-2">
                  <span>{lang.label}</span>
                  <span className="text-[11px] opacity-70">({lang.native})</span>
                </div>
                {isSelected && <Check className="w-3.5 h-3.5 text-terracotta" />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default LanguageSelector;
