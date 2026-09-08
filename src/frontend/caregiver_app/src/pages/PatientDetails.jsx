import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getPatientById, getCareStatusConfig } from '../services/patientService';
import {
  getGameSessions,
  DOMAIN_CONFIG,
  formatSessionDate,
} from '../services/gameSessionService';
import { fetchReminders } from '../services/reminderService';
import {
  ShieldCheck,
  HeartPulse,
  Clock,
  Phone,
  Tablet,
  AlertCircle,
  Calendar,
  Activity,
  CheckCircle2,
  ArrowRight,
  Brain,
  BookOpen,
  Eye,
  Pill,
  Droplets,
  Utensils,
  AlertTriangle,
  Copy,
  Check,
  Sparkles,
} from 'lucide-react';

export const CONDITION_OPTIONS = [
  {
    key: 'normal',
    label: 'Stable Condition',
    shortLabel: 'Stable',
    badgeBg: 'bg-sage/15',
    badgeText: 'text-sage',
    badgeBorder: 'border-sage/30',
    dotColor: 'bg-sage',
    ringColor: 'ring-sage/40',
    description: 'Vitals stable • Routine and adherence on track',
    icon: CheckCircle2,
  },
  {
    key: 'reminder_missed',
    label: 'Needs Attention',
    shortLabel: 'Needs Attention',
    badgeBg: 'bg-gold/15',
    badgeText: 'text-gold',
    badgeBorder: 'border-gold/30',
    dotColor: 'bg-gold',
    ringColor: 'ring-gold/40',
    description: 'Routine delayed or missed • Check-in advised',
    icon: AlertTriangle,
  },
  {
    key: 'alert',
    label: 'Critical / High Alert',
    shortLabel: 'Urgent Care',
    badgeBg: 'bg-alert/15',
    badgeText: 'text-alert',
    badgeBorder: 'border-alert/30',
    dotColor: 'bg-alert',
    ringColor: 'ring-alert/40',
    description: 'Acute distress / anomaly • Prompt check needed',
    icon: AlertCircle,
  },
];

