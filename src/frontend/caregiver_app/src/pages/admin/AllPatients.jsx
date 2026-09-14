import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { getAllPatients, getCaregivers, reassignPatient } from '../../services/adminService';
import { StyledSelect } from '../../components/StyledSelect';
import {
  HeartHandshake,
  Search,
  Filter,
  ArrowRightLeft,
  CheckCircle,
  AlertCircle,
  RefreshCw,
  X,
  ArrowLeft,
  Tablet,
  User,
} from 'lucide-react';

export const AllPatients = () => {
  const [patients, setPatients] = useState([]);
  const [caregivers, setCaregivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [caregiverFilter, setCaregiverFilter] = useState('all');

  // Reassignment Modal state
  const [reassignTarget, setReassignTarget] = useState(null);
  const [selectedCaregiverId, setSelectedCaregiverId] = useState('');
  const [reassignSubmitting, setReassignSubmitting] = useState(false);
  const [reassignError, setReassignError] = useState(null);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [ptData, cgData] = await Promise.all([
        getAllPatients(),
        getCaregivers(),
      ]);
      setPatients(ptData || []);
      setCaregivers(cgData || []);
    } catch (err) {
      setError(err?.message || 'Failed to load system-wide patient roster.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const filteredPatients = useMemo(() => {
    return patients.filter((patient) => {
      // Caregiver filter
      if (caregiverFilter !== 'all') {
        if (String(patient.caregiver_id) !== String(caregiverFilter)) {
          return false;
        }
      }

      // Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const matchesName = patient.name?.toLowerCase().includes(q);
        const matchesCode = patient.patient_code?.toLowerCase().includes(q) || patient.id?.toLowerCase().includes(q);
        const matchesDiagnosis = patient.diagnosis?.toLowerCase().includes(q);
        const matchesCg = patient.caregiver_name?.toLowerCase().includes(q);
        return matchesName || matchesCode || matchesDiagnosis || matchesCg;
      }

      return true;
    });
  }, [patients, caregiverFilter, searchQuery]);

  const handleOpenReassignModal = (patient) => {
    setReassignTarget(patient);
    setSelectedCaregiverId(patient.caregiver_id ? String(patient.caregiver_id) : '');
    setReassignError(null);
  };

  const handleReassignSubmit = async (e) => {
    e.preventDefault();
    if (!reassignTarget || !selectedCaregiverId) return;

    setReassignSubmitting(true);
    setReassignError(null);
    try {
      await reassignPatient(reassignTarget.id || reassignTarget.uuid_id, selectedCaregiverId);
      const targetCg = caregivers.find((c) => String(c.id) === String(selectedCaregiverId));
      setSuccessMessage(
        `Patient "${reassignTarget.name}" successfully reassigned to ${targetCg?.name || 'new caregiver'}.`
      );
      setReassignTarget(null);
      await loadData();
    } catch (err) {
      setReassignError(err?.message || 'Failed to reassign patient.');
    } finally {
      setReassignSubmitting(false);
    }
  };

  return (
    <div className="space-y-6 sm:space-y-8 font-sans">
      {/* Return to Admin Dashboard Button (Matches PatientLayout All Patients floating pill button) */}
      <Link
        to="/admin/dashboard"
        aria-label="Back to Admin Dashboard"
        className="fixed top-3.5 left-3.5 sm:top-5 sm:left-6 z-40 inline-flex items-center justify-center gap-1.5 w-8 h-8 sm:w-auto sm:h-auto sm:px-3.5 sm:py-2 bg-surface/90 dark:bg-ink/90 backdrop-blur-md border border-border/80 dark:border-ink-soft/40 rounded-full shadow-md text-xs sm:text-sm font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all select-none outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
      >
        <ArrowLeft className="w-4 h-4 text-terracotta shrink-0" />
        <span className="hidden sm:inline">Back to Admin</span>
      </Link>

      {/* Top Header */}
      <header className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border/60 dark:border-ink-soft/30 pb-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream">
            Cross-Caregiver Patients
          </h1>
          <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-0.5">
            System-wide visibility across all patients and dynamic caregiver caseload reassignment.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={loadData}
            disabled={loading}
            aria-label="Refresh patient roster"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            <RefreshCw className={`w-3.5 h-3.5 text-terracotta ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh Roster</span>
          </button>
        </div>
      </header>

      {/* Notifications */}
      {successMessage && (
        <div className="p-3.5 rounded-card bg-sage/10 border border-sage/30 text-sage text-xs flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CheckCircle className="w-4 h-4 shrink-0" />
            <span>{successMessage}</span>
          </div>
          <button onClick={() => setSuccessMessage(null)} className="p-1 hover:opacity-75">
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {error && (
        <div className="p-3.5 rounded-card bg-alert/10 border border-alert/30 text-alert text-xs flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{error}</span>
          </div>
          <button onClick={() => setError(null)} className="p-1 hover:opacity-75">
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {/* Search & Filter Controls */}
      <div className="flex flex-col sm:flex-row items-center gap-3">
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 text-ink-soft/70 dark:text-cream/50 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search patients by name, patient code, diagnosis, or caregiver..."
            className="w-full pl-9 pr-8 py-2 bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors shadow-xs"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => setSearchQuery('')}
              aria-label="Clear search"
              className="absolute right-2.5 top-1/2 -translate-y-1/2 p-0.5 text-ink-soft hover:text-ink dark:text-cream/60 dark:hover:text-cream transition-colors"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-ink-soft dark:text-cream/60 shrink-0" />
          <StyledSelect
            value={caregiverFilter}
            onChange={(val) => setCaregiverFilter(val)}
            options={[
              { value: 'all', label: `All Caregivers (${patients.length})` },
              ...caregivers.map((cg) => ({
                value: String(cg.id),
                label: `${cg.name} (${cg.patient_count ?? 0})`,
              })),
            ]}
            className="w-full sm:w-56"
          />
        </div>
      </div>

      {/* Patients Table Card */}
      <div className="rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 shadow-sm overflow-hidden transition-colors">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs sm:text-sm">
            <thead className="bg-cream/40 dark:bg-ink-soft/30 border-b border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/70 text-xs font-semibold">
              <tr>
                <th className="py-3 px-4">Patient Name &amp; Code</th>
                <th className="py-3 px-4">Diagnosis</th>
                <th className="py-3 px-4">Current Caregiver</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4">Hardware / Tablet</th>
                <th className="py-3 px-4 text-right">Reassign</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60 dark:divide-ink-soft/30 text-ink dark:text-cream">
              {filteredPatients.map((patient) => (
                <tr key={patient.id || patient.uuid_id} className="hover:bg-cream/30 dark:hover:bg-ink-soft/10 transition-colors">
                  <td className="py-3.5 px-4">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 rounded-full bg-terracotta/15 text-terracotta font-bold flex items-center justify-center text-xs shadow-xs">
                        {patient.name ? patient.name[0].toUpperCase() : 'P'}
                      </div>
                      <div>
                        <div className="font-semibold text-ink dark:text-cream">{patient.name}</div>
                        <div className="text-[11px] text-ink-soft dark:text-cream/60 font-mono">
                          Code: {patient.patient_code || String(patient.id).slice(0, 8)}
                        </div>
                      </div>
                    </div>
                  </td>

                  <td className="py-3.5 px-4 text-ink-soft dark:text-cream/80 max-w-[200px] truncate">
                    {patient.diagnosis || 'Dementia / Memory Care'}
                  </td>

                  <td className="py-3.5 px-4">
                    <div className="flex items-center gap-1.5 font-medium">
                      <User className="w-3.5 h-3.5 text-terracotta" />
                      <span>{patient.caregiver_name || 'Unassigned Caregiver'}</span>
                    </div>
                  </td>

                  <td className="py-3.5 px-4 text-center">
                    <span
                      className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold ${
                        patient.status === 'normal' || patient.status === 'stable'
                          ? 'bg-sage/15 text-sage border border-sage/30'
                          : patient.status === 'alert'
                          ? 'bg-alert/15 text-alert border border-alert/30'
                          : 'bg-gold/15 text-gold border border-gold/30'
                      }`}
                    >
                      {patient.status_label || patient.status || 'Active'}
                    </span>
                  </td>

                  <td className="py-3.5 px-4 font-mono text-xs text-ink-soft dark:text-cream/70">
                    <div className="flex items-center gap-1.5">
                      <Tablet className="w-3.5 h-3.5 text-ink-soft/70" />
                      <span>{patient.device_id || 'Tablet Not Linked'}</span>
                    </div>
                  </td>

                  <td className="py-3.5 px-4 text-right">
                    <button
                      type="button"
                      onClick={() => handleOpenReassignModal(patient)}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-cream dark:bg-ink-soft/30 hover:bg-terracotta hover:text-cream text-ink dark:text-cream border border-border/80 dark:border-ink-soft/40 transition-colors font-medium text-xs shadow-xs"
                    >
                      <ArrowRightLeft className="w-3 h-3" />
                      <span>Reassign</span>
                    </button>
                  </td>
                </tr>
              ))}
              {filteredPatients.length === 0 && !loading && (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-ink-soft dark:text-cream/60">
                    No patients match your filter criteria.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Reassignment Modal */}
      {reassignTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink/60 backdrop-blur-xs animate-in fade-in duration-150">
          <div className="w-full max-w-md bg-surface dark:bg-ink-soft/20 backdrop-blur-2xl border border-border/80 dark:border-ink-soft/40 rounded-card shadow-card p-6 sm:p-7 space-y-4">
            <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-3">
              <div className="flex items-center gap-2">
                <ArrowRightLeft className="w-5 h-5 text-terracotta" />
                <h3 className="text-base sm:text-lg font-bold text-ink dark:text-cream">Reassign Patient Caregiver</h3>
              </div>
              <button
                onClick={() => setReassignTarget(null)}
                className="text-ink-soft hover:text-ink dark:hover:text-cream transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {reassignError && (
              <div className="p-3 rounded-lg bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{reassignError}</span>
              </div>
            )}

            <div className="p-3.5 rounded-xl bg-cream/70 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 text-xs sm:text-sm space-y-1">
              <div>
                <span className="text-ink-soft dark:text-cream/60">Patient: </span>
                <strong className="text-ink dark:text-cream">{reassignTarget.name}</strong>{' '}
                <span className="font-mono text-ink-soft dark:text-cream/50">({reassignTarget.patient_code || reassignTarget.id})</span>
              </div>
              <div>
                <span className="text-ink-soft dark:text-cream/60">Current Assigned Caregiver: </span>
                <span className="font-semibold text-terracotta">
                  {reassignTarget.caregiver_name || 'None / Unassigned'}
                </span>
              </div>
            </div>

            <form onSubmit={handleReassignSubmit} className="space-y-4 text-xs sm:text-sm">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1.5">
                  Select New Primary Caregiver
                </label>
                <StyledSelect
                  value={selectedCaregiverId}
                  onChange={(val) => setSelectedCaregiverId(val)}
                  placeholder="-- Select a caregiver --"
                  options={caregivers
                    .filter((cg) => cg.status === 'active')
                    .map((cg) => ({
                      value: String(cg.id),
                      label: `${cg.name} (${cg.email}) • ${cg.patient_count ?? 0} current patients`,
                    }))}
                />
                <p className="text-[11px] text-ink-soft dark:text-cream/60 mt-1">
                  Only active caregivers are eligible to accept patient reassignment.
                </p>
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-border/60 dark:border-ink-soft/30">
                <button
                  type="button"
                  onClick={() => setReassignTarget(null)}
                  className="px-4 py-2 rounded-full border border-border/80 dark:border-ink-soft/40 text-xs font-medium text-ink-soft dark:text-cream/70 hover:bg-cream dark:hover:bg-ink-soft/30 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={reassignSubmitting || !selectedCaregiverId}
                  className="px-4 py-2 rounded-full bg-terracotta hover:bg-terracotta-dark text-cream text-xs font-semibold shadow-xs transition-colors focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                >
                  {reassignSubmitting ? 'Transferring...' : 'Confirm Reassignment'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default AllPatients;
