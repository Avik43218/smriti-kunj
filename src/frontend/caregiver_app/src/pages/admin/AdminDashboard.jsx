import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { getCaregivers, getAllPatients } from '../../services/adminService';
import {
  ShieldAlert,
  Users,
  UserCheck,
  HeartHandshake,
  UserPlus,
  ChevronRight,
  RefreshCw,
  Search,
  AlertTriangle,
} from 'lucide-react';

export const AdminDashboard = () => {
  const { user } = useAuth();
  const [caregivers, setCaregivers] = useState([]);
  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [cgData, ptData] = await Promise.all([
        getCaregivers(),
        getAllPatients(),
      ]);
      setCaregivers(cgData || []);
      setPatients(ptData || []);
    } catch (err) {
      setError(err?.message || 'Failed to load administrative overview.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    document.title = 'Smriti Kunj | Admin Portal';
    return () => { document.title = 'Smriti Kunj | Caregiver Portal'; };
  }, []);

  const totalCaregivers = caregivers.length;
  const activeCaregivers = caregivers.filter((c) => c.status === 'active').length;
  const totalPatients = patients.length;
  const alertPatients = patients.filter((p) => p.status === 'alert' || p.status === 'reminder_missed').length;

  return (
    <div className="space-y-6 sm:space-y-8 font-sans">
      {/* Header Banner */}
      <header className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-4 border-b border-border/60 dark:border-ink-soft/30 pb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-card bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shadow-xs">
            <ShieldAlert className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-baseline gap-2.5">
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream">
                Admin Control Center
              </h1>
              <span className="text-xs px-2.5 py-0.5 rounded-full font-semibold bg-terracotta/15 text-terracotta border border-terracotta/30">
                Tier 1 Administration
              </span>
            </div>
            <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-0.5">
              Smriti Kunj Platform Operations &bull; Cross-caregiver oversight &amp; patient distribution
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <button
            type="button"
            onClick={loadData}
            disabled={loading}
            aria-label="Refresh administrative overview"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            <RefreshCw className={`w-3.5 h-3.5 text-terracotta ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>
          <Link
            to="/admin/caregivers"
            className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-terracotta hover:bg-terracotta-dark text-cream text-xs sm:text-sm font-medium rounded-xl shadow-xs transition-colors shrink-0 outline-none focus-visible:ring-2 focus-visible:ring-terracotta/40"
          >
            <UserPlus className="w-4 h-4" />
            <span>Manage Caregivers</span>
          </Link>
        </div>
      </header>

      {error && (
        <div className="p-3.5 rounded-card bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2.5">
          <AlertTriangle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Metric Cards Grid - 3 evenly distributed cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Card 1: Total Caregivers */}
        <div className="p-5 sm:p-6 rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 shadow-sm transition-colors flex items-center justify-between">
          <div>
            <p className="text-xs sm:text-sm font-medium text-ink-soft dark:text-cream/70">Total Caregivers</p>
            <p className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream mt-1">{totalCaregivers}</p>
            <p className="text-xs text-sage font-medium mt-0.5">{activeCaregivers} active on roster</p>
          </div>
          <div className="w-10 h-10 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-ink-soft dark:text-cream/70 shadow-xs">
            <Users className="w-5 h-5 text-terracotta" />
          </div>
        </div>

        {/* Card 2: Total Patients */}
        <div className="p-5 sm:p-6 rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 shadow-sm transition-colors flex items-center justify-between">
          <div>
            <p className="text-xs sm:text-sm font-medium text-ink-soft dark:text-cream/70">Monitored Patients</p>
            <p className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream mt-1">{totalPatients}</p>
            <p className="text-xs text-ink-soft dark:text-cream/60 mt-0.5">Across all facilities</p>
          </div>
          <div className="w-10 h-10 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-ink-soft dark:text-cream/70 shadow-xs">
            <HeartHandshake className="w-5 h-5 text-terracotta" />
          </div>
        </div>

        {/* Card 3: Status Alerts */}
        <div className="p-5 sm:p-6 rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 shadow-sm transition-colors flex items-center justify-between">
          <div>
            <p className="text-xs sm:text-sm font-medium text-ink-soft dark:text-cream/70">Compliance Alerts</p>
            <p className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream mt-1">{alertPatients}</p>
            <p className="text-xs text-alert font-medium mt-0.5">Patients needing check-in</p>
          </div>
          <div className="w-10 h-10 rounded-full bg-alert/10 border border-alert/20 flex items-center justify-center text-alert shadow-xs">
            <AlertTriangle className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Quick Access Action Panels */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Link
          to="/admin/caregivers"
          className="group p-6 rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 hover:border-terracotta/50 dark:hover:border-terracotta/50 shadow-sm hover:shadow-md transition-all flex items-start justify-between"
        >
          <div className="space-y-1.5">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta">
                <UserCheck className="w-4 h-4" />
              </div>
              <h2 className="text-base sm:text-lg font-bold text-ink dark:text-cream group-hover:text-terracotta transition-colors">
                Manage Caregiver Roster
              </h2>
            </div>
            <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 leading-relaxed">
              Create caregiver logins directly without OTP verification, disable accounts, and monitor patient assignment counts.
            </p>
          </div>
          <div className="w-8 h-8 rounded-full bg-cream/60 dark:bg-ink-soft/20 border border-border/60 dark:border-ink-soft/30 flex items-center justify-center text-ink-soft dark:text-cream/70 group-hover:text-terracotta group-hover:bg-cream dark:group-hover:bg-ink-soft/40 group-hover:translate-x-0.5 transition-all shrink-0">
            <ChevronRight className="w-4 h-4" />
          </div>
        </Link>

        <Link
          to="/admin/patients"
          className="group p-6 rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 hover:border-terracotta/50 dark:hover:border-terracotta/50 shadow-sm hover:shadow-md transition-all flex items-start justify-between"
        >
          <div className="space-y-1.5">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta">
                <HeartHandshake className="w-4 h-4" />
              </div>
              <h2 className="text-base sm:text-lg font-bold text-ink dark:text-cream group-hover:text-terracotta transition-colors">
                Cross-Caregiver Patient Directory
              </h2>
            </div>
            <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 leading-relaxed">
              View all patients system-wide and reassign patients seamlessly when caregiver caseloads change or shift rotations occur.
            </p>
          </div>
          <div className="w-8 h-8 rounded-full bg-cream/60 dark:bg-ink-soft/20 border border-border/60 dark:border-ink-soft/30 flex items-center justify-center text-ink-soft dark:text-cream/70 group-hover:text-terracotta group-hover:bg-cream dark:group-hover:bg-ink-soft/40 group-hover:translate-x-0.5 transition-all shrink-0">
            <ChevronRight className="w-4 h-4" />
          </div>
        </Link>
      </div>

      {/* Caregiver Overview Preview */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta">
              <Users className="w-4 h-4" />
            </div>
            <h2 className="text-lg sm:text-xl font-bold text-ink dark:text-cream">
              Caregiver Roster Snapshot
            </h2>
          </div>
          <Link
            to="/admin/caregivers"
            className="text-xs sm:text-sm font-semibold text-terracotta hover:underline"
          >
            View all ({totalCaregivers})
          </Link>
        </div>

        <div className="rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 shadow-sm overflow-hidden transition-colors">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs sm:text-sm">
              <thead className="bg-cream/40 dark:bg-ink-soft/30 border-b border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/70 text-xs font-semibold">
                <tr>
                  <th className="py-3 px-4">Caregiver Name</th>
                  <th className="py-3 px-4">Email</th>
                  <th className="py-3 px-4">Language</th>
                  <th className="py-3 px-4 text-center">Status</th>
                  <th className="py-3 px-4 text-right">Assigned Patients</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/60 dark:divide-ink-soft/30 text-ink dark:text-cream">
                {caregivers.slice(0, 5).map((cg) => (
                  <tr key={cg.id} className="hover:bg-cream/30 dark:hover:bg-ink-soft/10 transition-colors">
                    <td className="py-3 px-4 font-semibold">{cg.name}</td>
                    <td className="py-3 px-4 text-ink-soft dark:text-cream/70">{cg.email}</td>
                    <td className="py-3 px-4 uppercase text-xs font-mono">{cg.region_language || 'en'}</td>
                    <td className="py-3 px-4 text-center">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold ${
                          cg.status === 'active'
                            ? 'bg-sage/15 text-sage border border-sage/30'
                            : 'bg-alert/15 text-alert border border-alert/30'
                        }`}
                      >
                        {cg.status === 'active' ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right font-semibold">
                      <span className="px-2.5 py-0.5 rounded-md bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 text-xs">
                        {cg.patient_count ?? 0}
                      </span>
                    </td>
                  </tr>
                ))}
                {caregivers.length === 0 && !loading && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-ink-soft dark:text-cream/60">
                      No caregivers provisioned yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </div>
  );
};

export default AdminDashboard;
