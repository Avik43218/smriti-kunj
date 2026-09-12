import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { getAllPatients, getCaregivers, reassignPatient } from '../../services/adminService';
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
      {/* Top Header */}
      <header className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border/60 dark:border-ink-soft/30 pb-4">
        <div>
          <div className="flex items-center gap-2 text-xs font-semibold text-terracotta mb-1">
            <Link to="/admin/dashboard" className="flex items-center gap-1 hover:underline">
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>Back to Admin Center</span>
            </Link>
          </div>
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
            className="inline-flex items-center gap-2 px-3.5 py-2 text-xs font-medium rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 text-ink dark:text-cream hover:bg-cream/80 transition-colors"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh Roster</span>
          </button>
        </div>
      </header>

      {/* Notifications */}
      {successMessage && (
        <div className="p-3 rounded-card bg-sage/10 border border-sage/30 text-sage text-xs flex items-center justify-between">
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
        <div className="p-3 rounded-card bg-alert/10 border border-alert/30 text-alert text-xs flex items-center justify-between">
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
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-soft dark:text-cream/50 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search patients by name, patient code, diagnosis, or caregiver..."
            className="w-full pl-10 pr-4 py-2 text-xs rounded-full bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:border-terracotta transition-colors shadow-xs"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-soft hover:text-ink dark:hover:text-cream"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-ink-soft dark:text-cream/60 shrink-0" />
          <select
            value={caregiverFilter}
            onChange={(e) => setCaregiverFilter(e.target.value)}
            className="w-full sm:w-auto px-3 py-2 text-xs rounded-full bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 text-ink dark:text-cream focus:outline-none focus:border-terracotta shadow-xs"
          >
            <option value="all">All Caregivers ({patients.length})</option>
            {caregivers.map((cg) => (
              <option key={cg.id} value={cg.id}>
                {cg.name} ({cg.patient_count ?? 0})
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Patients Table Card */}
      <div className="rounded-card bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-cream/60 dark:bg-ink-soft/20 border-b border-border dark:border-ink-soft/40 text-ink-soft dark:text-cream/70">
              <tr>
                <th className="py-3 px-4 font-semibold">Patient Name &amp; Code</th>
                <th className="py-3 px-4 font-semibold">Diagnosis</th>
                <th className="py-3 px-4 font-semibold">Current Caregiver</th>
                <th className="py-3 px-4 font-semibold text-center">Status</th>
                <th className="py-3 px-4 font-semibold">Hardware / Tablet</th>
                <th className="py-3 px-4 font-semibold text-right">Reassign</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60 dark:divide-ink-soft/30 text-ink dark:text-cream">
              {filteredPatients.map((patient) => (
                <tr key={patient.id || patient.uuid_id} className="hover:bg-cream/30 dark:hover:bg-ink-soft/10 transition-colors">
                  <td className="py-3.5 px-4">
                    <div className="flex items-center gap-2.5">
                      <div className="w-7 h-7 rounded-full bg-terracotta/15 text-terracotta font-bold flex items-center justify-center text-xs">
                        {patient.name ? patient.name[0].toUpperCase() : 'P'}
                      </div>
                      <div>
                        <div className="font-semibold text-ink dark:text-cream">{patient.name}</div>
                        <div className="text-[10px] text-ink-soft dark:text-cream/60 font-mono">
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

                  <td className="py-3.5 px-4 font-mono text-[11px] text-ink-soft dark:text-cream/70">
                    <div className="flex items-center gap-1">
                      <Tablet className="w-3 h-3 text-ink-soft/70" />
                      <span>{patient.device_id || 'Tablet Not Linked'}</span>
                    </div>
                  </td>

                  <td className="py-3.5 px-4 text-right">
                    <button
                      type="button"
                      onClick={() => handleOpenReassignModal(patient)}
                      className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-cream dark:bg-ink-soft/30 hover:bg-terracotta hover:text-cream text-ink dark:text-cream border border-border dark:border-ink-soft/40 transition-colors font-medium text-[11px]"
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
          <div className="w-full max-w-md bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 rounded-card shadow-card p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-3">
              <div className="flex items-center gap-2">
                <ArrowRightLeft className="w-5 h-5 text-terracotta" />
                <h3 className="text-base font-bold text-ink dark:text-cream">Reassign Patient Caregiver</h3>
              </div>
              <button
                onClick={() => setReassignTarget(null)}
                className="text-ink-soft hover:text-ink dark:hover:text-cream"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {reassignError && (
              <div className="p-3 rounded-md bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{reassignError}</span>
              </div>
            )}

            <div className="p-3 rounded-md bg-cream/50 dark:bg-ink-soft/20 text-xs space-y-1">
              <div>
                <span className="text-ink-soft dark:text-cream/60">Patient: </span>
                <strong className="text-ink dark:text-cream">{reassignTarget.name}</strong>{' '}
                <span className="font-mono text-ink-soft">({reassignTarget.patient_code || reassignTarget.id})</span>
              </div>
              <div>
                <span className="text-ink-soft dark:text-cream/60">Current Assigned Caregiver: </span>
                <span className="font-semibold text-terracotta">
                  {reassignTarget.caregiver_name || 'None / Unassigned'}
                </span>
              </div>
            </div>

            <form onSubmit={handleReassignSubmit} className="space-y-4 text-xs">
              <div>
                <label className="block font-semibold text-ink dark:text-cream mb-1.5">
                  Select New Primary Caregiver
                </label>
                <select
                  required
                  value={selectedCaregiverId}
                  onChange={(e) => setSelectedCaregiverId(e.target.value)}
                  className="w-full px-3 py-2 rounded-md bg-cream/40 dark:bg-ink-soft/20 border border-border dark:border-ink-soft/40 text-ink dark:text-cream focus:outline-none focus:border-terracotta"
                >
                  <option value="" disabled>-- Select a caregiver --</option>
                  {caregivers
                    .filter((cg) => cg.status === 'active')
                    .map((cg) => (
                      <option key={cg.id} value={cg.id}>
                        {cg.name} ({cg.email}) &bull; {cg.patient_count ?? 0} current patients
                      </option>
                    ))}
                </select>
                <p className="text-[11px] text-ink-soft dark:text-cream/60 mt-1">
                  Only active caregivers are eligible to accept patient reassignment.
                </p>
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-border/60 dark:border-ink-soft/30">
                <button
                  type="button"
                  onClick={() => setReassignTarget(null)}
                  className="px-3.5 py-1.5 rounded-full border border-border dark:border-ink-soft/40 text-ink-soft dark:text-cream/70 hover:bg-cream/40"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={reassignSubmitting || !selectedCaregiverId}
                  className="px-4 py-1.5 rounded-full bg-terracotta text-cream font-semibold hover:bg-terracotta/90 shadow-xs transition-all"
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
