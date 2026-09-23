import React from 'react';
import { Outlet } from 'react-router-dom';
import { TopControls } from '../components/TopControls';
import { Footer } from '../components/Footer';
import { MotifBackground } from '../components/MotifBackground';
import { PullToRefresh } from '../components/PullToRefresh';

export const DashboardLayout = () => {
  return (
    /* Fixed viewport container — PullToRefresh becomes the scroll root */
    <div className="h-screen bg-cream dark:bg-ink text-ink dark:text-cream font-sans transition-colors duration-200 relative overflow-hidden">
      {/* Ambient Cultural Motif Background Pattern */}
      <MotifBackground />

      {/* Persistent Top-Right Controls: Profile Chip + Language, Theme, Notifications, Settings */}
      <TopControls showSettings={true} showProfile={true} />

      {/* Pull-to-Refresh scroll container (mobile handhelds) */}
      <PullToRefresh>
        {/* Inner flex column mirrors the original min-h-screen layout */}
        <div className="flex flex-col min-h-screen">
          {/* Main Content Area */}
          <main className="flex-1 w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-16 sm:pt-20 pb-12 sm:pb-16 relative z-10">
            <Outlet />
          </main>

          {/* Site Identity Footer */}
          <Footer />
        </div>
      </PullToRefresh>
    </div>
  );
};

export default DashboardLayout;