export const PatientDetails = () => {
  const { id } = useParams();
  const [patient, setPatient] = useState(null);
  const [recentSessions, setRecentSessions] = useState([]);
  const [remindersList, setRemindersList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [copiedCode, setCopiedCode] = useState(false);

  useEffect(() => {
    let isMounted = true;

    const fetchDetail = async () => {
      try {
        setLoading(true);
        setError(null);

        const [patientData, sessionsData, rawReminders] = await Promise.all([
          getPatientById(id),
          getGameSessions(id).catch(() => []),
          fetchReminders(id).catch(() => null),
        ]);

        if (isMounted) {
          // Patient care status is determined dynamically by backend algorithms and analysis
          const effectiveCareStatus = patientData?.careStatus || 'normal';

          const resolvedPatient = {
            ...patientData,
            careStatus: effectiveCareStatus,
          };

          setPatient(resolvedPatient);

          // Take the 3 most recent sessions (sorted descending by date)
          const sortedSessions = [...(sessionsData || [])].sort(
            (a, b) => new Date(b.session_date).getTime() - new Date(a.session_date).getTime()
          );
          setRecentSessions(sortedSessions.slice(0, 3));

          // Flatten and prioritize reminders (missed first, then upcoming up to 3 total)
          const processedReminders = [];
          const hasMissedStatus = effectiveCareStatus === 'reminder_missed';

          if (rawReminders) {
            // 1. Medication
            if (Array.isArray(rawReminders.medication)) {
              rawReminders.medication.forEach((item, idx) => {
                processedReminders.push({
                  id: item.id || `med_${idx}`,
                  label: item.label || 'Medication Dose',
                  time: item.time || 'Scheduled',
                  category: 'Medication',
                  isMissed: hasMissedStatus && idx === 0, // Flag first as missed if patient careStatus is reminder_missed
                  icon: Pill,
                });
              });
            }

            // 2. Hydration
            if (rawReminders.hydration && rawReminders.hydration.label) {
              processedReminders.push({
                id: rawReminders.hydration.id || 'hyd_1',
                label: rawReminders.hydration.label,
                time: rawReminders.hydration.schedule || '8 AM – 8 PM',
                category: 'Hydration',
                isMissed: false,
                icon: Droplets,
              });
            }

            // 3. Meals
            if (Array.isArray(rawReminders.meals)) {
              rawReminders.meals.forEach((item, idx) => {
                processedReminders.push({
                  id: item.id || `meal_${idx}`,
                  label: item.label || 'Meal',
                  time: item.time || 'Scheduled',
                  category: 'Meals',
                  isMissed: false,
                  icon: Utensils,
                });
              });
            }

            // 4. Custom
            if (Array.isArray(rawReminders.custom)) {
              rawReminders.custom.forEach((item, idx) => {
                processedReminders.push({
                  id: item.id || `cust_${idx}`,
                  label: item.label || 'Routine Task',
                  time: item.time || item.frequency || 'Scheduled',
                  category: 'Custom Routine',
                  isMissed: false,
                  icon: Clock,
                });
              });
            }
          }

          // Prioritize missed items first, then upcoming routines
          const prioritized = [
            ...processedReminders.filter((r) => r.isMissed),
            ...processedReminders.filter((r) => !r.isMissed),
          ].slice(0, 3);

          setRemindersList(prioritized);
        }
      } catch (err) {
        if (isMounted) {
          setError(err?.message || 'Failed to load patient profile details.');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchDetail();

    return () => {
      isMounted = false;
    };
  }, [id]);

  // Initials generator for fallback avatar
  const getInitials = (name) => {
    if (!name) return 'PT';
    return name
      .split(' ')
      .filter(Boolean)
      .map((part) => part[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  const getDomainIcon = (domain) => {
    switch (domain) {
      case 'memory':
        return <Brain className="w-3.5 h-3.5 text-terracotta" />;
      case 'language':
        return <BookOpen className="w-3.5 h-3.5 text-sage" />;
      case 'attention':
        return <Eye className="w-3.5 h-3.5 text-gold" />;
      default:
        return <Activity className="w-3.5 h-3.5 text-terracotta" />;
    }
  };

  const getGameLabel = (gameType) => {
    switch (gameType) {
      case 'pair_matching':
        return 'Pair Matching';
      case 'word_association':
        return 'Word Association';
      case 'visual_search':
        return 'Visual Search';
      default:
        return gameType || 'Game';
    }
  };

  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        {/* Profile Header Skeleton */}
        <div className="bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6 sm:p-8">
          <div className="flex flex-col sm:flex-row sm:items-center gap-5">
            <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-full bg-cream dark:bg-ink-soft/30 shrink-0" />
            <div className="space-y-2.5 flex-1">
              <div className="h-6 w-48 bg-cream dark:bg-ink-soft/30 rounded" />
              <div className="h-4 w-72 bg-cream/70 dark:bg-ink-soft/20 rounded" />
              <div className="h-4 w-56 bg-cream/60 dark:bg-ink-soft/20 rounded" />
            </div>
          </div>
        </div>

        {/* Info Cards Grid Skeleton */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="h-44 bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6" />
          <div className="h-44 bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6" />
        </div>

        {/* Secondary Summary Cards Skeleton */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="h-60 bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6" />
          <div className="h-60 bg-surface/60 dark:bg-ink-soft/10 border border-border/60 dark:border-ink-soft/30 rounded-card p-6" />
        </div>
      </div>
    );
  }

  if (error || !patient) {
    return (
      <div className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-8 text-center space-y-3">
        <div className="w-10 h-10 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta mx-auto">
          <AlertCircle className="w-5 h-5" />
        </div>
        <p className="text-sm font-medium text-ink dark:text-cream">
          {error || 'Patient profile not found.'}
        </p>
      </div>
    );
  }

  // Derive paired device code consistently
  const pairedCode =
    patient.pairingToken ||
    (patient.deviceStatus?.deviceId &&
    patient.deviceStatus.deviceId !== 'UNLINKED' &&
    patient.deviceStatus.deviceId !== 'DEV-UNSET'
      ? patient.deviceStatus.deviceId
      : null) ||
    (() => {
      try {
        const stored = localStorage.getItem(`smriti_pairing_token_${patient.id}`);
        if (stored) return stored;
      } catch (e) {}
      const num = (patient.id || '').replace(/\D/g, '') || '101';
      const generated = `PAIR-${((parseInt(num, 10) * 73939 + 184920) % 900000) + 100000}`;
      try {
        localStorage.setItem(`smriti_pairing_token_${patient.id}`, generated);
      } catch (e) {}
      return generated;
    })();

  const handleCopyDeviceCode = (code) => {
    if (!code) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(code);
    } else {
      const textArea = document.createElement('textarea');
      textArea.value = code;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
    }
    setCopiedCode(true);
    setTimeout(() => setCopiedCode(false), 2000);
  };

  const initials = getInitials(patient.name);
  const activeConditionConfig =
    CONDITION_OPTIONS.find((c) => c.key === patient.careStatus) ||
    CONDITION_OPTIONS[0];

  return (
    <div className="space-y-6">
      {/* 1. Profile Header Card */}
      <section
        aria-label="Patient Profile Overview"
        className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-sm transition-colors"
      >
        <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-6">
          <div className="flex flex-col sm:flex-row sm:items-center gap-4 sm:gap-5 min-w-0 flex-1">
            {/* Large Circular Photo / Avatar with Initials Fallback */}
            <div className="relative shrink-0">
              {patient.avatarUrl ? (
                <img
                  src={patient.avatarUrl}
                  alt={patient.name}
                  className="w-20 h-20 sm:w-24 sm:h-24 rounded-full object-cover border-2 border-border/80 dark:border-ink-soft/40 shadow-xs"
                />
              ) : (
                <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-full bg-cream dark:bg-ink-soft/40 border-2 border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shadow-xs font-bold text-xl sm:text-2xl select-none tracking-tight">
                  {initials}
                </div>
              )}

              {/* Status Dot Ring reflecting selected condition */}
              <span
                className={`absolute bottom-1 right-1 w-4 h-4 rounded-full ${activeConditionConfig.dotColor} ring-2 ring-surface dark:ring-ink transition-colors duration-200`}
                aria-label={`Status: ${activeConditionConfig.label}`}
              />
            </div>

            {/* Core Patient Identity */}
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2 mb-1.5">
                <span className="inline-flex items-center px-2.5 py-0.5 rounded-full bg-cream dark:bg-ink-soft/40 text-terracotta text-xs font-semibold uppercase tracking-wider">
                  Patient ID • {patient.id}
                </span>

                {/* Patient Care Status Badge (Evaluated by Backend Algorithms & Analysis) */}
                <span
                  className={`inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full text-xs font-semibold border ${activeConditionConfig.badgeBg} ${activeConditionConfig.badgeText} ${activeConditionConfig.badgeBorder} shadow-2xs transition-all duration-200`}
                  title="Condition determined automatically by backend algorithms and analysis"
                >
                  <span className={`w-1.5 h-1.5 rounded-full ${activeConditionConfig.dotColor}`} />
                  <span>{activeConditionConfig.label}</span>
                  <Sparkles className="w-3 h-3 text-current/70" />
                </span>
              </div>

              {/* Patient Full Name */}
              <h1 className="text-xl sm:text-2xl font-bold text-ink dark:text-cream tracking-tight truncate">
                {patient.name}
              </h1>

              {/* Demographics bar: Age, Gender, DOB */}
              <div className="flex flex-wrap items-center gap-x-3 gap-y-1 mt-1 text-xs sm:text-sm text-ink-soft dark:text-cream/70">
                <span>{patient.age} years old</span>
                <span>•</span>
                <span>{patient.gender || 'Not specified'}</span>
                {patient.dateOfBirth && (
                  <>
                    <span>•</span>
                    <span className="inline-flex items-center gap-1">
                      <Calendar className="w-3.5 h-3.5 text-terracotta/80" />
                      <span>DOB: {patient.dateOfBirth}</span>
                    </span>
                  </>
                )}
              </div>

              {/* Diagnosis / Health Issue Tag */}
              <div className="mt-3 flex items-start gap-1.5">
                <Activity className="w-4 h-4 text-terracotta shrink-0 mt-0.5" />
                <p className="text-xs sm:text-sm font-medium text-ink dark:text-cream/90 leading-snug">
                  {patient.healthIssue || patient.diagnosis || 'Cognitive Support Routine Active'}
                </p>
              </div>
            </div>
          </div>

          {/* Top-Right Action Controls: Paired Device Code & Profile Synced */}
          <div className="flex flex-col sm:items-end gap-3 shrink-0 w-full sm:w-auto">
            {/* 1. Paired Device Code Card */}
            <div className="w-full sm:w-auto flex items-center justify-between sm:justify-end gap-3 bg-cream/70 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-xl px-3.5 py-2 shadow-2xs">
              <div className="flex items-center gap-2.5 min-w-0">
                <div className="w-8 h-8 rounded-lg bg-terracotta/10 dark:bg-terracotta/20 text-terracotta flex items-center justify-center shrink-0">
                  <Tablet className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-ink-soft dark:text-cream/60">
                      Paired Device Code
                    </span>
                    <span
                      className={`w-1.5 h-1.5 rounded-full ${
                        patient.deviceStatus?.linked ? 'bg-sage animate-pulse' : 'bg-gold'
                      }`}
                      title={patient.deviceStatus?.linked ? 'Device Linked' : 'Ready to Pair'}
                    />
                  </div>
                  <div className="flex items-center gap-1.5 mt-0.5">
                    <code className="font-mono text-xs sm:text-sm font-bold text-ink dark:text-cream tracking-wider select-all">
                      {pairedCode}
                    </code>
                  </div>
                </div>
              </div>

              {/* Copy Code Button */}
              <button
                type="button"
                onClick={() => handleCopyDeviceCode(pairedCode)}
                className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-surface dark:bg-ink-soft/40 hover:bg-cream dark:hover:bg-ink border border-border/80 dark:border-ink-soft/60 text-xs font-semibold text-ink dark:text-cream transition-all active:scale-95 shrink-0 shadow-2xs cursor-pointer select-none"
                title="Copy Paired Device Code"
                aria-label="Copy Paired Device Code"
              >
                {copiedCode ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-sage" />
                    <span className="text-xs font-bold text-sage">Copied!</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5 text-ink-soft dark:text-cream/70" />
                    <span>Copy</span>
                  </>
                )}
              </button>
            </div>


            {/* Profile Synced Badge */}
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-sage/15 text-sage border border-sage/30 text-[11px] font-semibold shadow-2xs">
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Profile Synced</span>
            </div>
          </div>
        </div>
      </section>

      {/* 2 & 3. Secondary Info Section: Emergency Contact & Device Pairing */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Emergency Contact Section */}
        <section
          aria-label="Emergency Contact"
          className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-sm transition-colors"
        >
          <div className="flex items-center justify-between gap-2 mb-4 pb-3 border-b border-border/60 dark:border-ink-soft/30">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta">
                <Phone className="w-4 h-4" />
              </div>
              <h2 className="text-base font-bold text-ink dark:text-cream">
                Emergency Contact
              </h2>
            </div>
            <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-cream dark:bg-ink-soft/40 text-terracotta border border-border/60 dark:border-ink-soft/30">
              Primary
            </span>
          </div>

          {patient.emergencyContact ? (
            <div className="space-y-3">
              <div>
                <p className="text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/60 mb-0.5">
                  Contact Name & Relationship
                </p>
                <p className="text-sm sm:text-base font-bold text-ink dark:text-cream">
                  {patient.emergencyContact.name}
                </p>
                <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70">
                  {patient.emergencyContact.relationship}
                </p>
              </div>

              <div className="pt-2">
                <p className="text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/60 mb-1">
                  Phone Number
                </p>
                <a
                  href={`tel:${patient.emergencyContact.phone.replace(/\s+/g, '')}`}
                  className="inline-flex items-center gap-2 text-sm font-semibold text-terracotta hover:text-terracotta-dark transition-colors"
                >
                  <Phone className="w-3.5 h-3.5" />
                  <span>{patient.emergencyContact.phone}</span>
                </a>
              </div>
            </div>
          ) : (
            <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70">
              No emergency contact configured yet.
            </p>
          )}
        </section>

        {/* Pairing / Device Status Section */}
        <section
          aria-label="Device Pairing Status"
          className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-sm transition-colors"
        >
          <div className="flex items-center justify-between gap-2 mb-4 pb-3 border-b border-border/60 dark:border-ink-soft/30">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-sage">
                <Tablet className="w-4 h-4" />
              </div>
              <h2 className="text-base font-bold text-ink dark:text-cream">
                Pairing & Device Status
              </h2>
            </div>
            {patient.deviceStatus?.linked ? (
              <span className="inline-flex items-center gap-1 text-xs font-semibold px-2 py-0.5 rounded-full bg-sage/15 text-sage border border-sage/30">
                <CheckCircle2 className="w-3 h-3" />
                <span>Linked</span>
              </span>
            ) : (
              <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-gold/15 text-gold border border-gold/30">
                Unpaired
              </span>
            )}
          </div>

          {patient.deviceStatus ? (
            <div className="space-y-3">
              <div>
                <p className="text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/60 mb-0.5">
                  Linked Hardware Unit
                </p>
                <p className="text-sm sm:text-base font-bold text-ink dark:text-cream">
                  {patient.deviceStatus.deviceName || 'Patient Tablet'}
                </p>
                <div className="flex items-center gap-2 mt-1">
                  <p className="text-xs text-ink-soft dark:text-cream/70 font-mono">
                    Paired Code: <span className="font-bold text-ink dark:text-cream">{pairedCode}</span>
                  </p>
                  <button
                    type="button"
                    onClick={() => handleCopyDeviceCode(pairedCode)}
                    className="text-[11px] text-terracotta hover:underline font-semibold cursor-pointer"
                  >
                    {copiedCode ? 'Copied' : 'Copy'}
                  </button>
                </div>
              </div>

              <div className="pt-2 flex items-center gap-1.5 text-xs text-ink-soft dark:text-cream/70">
                <Clock className="w-3.5 h-3.5 text-terracotta/80 shrink-0" />
                <span>Last Synced: {patient.deviceStatus.lastSynced || patient.lastCheckIn || 'Recent'}</span>
              </div>
            </div>
          ) : (
            <div className="space-y-2">
              <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70">
                Tablet pairing code is ready to connect.
              </p>
              <div className="flex items-center gap-2">
                <code className="font-mono font-bold text-xs bg-cream dark:bg-ink-soft/40 px-2 py-1 rounded border border-border/80">
                  {pairedCode}
                </code>
                <button
                  type="button"
                  onClick={() => handleCopyDeviceCode(pairedCode)}
                  className="text-xs text-terracotta font-semibold hover:underline cursor-pointer"
                >
                  {copiedCode ? 'Copied' : 'Copy'}
                </button>
              </div>
            </div>
          )}
        </section>
      </div>

      {/* 4. REAL RECENT ACTIVITY & SCHEDULE SUMMARY CARDS */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Recent Activity Summary Card */}
        <section
          aria-label="Recent Activity Summary"
          className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-sm transition-colors flex flex-col justify-between"
        >
          <div>
            <div className="flex items-center justify-between gap-2 mb-4 pb-3 border-b border-border/60 dark:border-ink-soft/30">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta">
                  <HeartPulse className="w-4 h-4" />
                </div>
                <h2 className="text-base font-bold text-ink dark:text-cream">
                  Recent Activity Summary
                </h2>
              </div>
              <Link
                to={`/patients/${id}/analytics#session-history`}
                className="inline-flex items-center gap-1 text-xs font-bold text-terracotta hover:text-terracotta-dark transition-colors group"
              >
                <span>View all</span>
                <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-0.5 transition-transform" />
              </Link>
            </div>

            {recentSessions.length > 0 ? (
              <div className="space-y-2.5">
                {recentSessions.map((session) => {
                  const domainCfg = DOMAIN_CONFIG[session.domain] || DOMAIN_CONFIG.memory;
                  return (
                    <Link
                      key={session.session_id}
                      to={`/patients/${id}/analytics#session-history`}
                      className="flex items-center justify-between gap-3 p-2.5 rounded-lg bg-cream/50 dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/40 border border-border/60 dark:border-ink-soft/30 transition-all text-xs group"
                    >
                      <div className="flex items-center gap-2.5 min-w-0">
                        <div className="w-7 h-7 rounded-full bg-surface dark:bg-ink-soft/40 flex items-center justify-center border border-border/60 dark:border-ink-soft/30 shrink-0">
                          {getDomainIcon(session.domain)}
                        </div>
                        <div className="min-w-0">
                          <p className="font-bold text-ink dark:text-cream truncate group-hover:text-terracotta transition-colors">
                            {getGameLabel(session.game_type)}
                          </p>
                          <p className="text-[11px] text-ink-soft dark:text-cream/60">
                            {formatSessionDate(session.session_date, true)}
                          </p>
                        </div>
                      </div>

                      <div className="text-right shrink-0">
                        <span
                          className="inline-block font-bold text-xs px-2 py-0.5 rounded-full border"
                          style={{
                            backgroundColor: `${domainCfg.color}15`,
                            borderColor: `${domainCfg.color}30`,
                            color: domainCfg.color,
                          }}
                        >
                          {Math.round(session.score_normalized * 100)}%
                        </span>
                        <p className="text-[10px] text-ink-soft dark:text-cream/60 mt-0.5">
                          Lvl {session.difficulty_level}
                        </p>
                      </div>
                    </Link>
                  );
                })}
              </div>
            ) : (
              <div className="py-6 text-center text-xs text-ink-soft dark:text-cream/60">
                No recent game activity recorded yet.
              </div>
            )}
          </div>

          <div className="mt-4 pt-3 border-t border-border/60 dark:border-ink-soft/30 flex items-center justify-between text-[11px] text-ink-soft dark:text-cream/70">
            <span>30-Day Cognitive Telemetry</span>
            <Link
              to={`/patients/${id}/analytics`}
              className="font-semibold text-terracotta hover:underline"
            >
              Explore Trends →
            </Link>
          </div>
        </section>

        {/* Schedule & Reminders Summary Card */}
        <section
          aria-label="Schedule and Reminders"
          className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-sm transition-colors flex flex-col justify-between"
        >
          <div>
            <div className="flex items-center justify-between gap-2 mb-4 pb-3 border-b border-border/60 dark:border-ink-soft/30">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-gold">
                  <Clock className="w-4 h-4" />
                </div>
                <h2 className="text-base font-bold text-ink dark:text-cream">
                  Schedule & Reminders
                </h2>
              </div>
              <Link
                to={`/patients/${id}/care-plan`}
                className="inline-flex items-center gap-1 text-xs font-bold text-terracotta hover:text-terracotta-dark transition-colors group"
              >
                <span>View Care Plan</span>
                <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-0.5 transition-transform" />
              </Link>
            </div>

            {remindersList.length > 0 ? (
              <div className="space-y-2.5">
                {remindersList.map((rem) => {
                  const IconComponent = rem.icon;
                  return (
                    <Link
                      key={rem.id}
                      to={`/patients/${id}/care-plan`}
                      className={`flex items-center justify-between gap-3 p-2.5 rounded-lg border transition-all text-xs group ${
                        rem.isMissed
                          ? 'bg-gold/10 dark:bg-gold/15 border-gold/40 hover:bg-gold/15'
                          : 'bg-cream/50 dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/40 border-border/60 dark:border-ink-soft/30'
                      }`}
                    >
                      <div className="flex items-center gap-2.5 min-w-0">
                        <div
                          className={`w-7 h-7 rounded-full flex items-center justify-center shrink-0 ${
                            rem.isMissed
                              ? 'bg-gold/20 text-gold border border-gold/40'
                              : 'bg-surface dark:bg-ink-soft/40 text-ink-soft dark:text-cream border border-border/60 dark:border-ink-soft/30'
                          }`}
                        >
                          <IconComponent className="w-3.5 h-3.5" />
                        </div>
                        <div className="min-w-0">
                          <p className="font-bold text-ink dark:text-cream truncate group-hover:text-terracotta transition-colors">
                            {rem.label}
                          </p>
                          <p className="text-[11px] text-ink-soft dark:text-cream/60">
                            {rem.category}
                          </p>
                        </div>
                      </div>

                      <div className="text-right shrink-0">
                        {rem.isMissed ? (
                          <span className="inline-flex items-center gap-1 text-[11px] font-bold px-2 py-0.5 rounded-full bg-gold/20 text-gold border border-gold/40">
                            <AlertTriangle className="w-3 h-3" />
                            <span>Missed</span>
                          </span>
                        ) : (
                          <span className="font-semibold text-xs text-ink dark:text-cream px-2 py-0.5 rounded-md bg-cream dark:bg-ink-soft/40 border border-border/60 dark:border-ink-soft/30">
                            {rem.time}
                          </span>
                        )}
                      </div>
                    </Link>
                  );
                })}
              </div>
            ) : (
              <div className="py-6 text-center text-xs text-ink-soft dark:text-cream/60">
                No reminders scheduled for this patient.
              </div>
            )}
          </div>

          <div className="mt-4 pt-3 border-t border-border/60 dark:border-ink-soft/30 flex items-center justify-between text-[11px] text-ink-soft dark:text-cream/70">
            <span>Daily Routine Plan</span>
            <Link
              to={`/patients/${id}/care-plan`}
              className="font-semibold text-terracotta hover:underline"
            >
              Manage Routine →
            </Link>
          </div>
        </section>
      </div>
    </div>
  );
};

export default PatientDetails;
