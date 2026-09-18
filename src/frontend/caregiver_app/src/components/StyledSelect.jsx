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
export const StyledSelect = ({
  id,
  value,
  onChange,
  options = [],
  placeholder,
  className = '',
  buttonClassName = '',
  size = 'md',
  align = 'auto',
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [positionAbove, setPositionAbove] = useState(false);
  const [autoAlignRight, setAutoAlignRight] = useState(false);

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

  // Position calculation — open downward by default, flip up if space below is tight
  useEffect(() => {
    if (!isOpen || !containerRef.current) return;
    const rect = containerRef.current.getBoundingClientRect();
    // Align right when near right viewport edge (panel ~220px wide)
    setAutoAlignRight(window.innerWidth - rect.left < 220);

    const spaceBelow = window.innerHeight - rect.bottom;
    const spaceAbove = rect.top;
    // Open upward if space below is less than dropdown height (~220px) and there's more space above
    if (spaceBelow < 220 && spaceAbove > spaceBelow) {
      setPositionAbove(true);
    } else {
      setPositionAbove(false);
    }
  }, [isOpen]);

  const isAlignRight = align === 'right' || (align === 'auto' && autoAlignRight);
  const isSm = size === 'sm';

  return (
    <div className={`relative ${className}`} ref={containerRef}>
      {/* Scoped scrollbar styling — matches TimePicker.jsx brand pattern */}
      <style>{`
        .ss-scrollbar::-webkit-scrollbar {
          width: 4px;
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
        className={`w-full inline-flex items-center justify-between font-medium transition-all duration-200 outline-none select-none focus:outline-none focus:ring-2 focus:ring-terracotta/40 border ${
          isSm
            ? 'px-2.5 py-1.5 rounded-lg text-xs min-h-[32px]'
            : 'px-3.5 py-2.5 rounded-xl text-sm min-h-[42px]'
        } ${
          isOpen
            ? 'bg-cream/90 dark:bg-ink-soft/40 border-terracotta dark:border-terracotta text-ink dark:text-cream ring-2 ring-terracotta/40'
            : 'bg-cream/40 dark:bg-ink-soft/20 border-border/80 dark:border-ink-soft/40 text-ink dark:text-cream hover:border-terracotta/60 dark:hover:border-terracotta/50 shadow-xs'
        } ${buttonClassName}`}
      >
        <span className="truncate text-left">{selectedObj.label}</span>
        <ChevronDown
          className={`${
            isSm ? 'w-3.5 h-3.5 ml-1.5' : 'w-4 h-4 ml-2'
          } text-ink-soft dark:text-cream/60 transition-transform duration-200 shrink-0 ${
            isOpen ? 'rotate-180 text-terracotta' : ''
          }`}
        />
      </button>

      {/* Options panel */}
      {isOpen && (
        <div
          role="listbox"
          className={`absolute ${isAlignRight ? 'right-0' : 'left-0'} ${
            positionAbove ? 'bottom-full mb-1.5' : 'top-full mt-1.5'
          } ${
            isSm ? 'w-full min-w-[170px] p-1 rounded-lg' : 'w-full min-w-[200px] p-1.5 rounded-xl'
          } bg-surface dark:bg-ink border border-border/80 dark:border-ink-soft/40 shadow-lg z-50 max-h-56 overflow-y-auto ss-scrollbar animate-in fade-in zoom-in-95 duration-150 ${
            isAlignRight
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
                className={`w-full ${
                  isSm ? 'px-2.5 py-1.5 rounded-md text-xs' : 'px-3 py-2 rounded-lg text-xs sm:text-sm'
                } flex items-center justify-between transition-colors text-left cursor-pointer outline-none select-none ${
                  isSelected
                    ? 'bg-terracotta/15 dark:bg-terracotta/25 text-terracotta font-semibold'
                    : 'text-ink dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/30 font-medium'
                }`}
              >
                <span className="truncate">{opt.label}</span>
                {isSelected && (
                  <Check
                    className={`${
                      isSm ? 'w-3.5 h-3.5 ml-1.5' : 'w-4 h-4 ml-2'
                    } text-terracotta shrink-0`}
                  />
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default StyledSelect;
