import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { SettingsDropdown } from './SettingsDropdown';
import { LogOut, ChevronDown, User, Settings } from 'lucide-react';

export const ProfilePopover = () => {
  const { caregiver, logout } = useAuth();
  const navigate = useNavigate();
  const [isOpen, setIsOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const containerRef = useRef(null);

  const caregiverInitials = caregiver?.name
    ? caregiver.name
        .split(' ')
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0].toUpperCase())
        .join('')
    : 'C';

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

  const handleOpenSettings = () => {
    setIsOpen(false);
    setIsSettingsOpen(true);
  };

  const handleLogout = async () => {
    setIsOpen(false);
    await logout();
    navigate('/login', { replace: true });
  };

  if (!caregiver) return null;

  return (
    <div className="relative" ref={containerRef}>
      {/* Clickable Profile Chip */}
      <button
        type="button"
        onClick={() => setIsOpen((prev) => !prev)}
        aria-label="User profile and account settings"
        aria-expanded={isOpen}
        className={`flex items-center gap-2 px-2.5 py-1 rounded-full text-xs transition-all duration-200 select-none outline-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:border-terracotta focus-visible:ring-2 focus-visible:ring-terracotta/30 active:scale-95 ${
          isOpen
            ? 'bg-cream dark:bg-ink-soft/40 border border-terracotta/50 dark:border-terracotta/50 text-terracotta shadow-md'
            : 'bg-surface/90 dark:bg-ink/90 backdrop-blur-md border border-border/80 dark:border-ink-soft/40 shadow-md hover:bg-cream dark:hover:bg-ink-soft/35'
        }`}
      >
        <div className="w-6 h-6 sm:w-7 sm:h-7 rounded-full bg-terracotta text-cream flex items-center justify-center font-bold text-[11px] sm:text-xs shrink-0 shadow-xs">
          {caregiverInitials}
        </div>
        <span className="font-semibold text-ink dark:text-cream truncate max-w-[90px] sm:max-w-[130px] hidden sm:inline">
          {caregiver.name}
        </span>
        <ChevronDown
          className={`w-3.5 h-3.5 text-ink-soft dark:text-cream/60 transition-transform duration-200 ${
            isOpen ? 'rotate-180 text-terracotta' : ''
          }`}
        />
      </button>

      {/* Profile Popover Panel */}
      {isOpen && (
        <div className="absolute right-0 top-full mt-2 w-64 bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 rounded-card shadow-card p-3 z-50 font-sans animate-in fade-in zoom-in-95 duration-150">
          <div className="flex items-center gap-2.5 px-1 pt-0.5 pb-2 border-b border-border/60 dark:border-ink-soft/30 mb-2">
            <div className="w-8 h-8 rounded-full bg-terracotta text-cream flex items-center justify-center font-bold text-xs shrink-0 shadow-xs">
              {caregiverInitials}
            </div>
            <div className="min-w-0 flex-1">
              <div className="font-semibold text-xs text-ink dark:text-cream truncate">
                {caregiver.name}
              </div>
              <div className="text-[11px] text-ink-soft dark:text-cream/70 truncate">
                {caregiver.email || 'caregiver@example.com'}
              </div>
            </div>
          </div>

          {/* Menu Items */}
          <div className="space-y-0.5">
            {/* Settings Trigger Option */}
            <button
              type="button"
              aria-label="Settings menu"
              onClick={handleOpenSettings}
              className="w-full text-left px-2.5 py-1.5 rounded-lg text-xs text-ink dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/20 flex items-center gap-2 transition-colors"
            >
              <Settings className="w-3.5 h-3.5 text-ink-soft dark:text-cream/70" />
              <span>Settings</span>
            </button>

            {/* Logout Action Button */}
            <button
              type="button"
              onClick={handleLogout}
              className="w-full text-left px-2.5 py-1.5 rounded-lg text-xs text-terracotta hover:bg-cream dark:hover:bg-ink-soft/20 font-medium flex items-center gap-2 transition-colors"
            >
              <LogOut className="w-3.5 h-3.5 text-terracotta" />
              <span>Sign Out</span>
            </button>
          </div>
        </div>
      )}

      {/* Settings Overlay Panel */}
      <SettingsDropdown
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
        onBack={() => {
          setIsSettingsOpen(false);
          setIsOpen(true);
        }}
      />
    </div>
  );
};

export default ProfilePopover;
