import React, { useState, useEffect, useMemo } from 'react';
import { useParams, useLocation } from 'react-router-dom';
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts';
import {
  TrendingUp,
  Brain,
  BookOpen,
  Eye,
  Activity,
  Calendar,
  Clock,
  AlertCircle,
  CheckCircle2,
  XCircle,
  HelpCircle,
  RefreshCw,
  Award,
  FileText,
} from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import { fetchPatients, getPatientById } from '../services/patientService';
import { fetchPatientRiskOverview } from '../services/riskService';
import { PatientReportCardModal } from '../components/PatientReportCardModal';
import {
  getGameSessions,
  DOMAINS,
  GAME_TYPES,
  DOMAIN_CONFIG,
  formatSessionDate,
  formatDuration,
} from '../services/gameSessionService';

/**
 * Custom Recharts Tooltip styled to match brand design system
 */
const CustomChartTooltip = ({ active, payload, domainKey }) => {
  if (!active || !payload || !payload.length) return null;

  const data = payload[0].payload;
  const config = DOMAIN_CONFIG[domainKey] || DOMAIN_CONFIG.memory;

  return (
    <div className="bg-surface dark:bg-ink border border-border dark:border-ink-soft/50 rounded-lg p-3 shadow-lg text-xs space-y-1.5 min-w-[170px]">
      <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-1.5 font-medium text-ink-soft dark:text-cream/70">
        <span>{data.fullDate || data.date}</span>
        <span className="px-1.5 py-0.5 rounded bg-cream dark:bg-ink-soft/40 text-[10px] uppercase font-bold text-ink dark:text-cream">
          Lvl {data.difficulty}
        </span>
      </div>

      <div className="flex items-center justify-between gap-3 pt-0.5">
        <span className="text-ink-soft dark:text-cream/70">Score Index:</span>
        <span className="font-bold text-ink dark:text-cream text-sm" style={{ color: config.color }}>
          {Math.round(data.score * 100)}% ({data.score.toFixed(2)})
        </span>
      </div>

      {data.keyMetricLabel && (
        <div className="flex items-center justify-between gap-3 text-[11px]">
          <span className="text-ink-soft dark:text-cream/60">{data.keyMetricLabel}:</span>
          <span className="font-medium text-ink dark:text-cream">{data.keyMetricValue}</span>
        </div>
      )}

      <div className="flex items-center justify-between gap-3 text-[11px] text-ink-soft dark:text-cream/60">
        <span>Duration:</span>
        <span>{formatDuration(data.duration)}</span>
      </div>
    </div>
  );
};

