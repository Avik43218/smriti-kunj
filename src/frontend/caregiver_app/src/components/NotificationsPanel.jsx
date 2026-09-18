import React, { useState, useEffect, useRef } from 'react';
import { Bell, Inbox } from 'lucide-react';

export const NotificationsPanel = () => {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef(null);

  const baseButtonClasses =
    'inline-flex items-center justify-center w-8 h-8 sm:w-8.5 sm:h-8.5 rounded-full bg-cream/70 dark:bg-ink-soft/20 border transition-all duration-200 outline-none select-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:border-terracotta focus-visible:ring-2 focus-visible:ring-terracotta/30 active:border-terracotta/60 active:scale-95 shadow-xs';

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

  return (
    <div className="relative" ref={containerRef}>
      <button
        type="button"
        onClick={() => setIsOpen((prev) => !prev)}
        aria-label="Notifications"
        aria-expanded={isOpen}
        className={`${baseButtonClasses} ${
          isOpen
            ? 'bg-cream dark:bg-ink-soft/40 border-terracotta/50 dark:border-terracotta/50 text-terracotta'
            : 'border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 hover:border-border dark:hover:border-ink-soft/60'
        }`}
      >
        <Bell className="w-4 h-4" />
      </button>

      {/* Notifications Popover Panel */}
      {isOpen && (
        <div className="absolute right-0 top-full mt-2.5 w-72 sm:w-80 bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 rounded-card shadow-card p-4 z-50 font-sans animate-in fade-in zoom-in-95 duration-150">
          <div className="flex items-center justify-between pb-2 border-b border-border/60 dark:border-ink-soft/30 mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-ink dark:text-cream">
              Notifications
            </span>
            <span className="text-[10px] text-ink-soft dark:text-cream/60">
              0 New
            </span>
          </div>

          {/* Genuine Empty State */}
          <div className="py-6 px-3 text-center space-y-2">
            <div className="w-10 h-10 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-ink-soft dark:text-cream/60 mx-auto">
              <Inbox className="w-5 h-5 text-terracotta" />
            </div>
            <p className="text-xs sm:text-sm font-semibold text-ink dark:text-cream">
              No notifications yet
            </p>
            <p className="text-[11px] text-ink-soft dark:text-cream/70 leading-relaxed">
              Clinical reminders, patient alert dispatches, and sync status updates will appear here.
            </p>
          </div>
        </div>
      )}
    </div>
  );
};

export default NotificationsPanel;
