import React from 'react';

export const Footer = ({ variant = 'default', className = '' }) => {
  const isDarkVariant = variant === 'dark';

  const containerClasses = isDarkVariant
    ? 'bg-ink/85 backdrop-blur-md border-t border-ink-soft/30 text-cream/70'
    : 'bg-surface/50 dark:bg-ink-soft/10 backdrop-blur-sm border-t border-border/70 dark:border-ink-soft/30 text-ink-soft/85 dark:text-cream/70';

  const textClasses = isDarkVariant
    ? 'text-cream/70'
    : 'text-ink-soft/85 dark:text-cream/70';

  return (
    <footer
      className={`relative z-10 w-full mt-auto py-5 px-4 flex flex-col items-center justify-center space-y-2 select-none transition-colors duration-300 font-sans ${containerClasses} ${className}`}
    >
      {/* Traditional Decorative Line Motif */}
      <div className="w-full max-w-xl px-4 flex items-center justify-center gap-4 opacity-85 dark:opacity-90">
        <div className="flex-1 h-[1px] bg-gradient-to-r from-transparent via-terracotta/50 to-gold/80 dark:via-terracotta/40 dark:to-gold/70" />
        <div className="flex items-center gap-1.5 text-gold text-xs font-semibold tracking-widest uppercase select-none">
          ❖ ✦ ❖
        </div>
        <div className="flex-1 h-[1px] bg-gradient-to-l from-transparent via-terracotta/50 to-gold/80 dark:via-terracotta/40 dark:to-gold/70" />
      </div>

      {/* Brand & Subtitle */}
      <p className={`text-[11px] sm:text-xs tracking-wider text-center transition-colors ${textClasses}`}>
        স্মৃতি কুঞ্জ • Smriti Kunj • Cognitive Assist Platform
      </p>
    </footer>
  );
};

export default Footer;

