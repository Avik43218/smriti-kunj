import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { Clock, ChevronDown, Check } from 'lucide-react';

// ─── Constants ────────────────────────────────────────────────────────────────
const HOURS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const MINUTES = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
const PERIODS = ['AM', 'PM'];

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Parse a time string like "8:00 AM", "8 AM", "8:30 PM" into { hour, minute, period }.
 * Falls back to 8:00 AM for any unrecognised input.
 */
const parseTimeStr = (str) => {
  const match = String(str ?? '')
    .trim()
    .match(/^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$/i);

  if (!match) return { hour: 8, minute: 0, period: 'AM' };

  const rawHour = parseInt(match[1], 10);
  const rawMinute = parseInt(match[2] ?? '0', 10);

  // Snap minute to nearest 5-min step
  const minute = MINUTES.reduce((best, m) =>
    Math.abs(m - rawMinute) < Math.abs(best - rawMinute) ? m : best,
    0
  );

  return {
    hour: rawHour >= 1 && rawHour <= 12 ? rawHour : 8,
    minute,
    period: match[3].toUpperCase(),
  };
};

/** Format parts back to canonical "H:MM AM" string (no leading zero on hour). */
const formatTimeStr = (hour, minute, period) =>
  `${hour}:${String(minute).padStart(2, '0')} ${period}`;

// ─── Component ────────────────────────────────────────────────────────────────

/**
 * TimePicker
 *
 * Props:
 *   value        {string}   – controlled value, e.g. "8:00 AM"
 *   onChange     {function} – called with new value string on each selection
 *   onOpenChange {function} – optional callback invoked with boolean when open state changes
 *   id           {string}   – optional id for the trigger button
 *   label        {string}   – optional aria-label override
 */
