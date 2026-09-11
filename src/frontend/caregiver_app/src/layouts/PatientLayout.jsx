import React from 'react';
import { Outlet, Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { Navbar } from '../components/Navbar';
import { TopControls } from '../components/TopControls';

export const PatientLayout = () => {
  return (
    <div className="min-h-screen bg-cream dark:bg-ink text-ink dark:text-cream font-sans transition-colors duration-200 flex flex-col relative">
      {/* Return to All Patients / Dashboard Button (Top-Left: Icon-only on mobile, labeled pill on sm+) */}
      <Link
        to="/dashboard"
        aria-label="Back to all patients dashboard"
        className="fixed top-3.5 left-3.5 sm:top-5 sm:left-6 z-40 inline-flex items-center justify-center gap-1.5 w-8 h-8 sm:w-auto sm:h-auto sm:px-3.5 sm:py-2 bg-surface/90 dark:bg-ink/90 backdrop-blur-md border border-border/80 dark:border-ink-soft/40 rounded-full shadow-md text-xs sm:text-sm font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all select-none outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
      >
        <ArrowLeft className="w-4 h-4 text-terracotta shrink-0" />
        <span className="hidden sm:inline">All Patients</span>
      </Link>

      {/* Patient-Scoped Navigation Dock (Centered Top) */}
      <Navbar />

      {/* Persistent Top-Right Controls: Theme Toggle + Settings */}
      <TopControls showSettings={true} />

      {/* Main Content Area: Responsive spacing clearing top controls on mobile, top dock on desktop, and bottom dock on mobile */}
      <main className="flex-1 w-full max-w-7xl mx-auto px-4 sm:px-6 pt-14 sm:pt-20 pb-24 sm:pb-20">
        <Outlet />
      </main>
    </div>
  );
};

export default PatientLayout;
