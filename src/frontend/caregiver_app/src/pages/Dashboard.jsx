import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { fetchPatients } from '../services/patientService';
import { getGameSessions, DOMAINS } from '../services/gameSessionService';
import { PatientCard } from '../components/PatientCard';
import { PatientRiskOverviewTable } from '../components/PatientRiskOverviewTable';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts';
import {
  Users,
  Sparkles,
  RefreshCw,
  AlertCircle,
  UserPlus,
  Search,
  X,
  HeartHandshake,
  Brain,
  Eye,
  Activity,
  BarChart3,
} from 'lucide-react';

// Custom Recharts Tooltip styled to brand design tokens
const DashboardChartTooltip = ({ active, payload, paramConfig }) => {
  if (!active || !payload || !payload.length) return null;
  const item = payload[0].payload;

  return (
    <div className="bg-surface dark:bg-ink border border-border dark:border-ink-soft/50 rounded-lg p-3 shadow-lg text-xs space-y-1.5 min-w-[190px]">
      <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-1.5">
        <span className="font-bold text-ink dark:text-cream">{item.name}</span>
        <span className="px-1.5 py-0.5 rounded bg-cream dark:bg-ink-soft/40 text-[10px] font-mono font-bold text-ink dark:text-cream">
          {item.id}
        </span>
      </div>
      <div className="flex items-center justify-between gap-3 pt-0.5">
        <span className="text-ink-soft dark:text-cream/70">{paramConfig.label}:</span>
        <span className="font-bold text-sm" style={{ color: paramConfig.color }}>
          {item.hasData ? `${item.rawScore}%` : 'No sessions recorded'}
        </span>
      </div>
      <div className="text-[10px] text-ink-soft dark:text-cream/60">
        {item.totalSessions} total session{item.totalSessions !== 1 ? 's' : ''} on record
      </div>
    </div>
  );
};