export const TimePicker = ({ value, onChange, onOpenChange, id, label }) => {
  const parsed = parseTimeStr(value);
  const [hour, setHour]         = useState(parsed.hour);
  const [minute, setMinute]     = useState(parsed.minute);
  const [period, setPeriod]     = useState(parsed.period);
  const [isOpen, setIsOpen]     = useState(false);
  const [positionAbove, setPositionAbove] = useState(true);
  const [panelStyles, setPanelStyles]     = useState({});

  const containerRef = useRef(null);
  const panelRef     = useRef(null);
  const hourListRef  = useRef(null);
  const minListRef   = useRef(null);

  // Notify parent component about open state changes
  useEffect(() => {
    onOpenChange?.(isOpen);
  }, [isOpen, onOpenChange]);

  // Keep internal state in sync when controlled value changes externally
  useEffect(() => {
    const p = parseTimeStr(value);
    setHour(p.hour);
    setMinute(p.minute);
    setPeriod(p.period);
  }, [value]);

  // Dynamic position calculation for the portal panel
  const updatePosition = () => {
    if (!containerRef.current) return;
    const rect = containerRef.current.getBoundingClientRect();
    const panelWidth = 208; // w-52 = 13rem = 208px

    // Determine horizontal alignment
    const shouldAlignRight = window.innerWidth - rect.left < 230;
    const leftPos = shouldAlignRight
      ? Math.max(8, rect.right - panelWidth)
      : Math.max(8, rect.left);

    // Determine vertical positioning: open upward by default unless cramped above
    const opensAbove = !(rect.top < 210 && window.innerHeight - rect.bottom > 220);
    setPositionAbove(opensAbove);

    if (opensAbove) {
      setPanelStyles({
        position: 'fixed',
        left: `${leftPos}px`,
        bottom: `${Math.max(8, window.innerHeight - rect.top + 6)}px`,
        top: 'auto',
      });
    } else {
      setPanelStyles({
        position: 'fixed',
        left: `${leftPos}px`,
        top: `${rect.bottom + 6}px`,
        bottom: 'auto',
      });
    }
  };

  useEffect(() => {
    if (!isOpen) return;
    updatePosition();

    const handleScrollOrResize = () => {
      updatePosition();
    };

    window.addEventListener('resize', handleScrollOrResize);
    window.addEventListener('scroll', handleScrollOrResize, true);

    return () => {
      window.removeEventListener('resize', handleScrollOrResize);
      window.removeEventListener('scroll', handleScrollOrResize, true);
    };
  }, [isOpen]);

  // Scroll selected items into view when panel opens
  useEffect(() => {
    if (!isOpen) return;
    const t = setTimeout(() => {
      const scrollToIdx = (ref, items, selected) => {
        const idx = items.indexOf(selected);
        if (ref.current && idx !== -1) {
          ref.current.children[idx]?.scrollIntoView({ block: 'nearest' });
        }
      };
      scrollToIdx(hourListRef, HOURS, hour);
      scrollToIdx(minListRef, MINUTES, minute);
    }, 30);
    return () => clearTimeout(t);
  }, [isOpen, hour, minute]);

  // Click-outside to close (handles portal panel and trigger container)
  useEffect(() => {
    if (!isOpen) return;
    const handler = (e) => {
      if (
        containerRef.current &&
        !containerRef.current.contains(e.target) &&
        panelRef.current &&
        !panelRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [isOpen]);

  // Selection handlers — update state and immediately fire onChange
  const selectHour = (h) => { setHour(h); onChange(formatTimeStr(h, minute, period)); };
  const selectMinute = (m) => { setMinute(m); onChange(formatTimeStr(hour, m, period)); };
  const selectPeriod = (p) => { setPeriod(p); onChange(formatTimeStr(hour, minute, p)); };

  const displayValue = formatTimeStr(hour, minute, period);

  const colBtn = (active) =>
    `w-full px-1.5 py-1 rounded-md text-xs font-medium transition-colors text-center cursor-pointer select-none outline-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-terracotta ${
      active
        ? 'bg-terracotta/15 dark:bg-terracotta/25 text-terracotta font-semibold'
        : 'text-ink dark:text-cream hover:bg-cream dark:hover:bg-ink-soft/30'
    }`;

  const portalContent = isOpen && typeof document !== 'undefined' ? (
    createPortal(
      <div
        ref={panelRef}
        role="listbox"
        aria-label="Time selector"
        style={panelStyles}
        className={`bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 rounded-card shadow-card z-[9999] p-2.5 w-52 animate-in fade-in zoom-in-95 duration-150 ${
          positionAbove ? 'origin-bottom' : 'origin-top'
        }`}
      >
        {/* Scoped scrollbar styling inside portal */}
        <style>{`
          .tp-scrollbar::-webkit-scrollbar {
            width: 3px;
          }
          .tp-scrollbar::-webkit-scrollbar-track {
            background: transparent;
          }
          .tp-scrollbar::-webkit-scrollbar-thumb {
            background: rgba(181, 86, 47, 0.35);
            border-radius: 9999px;
          }
          .tp-scrollbar::-webkit-scrollbar-thumb:hover {
            background: rgba(181, 86, 47, 0.65);
          }
          .tp-scrollbar {
            scrollbar-width: thin;
            scrollbar-color: rgba(181, 86, 47, 0.35) transparent;
          }
        `}</style>

        {/* Column headers */}
        <div className="grid grid-cols-3 gap-1.5 mb-1.5 px-1">
          {['Hour', 'Min', 'Period'].map((h) => (
            <span key={h} className="text-[9px] font-bold uppercase tracking-wider text-ink-soft dark:text-cream/60 text-center">
              {h}
            </span>
          ))}
        </div>

        <div className="grid grid-cols-3 gap-1.5">
          {/* Hours */}
          <div
            ref={hourListRef}
            className="tp-scrollbar flex flex-col gap-0.5 max-h-[140px] overflow-y-auto pr-0.5"
          >
            {HOURS.map((h) => (
              <button key={h} type="button" onClick={() => selectHour(h)} className={colBtn(h === hour)}>
                {h}
              </button>
            ))}
          </div>

          {/* Minutes */}
          <div
            ref={minListRef}
            className="tp-scrollbar flex flex-col gap-0.5 max-h-[140px] overflow-y-auto pr-0.5"
          >
            {MINUTES.map((m) => (
              <button key={m} type="button" onClick={() => selectMinute(m)} className={colBtn(m === minute)}>
                {String(m).padStart(2, '0')}
              </button>
            ))}
          </div>

          {/* AM / PM */}
          <div className="flex flex-col gap-1">
            {PERIODS.map((p) => (
              <button
                key={p}
                type="button"
                onClick={() => selectPeriod(p)}
                className={`${colBtn(p === period)} py-2.5 flex items-center justify-center gap-1`}
              >
                {p === period && <Check className="w-3 h-3 text-terracotta shrink-0" />}
                {p}
              </button>
            ))}
          </div>
        </div>

        {/* Done button */}
        <div className="mt-2 pt-2 border-t border-border/60 dark:border-ink-soft/30">
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            className="w-full py-1.5 bg-terracotta/10 hover:bg-terracotta/20 dark:bg-terracotta/15 dark:hover:bg-terracotta/25 text-terracotta text-xs font-semibold rounded-md transition-colors outline-none select-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            Done — {displayValue}
          </button>
        </div>
      </div>,
      document.body
    )
  ) : null;

  return (
    <div className="relative" ref={containerRef}>
      {/* Trigger button */}
      <button
        type="button"
        id={id}
        onClick={() => setIsOpen((prev) => !prev)}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-label={label ?? `Select time, current value: ${displayValue}`}
        className={`w-full inline-flex items-center gap-2 px-3.5 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 outline-none select-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-terracotta min-h-[44px] border shadow-[inset_0_1px_2px_rgba(46,42,36,0.06)] dark:shadow-none ${
          isOpen
            ? 'bg-cream/90 dark:bg-ink-soft/40 border-terracotta/70 dark:border-terracotta text-ink dark:text-cream ring-1 ring-terracotta/30'
            : 'bg-cream/80 dark:bg-ink-soft/30 border-border/80 dark:border-ink-soft/40 text-ink dark:text-cream hover:border-terracotta/50 dark:hover:border-terracotta/40'
        }`}
      >
        <Clock className="w-4 h-4 text-terracotta shrink-0" />
        <span className="flex-1 text-left font-semibold">{displayValue}</span>
        <ChevronDown
          className={`w-4 h-4 text-ink-soft dark:text-cream/60 transition-transform duration-200 shrink-0 ${
            isOpen ? 'rotate-180 text-terracotta' : ''
          }`}
        />
      </button>

      {/* Render panel via portal so it cannot be clipped by overflow containers */}
      {portalContent}
    </div>
  );
};

export default TimePicker;
