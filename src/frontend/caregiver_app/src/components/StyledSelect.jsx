import React, { useState, useEffect, useRef } from 'react';
import { ChevronDown, Check } from 'lucide-react';

/**
 * StyledSelect
 *
 * A brand-styled custom dropdown select component.
 *
 * Props:
 *   id          {string}   – optional id for the trigger button
 *   value       {string}   – controlled selected value
 *   onChange    {function} – called with the new value string
 *   options     {Array}    – array of strings or { value, label } objects
 *   placeholder {string}   – placeholder text when no value selected
 */
export const StyledSelect = ({ id, value, onChange, options = [], placeholder }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [positionAbove, setPositionAbove] = useState(true);
  const [alignRight, setAlignRight] = useState(false);

  const containerRef = useRef(null);

  // Normalise options to { value, label } objects
  const normalizedOptions = options.map((opt) =>
    typeof opt === 'string' ? { value: opt, label: opt } : opt
  );

  const selectedObj = normalizedOptions.find((o) => o.value === value) || {
    value,
    label: value || placeholder || 'Select an option',
  };

  // Click-outside to close
  useEffect(() => {
    if (!isOpen) return;
    const handleOutsideClick = (e) => {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleOutsideClick);
    return () => document.removeEventListener('mousedown', handleOutsideClick);
  }, [isOpen]);

  // Position calculation — open upward by default, flip down only when needed
  useEffect(() => {
    if (!isOpen || !containerRef.current) return;
    const rect = containerRef.current.getBoundingClientRect();
    // Align right when near right viewport edge (panel ~200px wide)
    setAlignRight(window.innerWidth - rect.left < 220);
    // Open upward by default; flip down only when very little room above
    if (rect.top < 180 && window.innerHeight - rect.bottom > 200) {
      setPositionAbove(false);
    } else {
      setPositionAbove(true);
    }
  }, [isOpen]);

  return (
    <div className="relative" ref={containerRef}>
      {/* Scoped scrollbar styling — matches TimePicker.jsx brand pattern */}
      <style>{`
        .ss-scrollbar::-webkit-scrollbar {
          width: 3px;
        }
        .ss-scrollbar::-webkit-scrollbar-track {
          background: transparent;
        }
        .ss-scrollbar::-webkit-scrollbar-thumb {
          background: rgba(181, 86, 47, 0.35);
          border-radius: 9999px;
        }
        .ss-scrollbar::-webkit-scrollbar-thumb:hover {
          background: rgba(181, 86, 47, 0.65);
        }
        .ss-scrollbar {
          scrollbar-width: thin;
          scrollbar-color: rgba(181, 86, 47, 0.35) transparent;
        }
      `}</style>

      {/* Trigger button */}
      <button
        type="button"
        id={id}
        onClick={() => setIsOpen((prev) => !prev)}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        className={`w-full inline-flex items-center justify-between px-3.5 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 outline-none select-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-terracotta min-h-[44px] border shadow-[inset_0_1px_2px_rgba(46,42,36,0.06)] dark:shadow-none ${
          isOpen
            ? 'bg-cream/90 dark:bg-ink-soft/40 border-terracotta/70 dark:border-terracotta text-ink dark:text-cream ring-1 ring-terracotta/30'
            : 'bg-cream/80 dark:bg-ink-soft/30 border-border/80 dark:border-ink-soft/40 text-ink dark:text-cream hover:border-terracotta/50 dark:hover:border-terracotta/40'
        }`}
      >
        <span className="truncate">{selectedObj.label}</span>
        <ChevronDown
          className={`w-4 h-4 text-ink-soft dark:text-cream/60 transition-transform duration-200 shrink-0 ml-2 ${
            isOpen ? 'rotate-180 text-terracotta' : ''
          }`}
        />
      </button>

      {/* Options panel — opens upward by default */}
      {isOpen && (
        <div
          role="listbox"
          className={`absolute ${alignRight ? 'right-0' : 'left-0'} ${
            positionAbove ? 'bottom-full mb-1.5' : 'top-full mt-1.5'
          } w-full bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 rounded-card shadow-card p-1.5 z-50 max-h-56 overflow-y-auto ss-scrollbar animate-in fade-in zoom-in-95 duration-150 ${
            alignRight
              ? positionAbove ? 'origin-bottom-right' : 'origin-top-right'
              : positionAbove ? 'origin-bottom-left' : 'origin-top-left'
          }`}
        >
          {normalizedOptions.map((opt) => {
            const isSelected = opt.value === value;
            return (
              <button
                key={opt.value}
                type="button"
                role="option"
                aria-selected={isSelected}
                onClick={() => {
                  onChange(opt.value);
                  setIsOpen(false);
                }}
                className={`w-full px-3 py-2 rounded-lg text-xs sm:text-sm flex items-center justify-between transition-colors text-left cursor-pointer outline-none select-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-terracotta ${
                  isSelected
                    ? 'bg-terracotta/10 dark:bg-terracotta/20 text-terracotta font-semibold'
                    : 'text-ink dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/20 font-medium'
                }`}
              >
                <span>{opt.label}</span>
                {isSelected && <Check className="w-4 h-4 text-terracotta shrink-0 ml-2" />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default StyledSelect;
