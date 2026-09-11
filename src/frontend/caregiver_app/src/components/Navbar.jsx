import React, { useState, useRef, useEffect } from 'react';
import { NavLink, useLocation, useParams } from 'react-router-dom';
import {
  UserCheck,
  TrendingUp,
  CalendarCheck,
} from 'lucide-react';

/**
 * useFinePointer
 * Returns true when the device has both hover capability AND a fine pointer
 * (mouse / trackpad). Returns false for coarse/touch inputs (phones, tablets)
 * and for devices with no hover (most touch-first devices).
 *
 * Uses `(hover: hover) and (pointer: fine)` — the most reliable CSS4 media
 * feature pair for distinguishing mouse input from touch, independent of
 * screen width.
 */
const useFinePointer = () => {
  const query = '(hover: hover) and (pointer: fine)';
  const [isFine, setIsFine] = useState(() => {
    if (typeof window === 'undefined') return false;
    return window.matchMedia(query).matches;
  });

  useEffect(() => {
    const mql = window.matchMedia(query);
    const handler = (e) => setIsFine(e.matches);
    mql.addEventListener('change', handler);
    return () => mql.removeEventListener('change', handler);
  }, []);

  return isFine;
};

export const Navbar = () => {
  const location = useLocation();
  const params = useParams();
  const patientId = params.id || location.pathname.split('/patients/')[1]?.split('/')[0] || 'p101';

  // Mouse/trackpad detected — enable magnification and hover tooltips
  const isFinePointer = useFinePointer();

  const [hoveredIndex, setHoveredIndex] = useState(null);
  const dockRef = useRef(null);

  const DOCK_ITEMS = [
    {
      id: 'details',
      name: 'Details',
      path: `/patients/${patientId}/details`,
      icon: UserCheck,
      matchExact: true,
    },
    {
      id: 'analytics',
      name: 'Analytics',
      path: `/patients/${patientId}/analytics`,
      icon: TrendingUp,
      matchExact: false,
    },
    {
      id: 'care-plan',
      name: 'Care Plan',
      path: `/patients/${patientId}/care-plan`,
      icon: CalendarCheck,
      matchExact: false,
    },
  ];

  /**
   * getScale — only runs when isFinePointer is true.
   * On touch devices this is never called; scale is always 1.
   */
  const getScale = (index) => {
    if (!isFinePointer || hoveredIndex === null) return 1;
    const distance = Math.abs(hoveredIndex - index);
    if (distance === 0) return 1.35;
    if (distance === 1) return 1.15;
    return 1;
  };

  return (
    <nav
      ref={dockRef}
      aria-label="Patient Navigation Dock"
      // Only wire mouse events when the device can hover
      onMouseLeave={isFinePointer ? () => setHoveredIndex(null) : undefined}
      className="fixed bottom-4 sm:bottom-auto sm:top-5 left-1/2 -translate-x-1/2 z-40 flex items-end gap-4 sm:gap-6 px-4 py-2 sm:px-6 sm:py-2.5 bg-surface/90 dark:bg-ink/90 backdrop-blur-md border border-border/80 dark:border-ink-soft/40 rounded-full shadow-xl transition-colors duration-200 select-none"
    >
      {DOCK_ITEMS.map((item, index) => {
        const isActive = item.matchExact
          ? location.pathname === item.path ||
            location.pathname === `/patients/${patientId}` ||
            location.pathname === `/patients/${patientId}/`
          : location.pathname.startsWith(item.path);

        const Icon = item.icon;
        const scale = getScale(index);

        return (
          <div
            key={item.id}
            // Only register mouseover when device has fine pointer
            onMouseEnter={isFinePointer ? () => setHoveredIndex(index) : undefined}
            className="relative flex flex-col items-center group"
          >
            {/* Dock Icon Button
                - Fine pointer: scale transform applied, hover ring classes active
                - Touch: scale is always 1 (no transform), hover classes are harmless
                  (touch browsers don't trigger :hover persistently) */}
            <NavLink
              to={item.path}
              aria-label={item.name}
              className={`w-10 h-10 sm:w-11 sm:h-11 rounded-full flex items-center justify-center transition-all duration-200 ease-out origin-bottom outline-none focus:outline-none focus:ring-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-terracotta ${
                isActive
                  ? 'bg-cream dark:bg-ink-soft/40 text-terracotta border border-terracotta/40 dark:border-terracotta/40 shadow-xs'
                  : 'bg-cream/60 dark:bg-ink-soft/20 text-ink-soft dark:text-cream/80 border border-border/70 dark:border-ink-soft/30 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35'
              }`}
              style={
                // Only apply the inline transform when magnification is in play.
                // On touch devices scale is always 1, so we can skip the style entirely
                // to avoid any transform compositing overhead.
                isFinePointer && scale !== 1 ? { transform: `scale(${scale})` } : undefined
              }
            >
              <Icon className="w-5 h-5 sm:w-5.5 sm:h-5.5 transition-transform duration-200" />
            </NavLink>

            {/* Active Page Indicator Dot — unchanged; purely opacity-driven, no hover dependency */}
            <div className="w-full h-1.5 mt-1 flex items-center justify-center pointer-events-none">
              <span
                className={`w-1.5 h-1.5 rounded-full bg-terracotta transition-opacity duration-300 ${
                  isActive ? 'opacity-100' : 'opacity-0'
                }`}
              />
            </div>

            {/* Tooltip — only rendered in the DOM for fine-pointer devices.
                Omitting it entirely on touch means zero chance of flicker on tap. */}
            {isFinePointer && (
              <div
                role="tooltip"
                className="absolute bottom-full sm:bottom-auto sm:top-full mb-2 sm:mb-0 sm:mt-1.5 left-1/2 -translate-x-1/2 px-2.5 py-0.5 bg-ink/90 dark:bg-surface/95 text-surface dark:text-ink text-xs font-medium rounded-full shadow-md whitespace-nowrap opacity-0 translate-y-1 sm:-translate-y-1 group-hover:opacity-100 group-hover:translate-y-0 transition-all duration-150 pointer-events-none z-50"
              >
                {item.name}
              </div>
            )}
          </div>
        );
      })}
    </nav>
  );
};

export default Navbar;
