import React from 'react';

export const Footer = () => {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="w-full bg-surface dark:bg-ink-soft/10 border-t border-border/80 dark:border-ink-soft/30 mt-auto transition-colors font-sans">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-ink-soft dark:text-cream/60">
        <div className="space-y-1 text-center sm:text-left">
          <div className="flex items-center justify-center sm:justify-start gap-2 font-bold text-ink dark:text-cream">
            <span className="tracking-tight text-sm">Smriti Kunj</span>
            <span className="text-border dark:text-ink-soft/50 font-normal">•</span>
            <span className="font-normal font-sans text-xs">স্মৃতি কুঞ্জ</span>
          </div>
          <p className="text-[11px] text-ink-soft dark:text-cream/70 max-w-md leading-relaxed">
            Cognitive assistive care platform for patient monitoring and routine adherence.
          </p>
        </div>

        <div className="text-center sm:text-right text-[11px]">
          <p>© {currentYear} Smriti Kunj. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
