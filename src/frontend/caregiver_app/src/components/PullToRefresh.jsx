import React, { useRef, useState, useCallback, useEffect } from 'react';
import { RefreshCw } from 'lucide-react';

/**
 * PullToRefresh — custom touch-gesture pull-to-refresh for mobile handhelds.
 *
 * Strategy: We intercept touchstart/touchmove/touchend on the scrollable
 * container directly (not relying on the browser's native overscroll PTR,
 * which is disabled via `overscroll-behavior: none` in index.css).
 *
 * Trigger: user drags down ≥ THRESHOLD px from the top of the page
 * (i.e. the container is already scrolled to top).
 *
 * Props:
 *   onRefresh  — async function to call when the pull is released.
 *                Defaults to window.location.reload.
 *   threshold  — px to drag before triggering (default 70).
 *   children   — the scrollable content.
 */

const THRESHOLD = 70;      // px of pull required to trigger
const MAX_PULL  = 110;     // px beyond which the pull indicator stops growing
const RESISTANCE = 0.45;  // friction factor (lower = harder to pull)

export const PullToRefresh = ({
  onRefresh,
  threshold = THRESHOLD,
  children,
}) => {
  const containerRef    = useRef(null);
  const startYRef       = useRef(null);
  const pullDistRef     = useRef(0);
  const [pullDist, setPullDist]     = useState(0);   // drives indicator height
  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    setPullDist(0);
    try {
      if (onRefresh) {
        await onRefresh();
      } else {
        window.location.reload();
      }
    } finally {
      // Small delay so spinner is visible even on instant cache hits
      setTimeout(() => setRefreshing(false), 600);
    }
  }, [onRefresh]);

  // ── touch handlers ──────────────────────────────────────────────────────
  const onTouchStart = useCallback((e) => {
    const el = containerRef.current;
    // Only start tracking when the scroll container is at the very top
    if (!el || el.scrollTop > 0) return;
    startYRef.current = e.touches[0].clientY;
    pullDistRef.current = 0;
  }, []);

  const onTouchMove = useCallback((e) => {
    if (startYRef.current === null || refreshing) return;
    const el = containerRef.current;
    // Cancel if the user has scrolled down since touchstart
    if (el && el.scrollTop > 0) {
      startYRef.current = null;
      setPullDist(0);
      return;
    }

    const deltaY = e.touches[0].clientY - startYRef.current;
    if (deltaY <= 0) {
      setPullDist(0);
      return;
    }

    // Apply resistance so the indicator doesn't fly off the screen
    const resistedDelta = Math.min(deltaY * RESISTANCE, MAX_PULL);
    pullDistRef.current = resistedDelta;
    setPullDist(resistedDelta);

    // Prevent the page from scrolling up while we animate the indicator
    if (deltaY > 4) {
      e.preventDefault();
    }
  }, [refreshing]);

  const onTouchEnd = useCallback(() => {
    if (startYRef.current === null) return;
    startYRef.current = null;

    if (pullDistRef.current >= threshold * RESISTANCE) {
      handleRefresh();
    } else {
      // Snap back with a quick animation
      setPullDist(0);
    }
    pullDistRef.current = 0;
  }, [threshold, handleRefresh]);

  // Attach passive:false so we can call preventDefault inside onTouchMove
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    el.addEventListener('touchstart', onTouchStart, { passive: true });
    el.addEventListener('touchmove',  onTouchMove,  { passive: false });
    el.addEventListener('touchend',   onTouchEnd,   { passive: true });

    return () => {
      el.removeEventListener('touchstart', onTouchStart);
      el.removeEventListener('touchmove',  onTouchMove);
      el.removeEventListener('touchend',   onTouchEnd);
    };
  }, [onTouchStart, onTouchMove, onTouchEnd]);

  // ── derived values ──────────────────────────────────────────────────────
  const triggered = pullDist >= threshold * RESISTANCE || refreshing;
  // Progress 0→1 as pull approaches threshold
  const progress  = Math.min(pullDist / (threshold * RESISTANCE), 1);
  // Spinner rotation angle follows drag when not yet triggered
  const spinAngle = triggered ? undefined : Math.round(progress * 270);

  return (
    /* Outer wrapper: full viewport height, overflow-y handles the page scroll */
    <div
      ref={containerRef}
      className="h-full overflow-y-auto overflow-x-hidden"
      style={{ WebkitOverflowScrolling: 'touch' }}
    >
      {/* ── Pull indicator ─────────────────────────────────────────────── */}
      <div
        aria-hidden="true"
        className="flex items-center justify-center overflow-hidden transition-[height] duration-200 ease-out"
        style={{
          height: refreshing ? 52 : pullDist > 0 ? Math.round(pullDist) : 0,
          // Only animate height back to 0 on release, not while pulling
          transition: pullDist === 0 || refreshing
            ? 'height 0.25s cubic-bezier(0.4, 0, 0.2, 1)'
            : 'none',
        }}
      >
        {(pullDist > 4 || refreshing) && (
          <div
            className="flex flex-col items-center gap-1 select-none"
            style={{ opacity: Math.max(0.3, progress) }}
          >
            <div
              className={`
                w-8 h-8 rounded-full border-2 flex items-center justify-center shadow-sm
                ${triggered
                  ? 'border-terracotta bg-terracotta/10 text-terracotta'
                  : 'border-border dark:border-ink-soft/50 bg-surface dark:bg-ink text-ink-soft dark:text-cream/60'}
              `}
              style={{
                transform: `rotate(${spinAngle ?? 0}deg)`,
                transition: refreshing ? 'none' : 'transform 0.05s linear',
              }}
            >
              <RefreshCw
                className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`}
              />
            </div>
            <span className="text-[10px] font-medium text-ink-soft dark:text-cream/50 tracking-wide">
              {refreshing
                ? 'Refreshing…'
                : triggered
                  ? 'Release to refresh'
                  : 'Pull to refresh'}
            </span>
          </div>
        )}
      </div>

      {/* ── Page content ────────────────────────────────────────────────── */}
      {children}
    </div>
  );
};

export default PullToRefresh;