const ScoreBadge = ({ score }) => {
  if (score === null || score === undefined) return <span className="text-ink-soft">—</span>;
  const pct = Math.round(score * 100);
  const colorClass =
    pct >= 80
      ? 'bg-sage/15 text-sage border-sage/30'
      : pct >= 65
      ? 'bg-gold/15 text-gold border-gold/30'
      : 'bg-terracotta/15 text-terracotta border-terracotta/30';

  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold border ${colorClass}`}>
      {pct}%
    </span>
  );
};

export const Analytics = () => {
  const { id } = useParams();
  const location = useLocation();
  const [resolvedId, setResolvedId] = useState(id || '');
  const patientId = resolvedId;
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const [patient, setPatient] = useState(null);
  const [sessions, setSessions] = useState([]);
  const [riskData, setRiskData] = useState(null);
  const [showReportModal, setShowReportModal] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Load patient info, game session analytics, and risk overview
  const loadData = async () => {
    let targetId = id;
    if (!targetId) {
      const roster = await fetchPatients();
      if (roster && roster.length > 0) {
        targetId = roster[0].id;
        setResolvedId(targetId);
      }
    }

    if (!targetId) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const [patientData, sessionsData, riskOverviewData] = await Promise.all([
        getPatientById(targetId),
        getGameSessions(targetId),
        fetchPatientRiskOverview().catch((err) => {
          console.warn('Could not fetch risk overview:', err);
          return null;
        }),
      ]);

      setPatient(patientData);
      setSessions(sessionsData || []);
      setRiskData(riskOverviewData);
    } catch (err) {
      console.error('Analytics load error:', err);
      setError(err?.message || 'Failed to load cognitive analytics data.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [id]);

  // Scroll to session history table when hash is #session-history
  useEffect(() => {
    if (!loading && location.hash === '#session-history') {
      const timer = setTimeout(() => {
        const el = document.getElementById('session-history');
        if (el) {
          el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [loading, location.hash]);

  // Separate session data by domain for the 3 individual line charts
  const domainData = useMemo(() => {
    const memory = [];
    const language = [];
    const attention = [];

    sessions.forEach((s) => {
      const point = {
        id: s.session_id,
        date: formatSessionDate(s.session_date),
        fullDate: formatSessionDate(s.session_date, true),
        rawDate: new Date(s.session_date).getTime(),
        score: s.score_normalized,
        difficulty: s.difficulty_level,
        duration: s.session_duration,
        status: s.status,
      };

      if (s.domain === DOMAINS.MEMORY) {
        point.keyMetricLabel = 'Match Rate';
        point.keyMetricValue = `${Math.round((s.correct_match_rate || 0.8) * 100)}%`;
        memory.push(point);
      } else if (s.domain === DOMAINS.LANGUAGE) {
        point.keyMetricLabel = 'Words Recalled';
        point.keyMetricValue = `${s.words_recalled_count || 10} words`;
        language.push(point);
      } else if (s.domain === DOMAINS.ATTENTION) {
        point.keyMetricLabel = 'Avg Latency';
        point.keyMetricValue = `${s.reaction_time_avg || 550} ms`;
        attention.push(point);
      }
    });

    return {
      memory: memory.sort((a, b) => a.rawDate - b.rawDate),
      language: language.sort((a, b) => a.rawDate - b.rawDate),
      attention: attention.sort((a, b) => a.rawDate - b.rawDate),
    };
  }, [sessions]);

  // All sessions sorted newest first for the history table
  const sortedSessions = useMemo(() => {
    return [...sessions].sort(
      (a, b) => new Date(b.session_date).getTime() - new Date(a.session_date).getTime()
    );
  }, [sessions]);

  // Aggregate stats across domains
  const stats = useMemo(() => {
    if (!sessions.length) return { total: 0, avgScore: 0, completedCount: 0 };
    const completed = sessions.filter((s) => s.status === 'completed');
    const totalScore = completed.reduce((sum, s) => sum + s.score_normalized, 0);
    const avg = completed.length > 0 ? totalScore / completed.length : 0;

    return {
      total: sessions.length,
      completedCount: completed.length,
      avgScore: Math.round(avg * 100),
    };
  }, [sessions]);

  // Chart styling colors based on theme
  const gridStroke = isDark ? 'rgba(228, 217, 196, 0.1)' : 'rgba(46, 42, 36, 0.08)';
  const axisTickColor = isDark ? '#A89F91' : '#6B625A';

  // Domain icon map
  const getDomainIcon = (domainKey) => {
    switch (domainKey) {
      case DOMAINS.MEMORY:
        return <Brain className="w-4 h-4 text-terracotta" />;
      case DOMAINS.LANGUAGE:
        return <BookOpen className="w-4 h-4 text-sage" />;
      case DOMAINS.ATTENTION:
        return <Eye className="w-4 h-4 text-gold" />;
      default:
        return <Activity className="w-4 h-4 text-terracotta" />;
    }
  };

  // Human friendly game type label
  const getGameLabel = (gameType) => {
    switch (gameType) {
      case GAME_TYPES.PAIR_MATCHING:
        return 'Pair Matching';
      case GAME_TYPES.MARKET_TRIP:
        return 'Market Trip';
      case GAME_TYPES.TAP_TARGET:
        return 'Tap the Target';
      default:
        return gameType || 'Cognitive Game';
    }
  };

  // Render individual domain trend line chart card
  const renderDomainChartCard = (domainKey) => {
    const config = DOMAIN_CONFIG[domainKey];
    const data = domainData[domainKey] || [];
    const latestSession = data.length > 0 ? data[data.length - 1] : null;
    const avgDomainScore =
      data.length > 0
        ? Math.round((data.reduce((acc, d) => acc + d.score, 0) / data.length) * 100)
        : 0;

    return (
      <div
        key={domainKey}
        className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-5 sm:p-6 shadow-sm flex flex-col justify-between transition-colors"
      >
        {/* Card Header */}
        <div className="space-y-2 mb-4">
          <div className="flex items-start justify-between gap-2">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/60 dark:border-ink-soft/30 flex items-center justify-center shrink-0">
                {getDomainIcon(domainKey)}
              </div>
              <div>
                <h3 className="text-base font-bold text-ink dark:text-cream leading-snug">
                  {config.label}
                </h3>
                <span className="text-[11px] font-semibold text-ink-soft dark:text-cream/70 uppercase tracking-wider">
                  {config.gameLabel.includes('&') ? 'Games' : 'Game'}: {config.gameLabel}
                </span>
              </div>
            </div>

            {latestSession && (
              <div className="text-right shrink-0">
                <div className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold border"
                  style={{
                    backgroundColor: `${config.color}15`,
                    borderColor: `${config.color}40`,
                    color: config.color,
                  }}
                >
                  <TrendingUp className="w-3 h-3" />
                  <span>{Math.round(latestSession.score * 100)}%</span>
                </div>
                <p className="text-[10px] text-ink-soft dark:text-cream/60 mt-0.5">
                  Avg: {avgDomainScore}%
                </p>
              </div>
            )}
          </div>

          <p className="text-xs text-ink-soft dark:text-cream/70 leading-relaxed">
            {config.description}
          </p>
        </div>

        {/* Chart View */}
        <div className="h-56 w-full pt-2">
          {data.length > 0 ? (
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={data} margin={{ top: 10, right: 12, left: -22, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} vertical={false} />
                <XAxis
                  dataKey="date"
                  tickLine={false}
                  axisLine={{ stroke: gridStroke }}
                  tick={{ fill: axisTickColor, fontSize: 11 }}
                  dy={6}
                />
                <YAxis
                  domain={[0.5, 1.0]}
                  ticks={[0.5, 0.65, 0.8, 0.95, 1.0]}
                  tickLine={false}
                  axisLine={{ stroke: gridStroke }}
                  tick={{ fill: axisTickColor, fontSize: 10 }}
                  tickFormatter={(val) => `${Math.round(val * 100)}%`}
                />
                <Tooltip content={<CustomChartTooltip domainKey={domainKey} />} />
                <Line
                  type="monotone"
                  dataKey="score"
                  stroke={config.color}
                  strokeWidth={2.5}
                  dot={{ r: 3.5, fill: config.color, strokeWidth: 1.5, stroke: isDark ? '#2E2A24' : '#FFFDF8' }}
                  activeDot={{ r: 5.5, fill: config.color, stroke: isDark ? '#2E2A24' : '#FFFDF8', strokeWidth: 2 }}
                />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-full flex items-center justify-center text-xs text-ink-soft dark:text-cream/60">
              No trend data available
            </div>
          )}
        </div>

        {/* Card Footer Metric Indicator */}
        <div className="mt-4 pt-3 border-t border-border/60 dark:border-ink-soft/30 flex items-center justify-between text-[11px] text-ink-soft dark:text-cream/70">
          <span>Target Metric:</span>
          <span className="font-semibold text-ink dark:text-cream">{config.targetParam}</span>
        </div>
      </div>
    );
  };

  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        {/* Header Skeleton */}
        <div className="bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6 sm:p-8">
          <div className="h-7 w-64 bg-cream dark:bg-ink-soft/30 rounded mb-2" />
          <div className="h-4 w-96 bg-cream/70 dark:bg-ink-soft/20 rounded" />
        </div>

        {/* Charts Grid Skeleton */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {[1, 2].map((n) => (
            <div
              key={n}
              className="h-80 bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6"
            />
          ))}
        </div>

        {/* Table Skeleton */}
        <div className="h-64 bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-8 text-center space-y-4">
        <div className="w-12 h-12 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta mx-auto">
          <AlertCircle className="w-6 h-6" />
        </div>
        <div className="space-y-1">
          <h3 className="text-base font-bold text-ink dark:text-cream">Failed to load analytics</h3>
          <p className="text-xs text-ink-soft dark:text-cream/70">{error}</p>
        </div>
        <button
          type="button"
          onClick={loadData}
          className="inline-flex items-center gap-1.5 px-4 py-2 bg-terracotta text-cream text-xs font-semibold rounded-lg hover:bg-terracotta/90 transition-colors shadow-2xs"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Retry</span>
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* PAGE HEADER & COGNITIVE SUMMARY */}
      <div className="bg-surface dark:bg-ink-soft/20 border border-border dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-sm transition-colors">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div>
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-terracotta/10 text-terracotta border border-terracotta/20 text-xs font-bold uppercase tracking-wider mb-3">
              <Activity className="w-3.5 h-3.5" />
              <span>Cognitive Trend Telemetry</span>
            </div>
            <h1 className="text-2xl sm:text-3xl font-bold text-ink dark:text-cream tracking-tight">
              Cognitive Analytics & Trends
            </h1>
            <p className="text-sm text-ink-soft dark:text-cream/70 mt-1.5 max-w-2xl leading-relaxed">
              Longitudinal performance tracking for <span className="font-semibold text-ink dark:text-cream">{patient?.name || 'Patient'}</span> across core cognitive domains: working & episodic memory recall, and attention processing speed.
            </p>
          </div>

          {/* Quick Metrics Badges & Download Report Card CTA */}
          <div className="flex flex-wrap items-center gap-3 sm:gap-4 shrink-0">
            <div className="bg-cream/70 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-card p-3.5 min-w-[120px]">
              <div className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider">
                Total Sessions
              </div>
              <div className="text-xl font-bold text-ink dark:text-cream mt-0.5">
                {stats.total}
              </div>
            </div>

            <div className="bg-cream/70 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-card p-3.5 min-w-[120px]">
              <div className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider">
                Avg Score
              </div>
              <div className="text-xl font-bold text-terracotta mt-0.5">
                {stats.avgScore}%
              </div>
            </div>

            <div className="bg-cream/70 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-card p-3.5 min-w-[130px]">
              <div className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider">
                Completion Rate
              </div>
              <div className="text-xl font-bold text-sage mt-0.5">
                {stats.total > 0 ? Math.round((stats.completedCount / stats.total) * 100) : 0}%
              </div>
            </div>

            <button
              type="button"
              onClick={() => setShowReportModal(true)}
              className="inline-flex items-center justify-center gap-2 px-4 py-3 bg-terracotta hover:bg-terracotta/90 text-cream text-xs sm:text-sm font-bold rounded-card shadow-sm hover:shadow transition-all cursor-pointer h-full self-stretch min-h-[58px]"
            >
              <FileText className="w-4 h-4" />
              <span>Download Report Card</span>
            </button>
          </div>
        </div>
      </div>

      {/* COGNITIVE DOMAIN TREND LINE CHARTS */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {renderDomainChartCard(DOMAINS.MEMORY)}
        {/* Middle chart temporarily disabled until data parameters are configured */}
        {/* {renderDomainChartCard(DOMAINS.LANGUAGE)} */}
        {renderDomainChartCard(DOMAINS.ATTENTION)}
      </div>

      {/* SESSION HISTORY DRILL-DOWN TABLE */}
      <div id="session-history" className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-sm space-y-4 transition-colors scroll-mt-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-border/60 dark:border-ink-soft/30 pb-4">
          <div>
            <h2 className="text-lg font-bold text-ink dark:text-cream">
              Recent Game Session History
            </h2>
            <p className="text-xs text-ink-soft dark:text-cream/70 mt-0.5">
              Chronological log of completed and active clinical game trials
            </p>
          </div>
          <span className="text-xs font-semibold text-ink-soft dark:text-cream/60">
            Showing {sortedSessions.length} records
          </span>
        </div>

        {sortedSessions.length === 0 ? (
          <div className="p-8 text-center text-xs text-ink-soft dark:text-cream/60 space-y-2">
            <HelpCircle className="w-8 h-8 text-ink-soft/40 mx-auto" />
            <p>No game sessions recorded yet for this patient.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-ink dark:text-cream">
              <thead>
                <tr className="border-b border-border/80 dark:border-ink-soft/40 bg-cream/50 dark:bg-ink-soft/30 text-ink-soft dark:text-cream/70 uppercase font-bold text-[10px] tracking-wider">
                  <th className="py-3 px-4 rounded-l-lg">Date & Time</th>
                  <th className="py-3 px-4">Game Type</th>
                  <th className="py-3 px-4">Cognitive Domain</th>
                  <th className="py-3 px-4">Score (Normalized)</th>
                  <th className="py-3 px-4">Duration</th>
                  <th className="py-3 px-4">Difficulty</th>
                  <th className="py-3 px-4 rounded-r-lg">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/50 dark:divide-ink-soft/20">
                {sortedSessions.map((session) => {
                  const domainCfg = DOMAIN_CONFIG[session.domain] || DOMAIN_CONFIG.memory;
                  const isCompleted = session.status === 'completed';

                  return (
                    <tr
                      key={session.session_id}
                      className="hover:bg-cream/40 dark:hover:bg-ink-soft/30 transition-colors"
                    >
                      {/* Date & Time */}
                      <td className="py-3 px-4 font-medium whitespace-nowrap">
                        <div className="flex items-center gap-2">
                          <Calendar className="w-3.5 h-3.5 text-ink-soft/60" />
                          <span>{formatSessionDate(session.session_date, true)}</span>
                        </div>
                      </td>

                      {/* Game Type */}
                      <td className="py-3 px-4 font-semibold whitespace-nowrap">
                        {getGameLabel(session.game_type)}
                      </td>

                      {/* Cognitive Domain */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        <span
                          className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[11px] font-semibold border"
                          style={{
                            backgroundColor: `${domainCfg.color}15`,
                            borderColor: `${domainCfg.color}40`,
                            color: domainCfg.color,
                          }}
                        >
                          {getDomainIcon(session.domain)}
                          <span>{domainCfg.label}</span>
                        </span>
                      </td>

                      {/* Normalized Score Bar & Percentage */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        <div className="flex items-center gap-2.5">
                          <div className="w-16 h-2 bg-cream dark:bg-ink-soft/50 rounded-full overflow-hidden border border-border/50 dark:border-ink-soft/30">
                            <div
                              className="h-full rounded-full transition-all"
                              style={{
                                width: `${Math.round(session.score_normalized * 100)}%`,
                                backgroundColor: domainCfg.color,
                              }}
                            />
                          </div>
                          <span className="font-bold text-xs" style={{ color: domainCfg.color }}>
                            {Math.round(session.score_normalized * 100)}%
                          </span>
                        </div>
                      </td>

                      {/* Duration */}
                      <td className="py-3 px-4 whitespace-nowrap text-ink-soft dark:text-cream/70 font-mono text-[11px]">
                        {formatDuration(session.session_duration)}
                      </td>

                      {/* Difficulty Level */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        <span className="px-2 py-0.5 rounded bg-cream dark:bg-ink-soft/40 border border-border/60 dark:border-ink-soft/30 text-[10px] font-bold text-ink-soft dark:text-cream/80">
                          Level {session.difficulty_level}
                        </span>
                      </td>

                      {/* Status */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        {isCompleted ? (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-sage/15 text-sage border border-sage/30 text-[11px] font-semibold">
                            <CheckCircle2 className="w-3 h-3" />
                            <span>Completed</span>
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-alert/15 text-alert border border-alert/30 text-[11px] font-semibold">
                            <XCircle className="w-3 h-3" />
                            <span>Abandoned</span>
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Patient Cognitive & Clinical Report Card Modal */}
      <PatientReportCardModal
        isOpen={showReportModal}
        onClose={() => setShowReportModal(false)}
        patient={patient}
        sessions={sessions}
        domainData={domainData}
        riskOverview={riskData}
        stats={stats}
      />
    </div>
  );
};

export default Analytics;
