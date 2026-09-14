import React, { useState, useEffect, useMemo } from 'react';
import {
  Users,
  AlertTriangle,
  Activity,
  CheckCircle2,
  Search,
  X,
  ArrowUpDown,
  RefreshCw,
  Cpu,
  ShieldAlert,
} from 'lucide-react';
import { fetchPatientRiskOverview, RISK_LEVEL_CONFIG } from '../services/riskService';

/**
 * PatientRiskOverviewTable
 *
 * Displays real-time XGBoost risk grades for all patients assigned to the logged-in caregiver.
 * Data flow: authenticated caregiver → backend queries GameSessions, DriftMetric, Alerts
 * → 5 features piped through xgboost_patient_risk_model.pkl → graded JSON rendered here.
 *
 * Features:
 *  - Summary metric cards: Total, High (Grade 2), Moderate (Grade 1), Low (Grade 0)
 *  - Risk filter tabs, name/ID search, sort by risk level & active alerts
 *  - Strictly 6-column table capped at 5 visible rows with internal scroll
 *    1. Patient ID / Code  2. Patient Name  3. Age & Gender
 *    4. Active Alerts Count  5. Risk Level Badge  6. Recommended Action
 */
export const PatientRiskOverviewTable = () => {
  const [data, setData] = useState({
    summary: { total_patients: 0, high_risk_count: 0, moderate_risk_count: 0, low_risk_count: 0 },
    patients: [],
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [riskFilter, setRiskFilter] = useState('all');
  const [sortBy, setSortBy] = useState('risk_desc');

  const loadRiskEvaluations = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await fetchPatientRiskOverview();
      setData(res);
    } catch (err) {
      setError(err?.message || 'Failed to load risk evaluations.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadRiskEvaluations();
  }, []);

  const filteredAndSortedPatients = useMemo(() => {
    let result = [...data.patients];

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter(
        (p) => p.name?.toLowerCase().includes(q) || p.patient_id?.toLowerCase().includes(q)
      );
    }

    if (riskFilter === 'high') result = result.filter((p) => p.risk_grade === 2);
    else if (riskFilter === 'moderate') result = result.filter((p) => p.risk_grade === 1);
    else if (riskFilter === 'low') result = result.filter((p) => p.risk_grade === 0);

    result.sort((a, b) => {
      if (sortBy === 'risk_desc') return b.risk_grade - a.risk_grade || b.active_alerts_count - a.active_alerts_count;
      if (sortBy === 'risk_asc') return a.risk_grade - b.risk_grade || a.active_alerts_count - b.active_alerts_count;
      if (sortBy === 'alerts_desc') return b.active_alerts_count - a.active_alerts_count || b.risk_grade - a.risk_grade;
      if (sortBy === 'alerts_asc') return a.active_alerts_count - b.active_alerts_count || a.risk_grade - b.risk_grade;
      return 0;
    });

    return result;
  }, [data.patients, searchQuery, riskFilter, sortBy]);

  const summary = data.summary;

  return (
    <section
      aria-label="XGBoost Patient Risk Overview"
      className="bg-surface dark:bg-ink-soft/10 rounded-card border border-border/90 dark:border-ink-soft/40 shadow-xs overflow-hidden"
    >
      {/* Header */}
      <div className="px-4 py-3 border-b border-border/70 dark:border-ink-soft/30 bg-cream/40 dark:bg-ink-soft/20 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-start gap-3">
          <div className="w-8 h-8 rounded-lg bg-terracotta/10 dark:bg-terracotta/20 border border-terracotta/25 flex items-center justify-center text-terracotta shrink-0">
            <Cpu className="w-4 h-4" />
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h3 className="text-sm font-bold text-ink dark:text-cream">
                Real-Time Patient Risk Grading
              </h3>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-500/20">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                xgboost_patient_risk_model.pkl
              </span>
            </div>
            <p className="text-[11px] text-ink-soft dark:text-cream/70 mt-0.5">
              Age · Accuracy · Latency · 7-day Drift · Alert Density — live from your patient records.
            </p>
          </div>
        </div>

        <button
          type="button"
          onClick={loadRiskEvaluations}
          disabled={loading}
          aria-label="Re-run real-time model inference"
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream bg-surface dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 hover:bg-cream dark:hover:bg-ink-soft/50 shadow-2xs transition-all active:scale-95 disabled:opacity-50 shrink-0"
        >
          <RefreshCw className={`w-3 h-3 text-terracotta ${loading ? 'animate-spin' : ''}`} />
          Re-run
        </button>
      </div>

      {/* Summary Metric Cards */}
      <div className="px-4 py-3 grid grid-cols-2 lg:grid-cols-4 gap-2.5">
        {/* Total */}
        <div className="p-3 rounded-xl bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 flex flex-col gap-1.5">
          <div className="flex items-center justify-between text-ink-soft dark:text-cream/70">
            <span className="text-[11px] font-medium">Total Monitored</span>
            <Users className="w-3.5 h-3.5" />
          </div>
          <span className="text-xl font-bold text-ink dark:text-cream">
            {loading ? '—' : summary.total_patients}
          </span>
          <span className="text-[10px] text-ink-soft/80 dark:text-cream/50">Active cohort</span>
        </div>

        {/* High Risk */}
        <div className="p-3 rounded-xl bg-[#e74c3c]/6 border border-[#e74c3c]/25 flex flex-col gap-1.5">
          <div className="flex items-center justify-between text-[#e74c3c]">
            <span className="text-[11px] font-semibold">High Risk</span>
            <AlertTriangle className="w-3.5 h-3.5" />
          </div>
          <div className="flex items-baseline gap-1.5">
            <span className="text-xl font-bold text-[#e74c3c]">
              {loading ? '—' : summary.high_risk_count}
            </span>
            <span className="text-[10px] font-bold uppercase px-1.5 py-0.5 rounded bg-[#e74c3c]/15 text-[#e74c3c]">
              Grade 2
            </span>
          </div>
          <span className="text-[10px] font-medium text-[#e74c3c]/90">Immediate Intervention</span>
        </div>

        {/* Moderate Risk */}
        <div className="p-3 rounded-xl bg-[#f39c12]/6 border border-[#f39c12]/25 flex flex-col gap-1.5">
          <div className="flex items-center justify-between text-[#f39c12]">
            <span className="text-[11px] font-semibold">Moderate Risk</span>
            <Activity className="w-3.5 h-3.5" />
          </div>
          <div className="flex items-baseline gap-1.5">
            <span className="text-xl font-bold text-[#f39c12]">
              {loading ? '—' : summary.moderate_risk_count}
            </span>
            <span className="text-[10px] font-bold uppercase px-1.5 py-0.5 rounded bg-[#f39c12]/15 text-[#f39c12]">
              Grade 1
            </span>
          </div>
          <span className="text-[10px] font-medium text-[#f39c12]/90">Adapt Difficulty</span>
        </div>

        {/* Low Risk */}
        <div className="p-3 rounded-xl bg-[#2ecc71]/6 border border-[#2ecc71]/25 flex flex-col gap-1.5">
          <div className="flex items-center justify-between text-[#2ecc71]">
            <span className="text-[11px] font-semibold">Low Risk</span>
            <CheckCircle2 className="w-3.5 h-3.5" />
          </div>
          <div className="flex items-baseline gap-1.5">
            <span className="text-xl font-bold text-[#2ecc71]">
              {loading ? '—' : summary.low_risk_count}
            </span>
            <span className="text-[10px] font-bold uppercase px-1.5 py-0.5 rounded bg-[#2ecc71]/15 text-[#2ecc71]">
              Grade 0
            </span>
          </div>
          <span className="text-[10px] font-medium text-[#2ecc71]/90">Routine Check</span>
        </div>
      </div>

      {/* Table Controls: Search + Filter Tabs + Sort */}
      <div className="px-4 pb-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 border-b border-border/70 dark:border-ink-soft/30">
        {/* Search */}
        <div className="relative flex-1 max-w-xs">
          <Search className="w-3.5 h-3.5 text-ink-soft/70 dark:text-cream/50 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by name or Patient ID..."
            className="w-full pl-8 pr-7 py-1.5 bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-lg text-xs text-ink dark:text-cream placeholder:text-ink-soft/60 dark:placeholder:text-cream/40 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => setSearchQuery('')}
              aria-label="Clear search"
              className="absolute right-2 top-1/2 -translate-y-1/2 text-ink-soft hover:text-ink dark:text-cream/60 dark:hover:text-cream"
            >
              <X className="w-3 h-3" />
            </button>
          )}
        </div>

        {/* Filter tabs + sort */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Filter tabs */}
          <div className="flex items-center gap-0.5 bg-cream/70 dark:bg-ink-soft/30 p-0.5 rounded-lg border border-border/70 dark:border-ink-soft/30 select-none">
            {[
              { key: 'all', label: `All (${summary.total_patients})`, color: null },
              { key: 'high', label: `High (${summary.high_risk_count})`, color: '#e74c3c' },
              { key: 'moderate', label: `Mod (${summary.moderate_risk_count})`, color: '#f39c12' },
              { key: 'low', label: `Low (${summary.low_risk_count})`, color: '#2ecc71' },
            ].map(({ key, label, color }) => (
              <button
                key={key}
                type="button"
                onClick={() => setRiskFilter(key)}
                className="px-2.5 py-1 rounded-md text-[11px] font-semibold transition-all"
                style={
                  riskFilter === key && color
                    ? { backgroundColor: color, color: '#fff' }
                    : riskFilter === key
                    ? { backgroundColor: 'var(--color-surface, #fff)', color: 'var(--color-ink, #222)' }
                    : { color: color || 'var(--color-ink-soft, #888)' }
                }
              >
                {label}
              </button>
            ))}
          </div>

          {/* Sort */}
          <div className="flex items-center gap-1">
            <ArrowUpDown className="w-3 h-3 text-ink-soft/70 dark:text-cream/50 shrink-0" />
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-ink dark:text-cream text-[11px] rounded-lg px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-terracotta"
            >
              <option value="risk_desc">Risk: High → Low</option>
              <option value="risk_asc">Risk: Low → High</option>
              <option value="alerts_desc">Alerts: Most → Least</option>
              <option value="alerts_asc">Alerts: Least → Most</option>
            </select>
          </div>
        </div>
      </div>

      {/* Table — capped at 5 rows with internal vertical scroll */}
      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse min-w-[700px]">
          <thead className="sticky top-0 z-10">
            <tr className="border-b border-border/80 dark:border-ink-soft/40 bg-cream/40 dark:bg-ink-soft/25 text-[10px] font-bold text-ink-soft dark:text-cream/70 uppercase tracking-wider select-none">
              <th scope="col" className="py-2.5 px-3 sm:px-4">Patient ID</th>
              <th scope="col" className="py-2.5 px-3">Patient Name</th>
              <th scope="col" className="py-2.5 px-3">Age & Gender</th>
              <th scope="col" className="py-2.5 px-3 text-center">Active Alerts</th>
              <th scope="col" className="py-2.5 px-3">Risk Level</th>
              <th scope="col" className="py-2.5 px-3 sm:px-4">Recommended Action</th>
            </tr>
          </thead>
        </table>
        {/* Scrollable tbody container — max 5 rows (~48px each) */}
        <div className="overflow-y-auto" style={{ maxHeight: '240px' }}>
          <table className="w-full text-left border-collapse min-w-[700px]">
            <tbody className="divide-y divide-border/60 dark:divide-ink-soft/20 text-xs">
              {/* Loading skeleton */}
              {loading &&
                [1, 2, 3].map((idx) => (
                  <tr key={idx} className="animate-pulse">
                    <td className="py-3 px-3 sm:px-4"><div className="h-3.5 w-14 bg-cream dark:bg-ink-soft/30 rounded" /></td>
                    <td className="py-3 px-3"><div className="h-3.5 w-24 bg-cream dark:bg-ink-soft/30 rounded" /></td>
                    <td className="py-3 px-3"><div className="h-3.5 w-16 bg-cream dark:bg-ink-soft/30 rounded" /></td>
                    <td className="py-3 px-3 text-center"><div className="h-3.5 w-6 bg-cream dark:bg-ink-soft/30 rounded mx-auto" /></td>
                    <td className="py-3 px-3"><div className="h-5 w-22 bg-cream dark:bg-ink-soft/30 rounded-full" /></td>
                    <td className="py-3 px-3 sm:px-4"><div className="h-3.5 w-28 bg-cream dark:bg-ink-soft/30 rounded" /></td>
                  </tr>
                ))}

              {/* Error */}
              {!loading && error && (
                <tr>
                  <td colSpan={6} className="py-6 text-center text-alert">
                    <div className="flex flex-col items-center gap-2">
                      <ShieldAlert className="w-5 h-5" />
                      <p className="text-xs font-semibold">{error}</p>
                      <button
                        type="button"
                        onClick={loadRiskEvaluations}
                        className="text-[11px] text-terracotta underline hover:text-terracotta-dark"
                      >
                        Retry inference
                      </button>
                    </div>
                  </td>
                </tr>
              )}

              {/* Empty */}
              {!loading && !error && filteredAndSortedPatients.length === 0 && (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-ink-soft dark:text-cream/60">
                    <p className="text-xs font-semibold">No patients match the current filter.</p>
                    {(searchQuery || riskFilter !== 'all') && (
                      <button
                        type="button"
                        onClick={() => { setSearchQuery(''); setRiskFilter('all'); }}
                        className="mt-2 text-[11px] text-terracotta underline"
                      >
                        Clear filters
                      </button>
                    )}
                  </td>
                </tr>
              )}

              {/* Data rows */}
              {!loading &&
                !error &&
                filteredAndSortedPatients.map((patient) => {
                  const config = RISK_LEVEL_CONFIG[patient.risk_grade] || RISK_LEVEL_CONFIG[0];
                  return (
                    <tr
                      key={patient.patient_id}
                      className="hover:bg-cream/40 dark:hover:bg-ink-soft/20 transition-colors"
                    >
                      {/* 1. Patient ID */}
                      <td className="py-3 px-3 sm:px-4 whitespace-nowrap">
                        <span className="px-1.5 py-0.5 rounded font-mono text-[11px] font-bold bg-cream/80 dark:bg-ink-soft/50 text-ink dark:text-cream border border-border/80 dark:border-ink-soft/40">
                          {patient.patient_id}
                        </span>
                      </td>

                      {/* 2. Patient Name */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        <div className="flex items-center gap-2">
                          <div className="w-6 h-6 rounded-full bg-terracotta/10 border border-terracotta/20 flex items-center justify-center text-terracotta font-bold text-[10px] shrink-0">
                            {patient.name.charAt(0)}
                          </div>
                          <span className="font-semibold text-ink dark:text-cream text-xs">
                            {patient.name}
                          </span>
                        </div>
                      </td>

                      {/* 3. Age & Gender */}
                      <td className="py-3 px-3 whitespace-nowrap text-ink-soft dark:text-cream/70 text-xs">
                        {patient.age} yrs
                        <span className="mx-1 opacity-40">·</span>
                        {patient.gender}
                      </td>

                      {/* 4. Active Alerts Count */}
                      <td className="py-3 px-3 whitespace-nowrap text-center">
                        {patient.active_alerts_count > 0 ? (
                          <span className="inline-flex items-center justify-center px-1.5 py-0.5 rounded-full text-[11px] font-bold bg-alert/15 text-alert border border-alert/30 min-w-[20px]">
                            {patient.active_alerts_count}
                          </span>
                        ) : (
                          <span className="text-[11px] text-ink-soft/50 dark:text-cream/30">0</span>
                        )}
                      </td>

                      {/* 5. Risk Level badge */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        <span
                          className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold"
                          style={{
                            backgroundColor: `${config.badgeColor}22`,
                            color: config.badgeColor,
                            border: `1px solid ${config.badgeColor}55`,
                          }}
                        >
                          <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: config.badgeColor }} />
                          {config.level}
                        </span>
                      </td>

                      {/* 6. Recommended Action */}
                      <td className="py-3 px-3 sm:px-4 whitespace-nowrap">
                        <span className="font-semibold text-ink dark:text-cream text-xs">{config.action}</span>
                        <p className="text-[10px] text-ink-soft dark:text-cream/55 mt-0.5 max-w-[200px] leading-snug">
                          {config.actionDescription}
                        </p>
                      </td>
                    </tr>
                  );
                })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Footer */}
      <div className="px-4 py-2 bg-cream/20 dark:bg-ink-soft/10 border-t border-border/60 dark:border-ink-soft/20 flex flex-col sm:flex-row sm:items-center justify-between gap-1 text-[10px] text-ink-soft/70 dark:text-cream/50">
        <span>
          Model:{' '}
          <span className="font-mono font-semibold text-ink dark:text-cream">GradientBoosting Classifier</span>
          {' · '}Features: [age, accuracy_rate_pct, reaction_time_ms, drift_slope_7d, active_alert_count]
        </span>
        <span>
          {filteredAndSortedPatients.length} of {data.patients.length} records
        </span>
      </div>
    </section>
  );
};

export default PatientRiskOverviewTable;
