import React from 'react';

/**
 * Shared IconButton Component
 * 
 * Standardizes rounded button styling with unified border, background,
 * hover, and focus ring treatments in light and dark mode.
 */
export const IconButton = ({
  icon: Icon,
  children,
  onClick,
  ariaLabel,
  ariaExpanded,
  isActive = false,
  className = '',
  size = 'md', // 'sm' | 'md'
}) => {
  const sizeClasses = size === 'sm' ? 'w-8 h-8' : 'w-8 h-8 sm:w-8.5 sm:h-8.5';

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={ariaLabel}
      aria-expanded={ariaExpanded}
      className={`inline-flex items-center justify-center rounded-full bg-cream/70 dark:bg-ink-soft/20 border transition-all duration-200 focus:outline-none focus:ring-1 focus:ring-terracotta ${sizeClasses} ${
        isActive
          ? 'bg-cream dark:bg-ink-soft/40 border-terracotta/50 dark:border-terracotta/50 text-ink dark:text-cream shadow-xs'
          : 'border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 hover:border-border dark:hover:border-ink-soft/60 shadow-xs'
      } ${className}`}
    >
      {Icon ? <Icon className="w-4 h-4" /> : children}
    </button>
  );
};

export default IconButton;
