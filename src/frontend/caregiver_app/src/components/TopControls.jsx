import React from 'react';
import { useTheme } from '../context/ThemeContext';
import { LanguageSelector } from './LanguageSelector';
import { NotificationsPanel } from './NotificationsPanel';
import { ProfilePopover } from './ProfilePopover';
import { Sun, Moon } from 'lucide-react';

/**
 * TopControls Component
 * 
 * Persistent top-right floating control group.
 * Ordered items (left-to-right single cluster):
 * 1. Language selector
 * 2. Theme toggle
 * 3. Notifications panel
 * 4. Profile avatar chip (rightmost item, when showProfile is true)
 */
export const TopControls = ({ showProfile = true }) => {
  const { theme, toggleTheme } = useTheme();

  const baseButtonClasses =
    'inline-flex items-center justify-center w-8 h-8 sm:w-8.5 sm:h-8.5 rounded-full bg-cream/70 dark:bg-ink-soft/20 border transition-all duration-200 outline-none select-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:border-terracotta focus-visible:ring-2 focus-visible:ring-terracotta/30 active:border-terracotta/60 active:scale-95 shadow-xs';

  return (
    <aside
      aria-label="App controls"
      className="fixed top-3.5 right-3.5 sm:top-5 sm:right-6 z-50 flex items-center font-sans"
    >
      {/* Main Top Controls Pill Group */}
      <div className="flex items-center gap-1.5 p-1 bg-surface/90 dark:bg-ink/90 backdrop-blur-md border border-border/80 dark:border-ink-soft/40 rounded-full shadow-md transition-colors">
        {/* 1. Language Selector */}
        <LanguageSelector />

        {/* 2. Theme Toggle Button */}
        <button
          type="button"
          onClick={toggleTheme}
          aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          className={`${baseButtonClasses} border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 hover:border-border dark:hover:border-ink-soft/60`}
        >
          {theme === 'dark' ? (
            <Sun className="w-4 h-4 text-gold animate-in spin-in-90 duration-200" />
          ) : (
            <Moon className="w-4 h-4 animate-in spin-in-90 duration-200" />
          )}
        </button>

        {/* 3. Notifications Panel */}
        <NotificationsPanel />

        {/* 4. Profile Avatar Popover (Rightmost item in cluster) */}
        {showProfile && <ProfilePopover />}
      </div>
    </aside>
  );
};

export default TopControls;
