import React from 'react';
import { BellOff, Clock, CalendarX, X } from 'lucide-react';

/**
 * AlarmOffModal
 *
 * Prompts the caregiver when toggling an alarm off in the Health & Wellness section.
 * Allows choosing between muting once (just for current/next instance) or repeatedly (permanently).
 *
 * Props:
 *   isOpen              {boolean}  - Controls modal visibility
 *   reminderLabel       {string}   - Name of the reminder being turned off
 *   onTurnOffOnce       {Function} - Callback when user chooses "Turn off once"
 *   onTurnOffRepeatedly {Function} - Callback when user chooses "Turn off repeatedly"
 *   onCancel            {Function} - Callback to dismiss without turning off
 */
export const AlarmOffModal = ({
  isOpen,
  reminderLabel = 'this reminder',
  onTurnOffOnce,
  onTurnOffRepeatedly,
  onCancel,
}) => {
  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-[60] bg-ink/50 dark:bg-ink/70 flex items-center justify-center p-4"
      onClick={onCancel}
      aria-modal="true"
      role="dialog"
      aria-label="Turn off alarm confirmation"
    >
      <div
        className="bg-surface dark:bg-ink border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-md max-w-md w-full space-y-5 animate-in fade-in zoom-in duration-200"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-terracotta/10 dark:bg-terracotta/20 border border-terracotta/30 flex items-center justify-center shrink-0">
              <BellOff className="w-4 h-4 text-terracotta" />
            </div>
            <div>
              <h3 className="text-base font-bold text-ink dark:text-cream">
                Turn Off Alarm
              </h3>
              <p className="text-[11px] text-ink-soft dark:text-cream/60">
                Choose silence duration for this reminder
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onCancel}
            aria-label="Close dialog"
            className="p-1.5 text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream rounded-lg hover:bg-cream dark:hover:bg-ink-soft/30 transition-colors outline-none focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Prompt question */}
        <p className="text-sm text-ink dark:text-cream/90 leading-relaxed">
          How would you like to turn off the alarm for{' '}
          <strong className="text-terracotta font-semibold">
            {reminderLabel}
          </strong>
          ?
        </p>

        {/* Options */}
        <div className="space-y-3">
          {/* Option 1: Turn off once */}
          <button
            type="button"
            onClick={onTurnOffOnce}
            className="w-full text-left p-3.5 bg-cream/50 dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 border border-border/80 dark:border-ink-soft/40 hover:border-terracotta/60 rounded-xl transition-all group flex items-start gap-3 outline-none focus:outline-none focus-visible:ring-2 focus-visible:ring-terracotta"
          >
            <div className="w-8 h-8 rounded-lg bg-surface dark:bg-ink border border-border/60 dark:border-ink-soft/40 flex items-center justify-center shrink-0 group-hover:border-terracotta/40 transition-colors mt-0.5">
              <Clock className="w-4 h-4 text-ink-soft dark:text-cream/70 group-hover:text-terracotta transition-colors" />
            </div>
            <div className="space-y-0.5 min-w-0">
              <div className="flex items-center justify-between">
                <span className="text-sm font-bold text-ink dark:text-cream group-hover:text-terracotta transition-colors">
                  Turn Off Just This Once
                </span>
                <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded-full bg-cream dark:bg-ink-soft/60 border border-border/60 text-ink-soft dark:text-cream/70">
                  Temporary
                </span>
              </div>
              <p className="text-xs text-ink-soft dark:text-cream/65 leading-relaxed">
                Mute for the next scheduled occurrence only. Alerts will resume automatically afterwards.
              </p>
            </div>
          </button>

          {/* Option 2: Turn off repeatedly */}
          <button
            type="button"
            onClick={onTurnOffRepeatedly}
            className="w-full text-left p-3.5 bg-cream/50 dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 border border-border/80 dark:border-ink-soft/40 hover:border-terracotta/60 rounded-xl transition-all group flex items-start gap-3 outline-none focus:outline-none focus-visible:ring-2 focus-visible:ring-terracotta"
          >
            <div className="w-8 h-8 rounded-lg bg-surface dark:bg-ink border border-border/60 dark:border-ink-soft/40 flex items-center justify-center shrink-0 group-hover:border-terracotta/40 transition-colors mt-0.5">
              <CalendarX className="w-4 h-4 text-ink-soft dark:text-cream/70 group-hover:text-terracotta transition-colors" />
            </div>
            <div className="space-y-0.5 min-w-0">
              <div className="flex items-center justify-between">
                <span className="text-sm font-bold text-ink dark:text-cream group-hover:text-terracotta transition-colors">
                  Turn Off Repeatedly
                </span>
                <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded-full bg-terracotta/10 dark:bg-terracotta/20 border border-terracotta/30 text-terracotta">
                  Always
                </span>
              </div>
              <p className="text-xs text-ink-soft dark:text-cream/65 leading-relaxed">
                Keep the alarm turned off indefinitely for all future reminders until you turn it back on.
              </p>
            </div>
          </button>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end pt-2 border-t border-border/60 dark:border-ink-soft/30">
          <button
            type="button"
            onClick={onCancel}
            className="px-4 py-2 text-sm font-semibold text-ink dark:text-cream bg-cream dark:bg-ink-soft/30 hover:bg-cream/80 dark:hover:bg-ink-soft/50 border border-border/80 dark:border-ink-soft/40 rounded-lg transition-colors outline-none focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            Cancel (Keep Alarm On)
          </button>
        </div>
      </div>
    </div>
  );
};

export default AlarmOffModal;
