import React from 'react';
import { Trash2, X } from 'lucide-react';

/**
 * ConfirmDeleteModal
 *
 * A small reusable confirmation dialog shown before any destructive delete.
 * Matches the existing modal styling used throughout CarePlan (backdrop,
 * rounded-card panel, brand tokens -- no backdrop blur per app convention).
 *
 * Props:
 *   message   {string}   - Contextual question shown to the user
 *   onConfirm {Function} - Called when the user confirms the delete
 *   onCancel  {Function} - Called when the user cancels
 */
export const ConfirmDeleteModal = ({ message, onConfirm, onCancel }) => {
  return (
    <div
      className="fixed inset-0 z-[60] bg-ink/50 dark:bg-ink/70 flex items-center justify-center p-4"
      onClick={onCancel}
      aria-modal="true"
      role="dialog"
      aria-label="Confirm delete"
    >
      <div
        className="bg-surface dark:bg-ink border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-md max-w-sm w-full space-y-5 animate-in fade-in zoom-in duration-200"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-3">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-full bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/40 flex items-center justify-center shrink-0">
              <Trash2 className="w-3.5 h-3.5 text-terracotta" />
            </div>
            <h3 className="text-base font-bold text-ink dark:text-cream">
              Confirm Delete
            </h3>
          </div>
          <button
            type="button"
            onClick={onCancel}
            aria-label="Cancel"
            className="p-1.5 text-ink-soft dark:text-cream/70 hover:text-ink dark:hover:text-cream rounded-lg hover:bg-cream dark:hover:bg-ink-soft/30 transition-colors outline-none focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Message */}
        <p className="text-sm text-ink dark:text-cream/90 leading-relaxed">
          {message}
        </p>
        <p className="text-xs text-ink-soft dark:text-cream/60 -mt-3">
          This action cannot be undone.
        </p>

        {/* Actions */}
        <div className="flex items-center justify-end gap-3 pt-1">
          <button
            type="button"
            onClick={onCancel}
            className="px-4 py-2 text-sm font-semibold text-ink dark:text-cream bg-cream dark:bg-ink-soft/30 hover:bg-cream/80 dark:hover:bg-ink-soft/50 border border-border/80 dark:border-ink-soft/40 rounded-lg transition-colors outline-none focus:outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            className="px-4 py-2 text-sm font-bold text-cream bg-terracotta hover:bg-terracotta/90 active:scale-95 rounded-lg transition-all shadow-sm outline-none focus:outline-none focus-visible:ring-2 focus-visible:ring-terracotta/50"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmDeleteModal;
