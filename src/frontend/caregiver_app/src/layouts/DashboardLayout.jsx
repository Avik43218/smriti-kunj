import React from 'react';
import { Outlet } from 'react-router-dom';
import { TopControls } from '../components/TopControls';
import { Footer } from '../components/Footer';
import { MotifBackground } from '../components/MotifBackground';

export const DashboardLayout = () => {
  return (
    <div className="min-h-screen bg-cream dark:bg-ink text-ink dark:text-cream font-sans transition-colors duration-200 flex flex-col relative">
      {/* Ambient Cultural Motif Background Pattern */}
      <MotifBackground />

      {/* Persistent Top-Right Controls: Profile Chip + Language, Theme, Notifications, Settings */}
      <TopControls showSettings={true} showProfile={true} />

      {/* Main Content Area */}
      <main className="flex-1 w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-16 sm:pt-20 pb-12 sm:pb-16 relative z-10">
        <Outlet />
      </main>

      {/* Site Identity Footer */}
      <Footer />
    </div>
  );
};

export default DashboardLayout;