export const Dashboard = () => {
  const { caregiver } = useAuth();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all'); // 'all' | 'needs_attention' | 'stable'
  const [selectedParam, setSelectedParam] = useState('memory'); // 'memory' | 'attention'
  const [patientScores, setPatientScores] = useState({});
  const [loadingScores, setLoadingScores] = useState(false);

  const loadPatients = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchPatients();
      setPatients(data || []);
    } catch (err) {
      setError(err?.message || 'Unable to load patient records. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPatients();
  }, []);

  // Fetch session data for all patients to compute real average domain scores
  useEffect(() => {
    if (!patients || patients.length === 0) return;

    let isMounted = true;
    const fetchAllScores = async () => {
      setLoadingScores(true);
      const scoresMap = {};

      await Promise.all(
        patients.map(async (patient) => {
          try {
            const sessions = await getGameSessions(patient.id);
            if (!Array.isArray(sessions) || sessions.length === 0) {
              scoresMap[patient.id] = {
                memory: null,
                attention: null,
                totalSessions: 0,
              };
              return;
            }

            // Filter for Working & Episodic Memory (Market Trip + Pair Matching)
            const memorySessions = sessions.filter(
              (s) =>
                s.domain === 'memory' ||
                s.game_type === 'pair_matching' ||
                s.game_type === 'market_trip'
            );

            // Filter for Attention & Processing Speed (Tap the Target + Visual Search)
            const attentionSessions = sessions.filter(
              (s) =>
                s.domain === 'attention' ||
                s.game_type === 'tap_target' ||
                s.game_type === 'visual_search'
            );

            const calcAvg = (sessionList) => {
              if (!sessionList.length) return null;
              const total = sessionList.reduce((sum, s) => {
                const score = s.score_normalized ?? s.performance_score ?? 0;
                return sum + score;
              }, 0);
              return Math.round((total / sessionList.length) * 100);
            };

            scoresMap[patient.id] = {
              memory: calcAvg(memorySessions),
              attention: calcAvg(attentionSessions),
              totalSessions: sessions.length,
            };
          } catch (err) {
            console.error(`Failed to fetch sessions for patient ${patient.id}:`, err);
            scoresMap[patient.id] = {
              memory: null,
              attention: null,
              totalSessions: 0,
            };
          }
        })
      );

      if (isMounted) {
        setPatientScores(scoresMap);
        setLoadingScores(false);
      }
    };

    fetchAllScores();

    return () => {
      isMounted = false;
    };
  }, [patients]);

  const PARAM_CONFIG = {
    memory: {
      label: 'Working & Episodic Memory',
      shortLabel: 'Memory',
      description: 'Market Trip & Pair Matching cognitive routines',
      color: '#B5562F', // Terracotta
      icon: Brain,
    },
    attention: {
      label: 'Attention & Processing Speed',
      shortLabel: 'Attention',
      description: 'Tap the Target focus & motor latency tests',
      color: '#C9962C', // Gold
      icon: Eye,
    },
  };

  const activeParamConfig = PARAM_CONFIG[selectedParam];

  // Chart data preparation - each bar represents a patient
  const chartData = useMemo(() => {
    return patients.map((patient) => {
      const scores = patientScores[patient.id];
      const avgScore = scores ? scores[selectedParam] : null;

      return {
        id: patient.id,
        name: patient.name,
        displayName: `${patient.name} (${patient.id})`,
        score: avgScore !== null ? avgScore : 0,
        rawScore: avgScore,
        hasData: avgScore !== null,
        totalSessions: scores?.totalSessions || 0,
      };
    });
  }, [patients, patientScores, selectedParam]);

  const gridStroke = isDark ? 'rgba(228, 217, 196, 0.1)' : 'rgba(46, 42, 36, 0.08)';
  const axisTickColor = isDark ? '#A89F91' : '#6B625A';

  // Filter & Search composition
  const filteredPatients = useMemo(() => {
    return patients.filter((patient) => {
      // 1. Status Filter
      if (statusFilter === 'needs_attention') {
        if (patient.careStatus !== 'reminder_missed' && patient.careStatus !== 'alert') {
          return false;
        }
      } else if (statusFilter === 'stable') {
        if (patient.careStatus !== 'normal') {
          return false;
        }
      }

      // 2. Search Substring Filter (case-insensitive)
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase().trim();
        return patient.name?.toLowerCase().includes(query);
      }

      return true;
    });
  }, [patients, statusFilter, searchQuery]);

  // Live counts computed from patients array
  const attentionCount = patients.filter(
    (p) => p.careStatus === 'reminder_missed' || p.careStatus === 'alert'
  ).length;
  const stableCount = patients.filter((p) => p.careStatus === 'normal').length;

  const todayFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  return (
    <div className="space-y-6 sm:space-y-8 font-sans">
      {/* 1. Prominent Top-Left Branding Header */}
      <header className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-2 border-b border-border/60 dark:border-ink-soft/30 pb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-card bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shadow-xs">
            <HeartHandshake className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-baseline gap-2.5">
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream">
                Smriti Kunj
              </h1>
              <span className="text-sm font-medium text-ink-soft dark:text-cream/60">
                স্মৃতি কুঞ্জ
              </span>
            </div>
            <p className="text-xs text-ink-soft dark:text-cream/60">
              Cognitive Assistive Care Portal
            </p>
          </div>
        </div>

        {/* Formatted Date */}
        <div className="text-xs text-ink-soft dark:text-cream/60 font-medium">
          {todayFormatted}
        </div>
      </header>

      {/* 2. Welcome Card */}
      <section
        aria-label="Welcome Overview"
        className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-sm transition-colors"
      >
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-cream dark:bg-ink-soft/40 text-terracotta text-xs font-semibold uppercase tracking-wider mb-3">
              <Sparkles className="w-3.5 h-3.5" />
              <span>Caregiver Roster</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-bold text-ink dark:text-cream tracking-tight">
              Welcome, {caregiver?.name || 'Caregiver'}
            </h2>
            <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-1.5 max-w-2xl leading-relaxed">
              Monitor active patient cognitive routines, longitudinal trends, and tablet synchronization status from your dashboard portal.
            </p>
          </div>

          <div className="flex items-center gap-3 self-start sm:self-center shrink-0">
            <div className="w-12 h-12 rounded-card bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shadow-xs">
              <Users className="w-6 h-6" />
            </div>
          </div>
        </div>
      </section>

      {/* 3. Cognitive Parameter Performance Chart & Selector */}
      <section
        aria-label="Cognitive Parameter Performance"
        className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-5 sm:p-6 shadow-sm transition-colors space-y-4"
      >
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-border/60 dark:border-ink-soft/30 pb-3">
          <div className="flex items-center gap-2.5">
            <div
              className="w-8 h-8 rounded-lg flex items-center justify-center text-white shrink-0 shadow-xs"
              style={{ backgroundColor: activeParamConfig.color }}
            >
              <BarChart3 className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-base sm:text-lg font-bold text-ink dark:text-cream tracking-tight">
                Cognitive Parameter Performance
              </h3>
              <p className="text-xs text-ink-soft dark:text-cream/60">
                Comparative patient average scores across assessment domains
              </p>
            </div>
          </div>
          <span className="text-[11px] font-medium text-ink-soft dark:text-cream/60 self-start sm:self-center">
            {loadingScores ? (
              <span className="inline-flex items-center gap-1.5 text-terracotta">
                <RefreshCw className="w-3 h-3 animate-spin" />
                Aggregating scores...
              </span>
            ) : (
              `Updated from ${patients.length} patient profile${patients.length !== 1 ? 's' : ''}`
            )}
          </span>
        </div>

        {/* Responsive Grid: Left Parameter Selector + Right Clustered Bar Chart */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-stretch">
          {/* Left Column: Parameter Selector (takes 4 cols on large screens) */}
          <div className="lg:col-span-4 flex flex-col justify-between gap-3">
            <div className="space-y-2.5">
              <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70">
                Select Parameter
              </label>

              {/* Memory Option */}
              <button
                type="button"
                onClick={() => setSelectedParam('memory')}
                className={`w-full text-left p-3.5 rounded-xl border transition-all text-xs flex items-start gap-3 ${
                  selectedParam === 'memory'
                    ? 'bg-cream/90 dark:bg-ink-soft/50 border-terracotta shadow-xs ring-1 ring-terracotta/30'
                    : 'bg-surface dark:bg-ink-soft/20 border-border/80 dark:border-ink-soft/40 hover:bg-cream/40 dark:hover:bg-ink-soft/30'
                }`}
              >
                <div
                  className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 mt-0.5 ${
                    selectedParam === 'memory'
                      ? 'bg-terracotta text-white'
                      : 'bg-cream dark:bg-ink-soft/40 text-terracotta'
                  }`}
                >
                  <Brain className="w-4 h-4" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-ink dark:text-cream text-xs sm:text-sm">
                      Working & Episodic Memory
                    </span>
                    {selectedParam === 'memory' && (
                      <span className="w-2 h-2 rounded-full bg-terracotta shrink-0 ml-1.5" />
                    )}
                  </div>
                  <p className="text-[11px] text-ink-soft dark:text-cream/60 mt-0.5 leading-relaxed">
                    Market Trip & Pair Matching tasks
                  </p>
                </div>
              </button>

              {/* Attention Option */}
              <button
                type="button"
                onClick={() => setSelectedParam('attention')}
                className={`w-full text-left p-3.5 rounded-xl border transition-all text-xs flex items-start gap-3 ${
                  selectedParam === 'attention'
                    ? 'bg-gold/10 dark:bg-gold/15 border-gold shadow-xs ring-1 ring-gold/30'
                    : 'bg-surface dark:bg-ink-soft/20 border-border/80 dark:border-ink-soft/40 hover:bg-cream/40 dark:hover:bg-ink-soft/30'
                }`}
              >
                <div
                  className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 mt-0.5 ${
                    selectedParam === 'attention'
                      ? 'bg-gold text-white'
                      : 'bg-cream dark:bg-ink-soft/40 text-gold'
                  }`}
                >
                  <Eye className="w-4 h-4" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-ink dark:text-cream text-xs sm:text-sm">
                      Attention & Processing Speed
                    </span>
                    {selectedParam === 'attention' && (
                      <span className="w-2 h-2 rounded-full bg-gold shrink-0 ml-1.5" />
                    )}
                  </div>
                  <p className="text-[11px] text-ink-soft dark:text-cream/60 mt-0.5 leading-relaxed">
                    Tap the Target focus & motor latency tests
                  </p>
                </div>
              </button>
            </div>

            {/* Active Parameter Summary Info Box */}
            <div className="p-3 rounded-xl bg-cream/50 dark:bg-ink-soft/30 border border-border/60 dark:border-ink-soft/30 text-[11px] text-ink-soft dark:text-cream/70 space-y-1">
              <div className="flex items-center gap-1.5 font-medium text-ink dark:text-cream">
                <Activity className="w-3.5 h-3.5" style={{ color: activeParamConfig.color }} />
                <span>Metric Legend</span>
              </div>
              <p className="leading-relaxed">
                Displaying average percentage score (0–100%) computed across all recorded sessions for{' '}
                <strong className="text-ink dark:text-cream">{activeParamConfig.label}</strong>.
              </p>
            </div>
          </div>

          {/* Right Column: Clustered Bar Chart (takes 8 cols on large screens) */}
          <div className="lg:col-span-8 bg-cream/30 dark:bg-ink-soft/10 rounded-xl p-3 sm:p-4 border border-border/60 dark:border-ink-soft/30 flex flex-col justify-between min-h-[300px]">
            <div className="flex items-center justify-between text-xs font-semibold text-ink-soft dark:text-cream/70 mb-2 px-1">
              <span>Patient Comparison</span>
              <span className="font-mono text-[10px] uppercase tracking-wider">Avg Score %</span>
            </div>

            {chartData.length === 0 ? (
              <div className="flex-1 flex flex-col items-center justify-center py-12 text-center text-ink-soft dark:text-cream/60 text-xs">
                <BarChart3 className="w-8 h-8 opacity-40 mb-2" />
                <p>No patient records available to plot.</p>
              </div>
            ) : (
              <div className="w-full h-64 sm:h-72">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart
                    data={chartData}
                    margin={{ top: 10, right: 16, left: -16, bottom: 24 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} vertical={false} />
                    <XAxis
                      dataKey="displayName"
                      stroke={axisTickColor}
                      fontSize={11}
                      tickLine={false}
                      axisLine={{ stroke: gridStroke }}
                      interval={0}
                      angle={chartData.length > 4 ? -25 : 0}
                      textAnchor={chartData.length > 4 ? 'end' : 'middle'}
                      height={chartData.length > 4 ? 45 : 30}
                    />
                    <YAxis
                      domain={[0, 100]}
                      ticks={[0, 25, 50, 75, 100]}
                      stroke={axisTickColor}
                      fontSize={11}
                      tickLine={false}
                      axisLine={{ stroke: gridStroke }}
                      tickFormatter={(val) => `${val}%`}
                    />
                    <Tooltip
                      content={<DashboardChartTooltip paramConfig={activeParamConfig} />}
                      cursor={{ fill: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.04)' }}
                    />
                    <Bar
                      dataKey="score"
                      fill={activeParamConfig.color}
                      radius={[4, 4, 0, 0]}
                      maxBarSize={48}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
          </div>
        </div>
      </section>

      {/* 4. XGBoost Real-Time Patient Risk Overview Table */}
      <PatientRiskOverviewTable />

      {/* 5. Search + Filter Pills + Register New Patient Bar */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3.5">
        {/* Left: Search input + Filter pills */}
        <div className="flex flex-col sm:flex-row sm:items-center gap-3 flex-1">
          {/* Search Input */}
          <div className="relative flex-1 max-w-sm">
            <Search className="w-4 h-4 text-ink-soft/70 dark:text-cream/50 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search patient by name..."
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

          {/* Filter Pills */}
          <div className="flex items-center gap-1.5 overflow-x-auto py-0.5 select-none">
            <button
              type="button"
              onClick={() => setStatusFilter('all')}
              className={`px-3 py-1.5 rounded-full text-xs transition-all border outline-none focus-visible:ring-1 focus-visible:ring-terracotta ${statusFilter === 'all'
                  ? 'bg-cream dark:bg-ink-soft/40 text-ink dark:text-cream border-border/90 dark:border-ink-soft/60 font-semibold shadow-xs'
                  : 'bg-surface dark:bg-ink-soft/20 text-ink-soft dark:text-cream/70 border-border/80 dark:border-ink-soft/40 hover:text-ink dark:hover:text-cream hover:bg-cream/60 dark:hover:bg-ink-soft/30'
                }`}
            >
              All ({patients.length})
            </button>

            <button
              type="button"
              onClick={() => setStatusFilter('needs_attention')}
              className={`px-3 py-1.5 rounded-full text-xs transition-all border outline-none focus-visible:ring-1 focus-visible:ring-gold ${statusFilter === 'needs_attention'
                  ? 'bg-gold/15 text-gold border-gold/40 font-semibold shadow-xs'
                  : 'bg-surface dark:bg-ink-soft/20 text-ink-soft dark:text-cream/70 border-border/80 dark:border-ink-soft/40 hover:text-ink dark:hover:text-cream hover:bg-cream/60 dark:hover:bg-ink-soft/30'
                }`}
            >
              Needs Attention ({attentionCount})
            </button>

            <button
              type="button"
              onClick={() => setStatusFilter('stable')}
              className={`px-3 py-1.5 rounded-full text-xs transition-all border outline-none focus-visible:ring-1 focus-visible:ring-sage ${statusFilter === 'stable'
                  ? 'bg-sage/15 text-sage border-sage/40 font-semibold shadow-xs'
                  : 'bg-surface dark:bg-ink-soft/20 text-ink-soft dark:text-cream/70 border-border/80 dark:border-ink-soft/40 hover:text-ink dark:hover:text-cream hover:bg-cream/60 dark:hover:bg-ink-soft/30'
                }`}
            >
              Stable ({stableCount})
            </button>
          </div>
        </div>

        {/* Right: Register New Patient Button */}
        <Link
          to="/patients/new"
          className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-terracotta hover:bg-terracotta-dark text-cream text-xs sm:text-sm font-medium rounded-xl shadow-xs transition-colors shrink-0 outline-none focus-visible:ring-2 focus-visible:ring-terracotta/40"
        >
          <UserPlus className="w-4 h-4" />
          <span>Register New Patient</span>
        </Link>
      </div>

      {/* 4. Patient Roster Section */}
      <section aria-label="Assigned Patients Roster" className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta">
              <Users className="w-4 h-4" />
            </div>
            <h2 className="text-lg sm:text-xl font-bold text-ink dark:text-cream">
              Assigned Patients
            </h2>
            {!loading && !error && (
              <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-cream dark:bg-ink-soft/40 text-ink-soft dark:text-cream/80 border border-border/70 dark:border-ink-soft/30">
                {filteredPatients.length === patients.length
                  ? patients.length
                  : `${filteredPatients.length} of ${patients.length}`}
              </span>
            )}
          </div>

          {/* Refresh Action */}
          <button
            type="button"
            onClick={loadPatients}
            disabled={loading}
            aria-label="Refresh patient roster"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            <RefreshCw className={`w-3.5 h-3.5 text-terracotta ${loading ? 'animate-spin' : ''}`} />
            <span className="hidden sm:inline">Refresh</span>
          </button>
        </div>

        {/* STATE 1: Loading Skeleton */}
        {loading && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6 animate-pulse">
            {[1, 2, 3].map((n) => (
              <div
                key={n}
                className="bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-5 sm:p-6 space-y-4"
              >
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full bg-cream dark:bg-ink-soft/30" />
                  <div className="space-y-2 flex-1">
                    <div className="h-4 w-32 bg-cream dark:bg-ink-soft/30 rounded" />
                    <div className="h-3 w-48 bg-cream/70 dark:bg-ink-soft/20 rounded" />
                  </div>
                </div>
                <div className="pt-3 border-t border-border/40 dark:border-ink-soft/20 flex justify-between">
                  <div className="h-3 w-28 bg-cream dark:bg-ink-soft/20 rounded" />
                  <div className="h-3 w-20 bg-cream dark:bg-ink-soft/20 rounded" />
                </div>
              </div>
            ))}
          </div>
        )}

        {/* STATE 2: Error State */}
        {!loading && error && (
          <div className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-8 text-center space-y-3">
            <div className="w-10 h-10 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta mx-auto">
              <AlertCircle className="w-5 h-5" />
            </div>
            <p className="text-sm text-ink dark:text-cream font-medium">
              {error}
            </p>
            <button
              type="button"
              onClick={loadPatients}
              className="inline-flex items-center gap-1.5 px-4 py-2 bg-terracotta text-cream rounded-full text-xs font-semibold hover:bg-terracotta-dark active:scale-95 transition-all outline-none focus-visible:ring-2 focus-visible:ring-terracotta/40"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Retry</span>
            </button>
          </div>
        )}

        {/* STATE 3: Empty State (No Patients in System) */}
        {!loading && !error && patients.length === 0 && (
          <div className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-8 sm:p-12 text-center space-y-3">
            <div className="w-12 h-12 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-ink-soft dark:text-cream/60 mx-auto">
              <UserPlus className="w-6 h-6" />
            </div>
            <h3 className="text-base font-bold text-ink dark:text-cream">
              No Patients Assigned
            </h3>
            <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 max-w-sm mx-auto leading-relaxed">
              Pair a patient tablet via device pairing to begin monitoring care metrics and cognitive routines.
            </p>
          </div>
        )}

        {/* STATE 4: No Match Found from Filter/Search */}
        {!loading && !error && patients.length > 0 && filteredPatients.length === 0 && (
          <div className="bg-surface dark:bg-ink-soft/20 border border-dashed border-border/80 dark:border-ink-soft/40 rounded-card p-8 text-center space-y-3">
            <p className="text-sm text-ink-soft dark:text-cream/70">
              No patients match your current search or filter criteria.
            </p>
            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setStatusFilter('all');
              }}
              className="inline-flex items-center gap-1 px-3 py-1.5 bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 text-xs font-semibold text-terracotta rounded-full hover:bg-cream/80 transition-colors"
            >
              Clear filters
            </button>
          </div>
        )}

        {/* STATE 5: Success Grid of Filtered Patient Cards (3 columns on wide screens) */}
        {!loading && !error && filteredPatients.length > 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
            {filteredPatients.map((patient) => (
              <PatientCard key={patient.id} patient={patient} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
};

export default Dashboard;








// import React from 'react';
// import { useAuth } from '../context/AuthContext';
// import { LogOut, User, Users, Heart } from 'lucide-react';
// import { Link } from 'react-router-dom';

// export const Dashboard = () => {
//   const { caregiver, logout } = useAuth();

//   return (
//     <div className="min-h-screen bg-cream font-sans p-6 sm:p-8">
//       <div className="max-w-5xl mx-auto space-y-6">
//         {/* Top bar */}
//         <header className="bg-surface border border-border rounded-card p-6 shadow-sm flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
//           <div>
//             <span className="text-xs font-semibold uppercase tracking-wider text-terracotta">
//               Caregiver Portal
//             </span>
//             <h1 className="text-2xl font-bold text-ink tracking-tight mt-0.5">
//               Welcome back, {caregiver?.name || 'Caregiver'}
//             </h1>
//             <p className="text-sm text-ink-soft mt-1">
//               Logged in as {caregiver?.email}
//             </p>
//           </div>

//           <button
//             onClick={logout}
//             className="inline-flex items-center gap-2 px-4 py-2.5 bg-cream hover:bg-surface border border-border rounded-lg text-sm font-medium text-ink transition-colors focus:outline-none focus:ring-1 focus:ring-terracotta min-h-[44px]"
//           >
//             <LogOut className="w-4 h-4 text-ink-soft" />
//             <span>Sign Out</span>
//           </button>
//         </header>

//         {/* Multi-patient switcher section */}
//         <section className="bg-surface border border-border rounded-card p-6 shadow-sm">
//           <div className="flex items-center gap-2 mb-4">
//             <Users className="w-5 h-5 text-terracotta" />
//             <h2 className="text-lg font-bold text-ink">
//               Managed Patients
//             </h2>
//           </div>
//           <p className="text-sm text-ink-soft mb-6">
//             Select a patient profile to view detailed history, activity logs, and customization options.
//           </p>

//           <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
//             <div className="p-4 bg-cream hover:bg-surface border border-border rounded-card transition-all space-y-3">
//               <div className="flex items-center gap-3">
//                 <div className="w-10 h-10 rounded-full bg-surface border border-border flex items-center justify-center text-terracotta shrink-0">
//                   <User className="w-5 h-5" />
//                 </div>
//                 <div>
//                   <h3 className="text-sm font-semibold text-ink">
//                     Amina Begum
//                   </h3>
//                   <p className="text-xs text-ink-soft">
//                     ID: p1 • Last check-in 10m ago
//                   </p>
//                 </div>
//               </div>

//               <div className="flex items-center gap-2 pt-1 border-t border-border/60">
//                 <Link
//                   to="/patients/p1"
//                   className="flex-1 py-2 px-3 bg-surface hover:bg-cream border border-border rounded-lg text-xs font-semibold text-ink text-center transition-colors min-h-[44px] flex items-center justify-center"
//                 >
//                   View Profile
//                 </Link>
//                 <Link
//                   to="/patients/p1/care-plan"
//                   className="flex-1 py-2 px-3 bg-terracotta hover:bg-terracotta-dark text-surface rounded-lg text-xs font-semibold text-center transition-colors min-h-[44px] flex items-center justify-center"
//                 >
//                   Care Plan & Reminders
//                 </Link>
//               </div>
//             </div>

//             <div className="p-4 bg-cream hover:bg-surface border border-border rounded-card transition-all space-y-3">
//               <div className="flex items-center gap-3">
//                 <div className="w-10 h-10 rounded-full bg-surface border border-border flex items-center justify-center text-terracotta shrink-0">
//                   <User className="w-5 h-5" />
//                 </div>
//                 <div>
//                   <h3 className="text-sm font-semibold text-ink">
//                     Rohan Sharma
//                   </h3>
//                   <p className="text-xs text-ink-soft">
//                     ID: p2 • Last check-in 1h ago
//                   </p>
//                 </div>
//               </div>

//               <div className="flex items-center gap-2 pt-1 border-t border-border/60">
//                 <Link
//                   to="/patients/p2"
//                   className="flex-1 py-2 px-3 bg-surface hover:bg-cream border border-border rounded-lg text-xs font-semibold text-ink text-center transition-colors min-h-[44px] flex items-center justify-center"
//                 >
//                   View Profile
//                 </Link>
//                 <Link
//                   to="/patients/p2/care-plan"
//                   className="flex-1 py-2 px-3 bg-terracotta hover:bg-terracotta-dark text-surface rounded-lg text-xs font-semibold text-center transition-colors min-h-[44px] flex items-center justify-center"
//                 >
//                   Care Plan & Reminders
//                 </Link>
//               </div>
//             </div>
//           </div>
//         </section>

//         {/* Global Quick Access Card */}
//         <section className="bg-surface border border-border rounded-card p-6 shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
//           <div>
//             <h3 className="text-base font-bold text-ink flex items-center gap-2">
//               <Heart className="w-4 h-4 text-terracotta fill-terracotta/20" />
//               <span>Care Plan & Customization Portal</span>
//             </h3>
//             <p className="text-xs text-ink-soft mt-0.5">
//               Personalize memory gallery photo cards, daily routines, and family memories.
//             </p>
//           </div>
//           <Link
//             to="/care-plan"
//             className="px-4 py-2.5 bg-terracotta hover:bg-terracotta-dark text-surface rounded-lg text-xs font-semibold transition-colors min-h-[44px] flex items-center justify-center shrink-0"
//           >
//             Open Care Plan
//           </Link>
//         </section>
//       </div>
//     </div>
//   );
// };

// export default Dashboard;
