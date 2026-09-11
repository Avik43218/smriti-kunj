import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { getPatientById, getCareStatusConfig, deletePatient, updatePatient } from '../services/patientService';
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
  Sparkles,
  Trash2,
  Scale,
  Apple,
  Wine,
  Cigarette,
  Camera,
  Pencil,
  Upload,
  X,
  Save,
  Check,
} from 'lucide-react';

const DIAGNOSIS_OPTIONS = [
  'Mild Cognitive Impairment (MCI)',
  "Early Stage Alzheimer's",
  'Vascular Dementia',
  'Frontotemporal Dementia',
  'Subjective Cognitive Decline (SCD)',
  'Age-Associated Memory Impairment',
  'Other / Under Observation',
];

const DIABETIC_OPTIONS = [
  'Non-Diabetic',
  'Pre-Diabetic',
  'Type 2 Diabetic (Diet Controlled)',
  'Type 2 Diabetic (Insulin / Medication)',
  'Type 1 Diabetic',
  'Under Observation / Borderline',
];

const NUTRITION_DIET_OPTIONS = [
  'Healthy & Balanced (Regular nutritious meals)',
  'Fair / Moderate Diet (Occasional irregular intake)',
  'Needs Improvement (Poor appetite / skips meals)',
  'Specialized Diabetic / Low-Sodium Diet',
  'Liquid / Soft Food Assisted Diet',
];

const ALCOHOL_OPTIONS = [
  'None / Non-Drinker',
  'Occasional / Light (< 1 drink/week)',
  'Moderate (1-2 drinks/week)',
  'Frequent / Heavy (> 2 drinks/week)',
  'Past History (Now Abstinent)',
];

const SMOKING_OPTIONS = [
  'Non-Smoker',
  'Former Smoker (Quit)',
  'Occasional / Light Smoker',
  'Active / Regular Smoker',
];

const GENDER_OPTIONS = ['Male', 'Female', 'Other', 'Prefer not to say'];

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
  const navigate = useNavigate();
  const [patient, setPatient] = useState(null);
  const [recentSessions, setRecentSessions] = useState([]);
  const [remindersList, setRemindersList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState(null);

  // Edit Profile State
  const [showEditModal, setShowEditModal] = useState(false);
  const [isSavingEdit, setIsSavingEdit] = useState(false);
  const [editError, setEditError] = useState(null);
  const [photoFeedback, setPhotoFeedback] = useState('');
  const [editFormData, setEditFormData] = useState({
    name: '',
    age: '',
    gender: 'Male',
    dateOfBirth: '',
    diagnosis: 'Mild Cognitive Impairment (MCI)',
    healthIssue: '',
    notes: '',
    weight: '',
    diabetic: 'Non-Diabetic',
    nutritionDiet: 'Healthy & Balanced (Regular nutritious meals)',
    alcoholLevel: 'None / Non-Drinker',
    smokingStatus: 'Non-Smoker',
    avatarUrl: null,
    emergencyContact: {
      name: '',
      relationship: '',
      phone: '',
    },
  });

  const openEditModal = () => {
    if (!patient) return;
    setEditFormData({
      name: patient.name || '',
      age: patient.age ? String(patient.age) : '',
      gender: patient.gender || 'Male',
      dateOfBirth: patient.dateOfBirth && patient.dateOfBirth !== 'Not specified' ? patient.dateOfBirth : '',
      diagnosis: patient.diagnosis || 'Mild Cognitive Impairment (MCI)',
      healthIssue: patient.healthIssue || '',
      notes: patient.notes || '',
      weight: (patient.weight || '').replace(/\s*kg$/i, ''),
      diabetic: patient.diabetic || 'Non-Diabetic',
      nutritionDiet: patient.nutritionDiet || 'Healthy & Balanced (Regular nutritious meals)',
      alcoholLevel: patient.alcoholLevel || 'None / Non-Drinker',
      smokingStatus: patient.smokingStatus || 'Non-Smoker',
      avatarUrl: patient.avatarUrl || null,
      emergencyContact: {
        name: patient.emergencyContact?.name || '',
        relationship: patient.emergencyContact?.relationship || '',
        phone: patient.emergencyContact?.phone || '',
      },
    });
    setEditError(null);
    setShowEditModal(true);
  };

  const handleDirectPhotoUpload = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      setPhotoFeedback('Image exceeds 5MB limit.');
      setTimeout(() => setPhotoFeedback(''), 3000);
      return;
    }
    const reader = new FileReader();
    reader.onload = async (event) => {
      const dataUrl = event.target.result;
      try {
        await updatePatient(patient.id, { avatarUrl: dataUrl });
        setPatient((prev) => ({ ...prev, avatarUrl: dataUrl }));
        setPhotoFeedback('Photo updated successfully!');
        setTimeout(() => setPhotoFeedback(''), 3000);
      } catch (err) {
        setPhotoFeedback('Failed to update photo.');
        setTimeout(() => setPhotoFeedback(''), 3000);
      }
    };
    reader.readAsDataURL(file);
  };

  const handleEditModalPhotoUpload = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      setEditError('Selected photo exceeds 5MB limit.');
      return;
    }
    const reader = new FileReader();
    reader.onload = (event) => {
      const dataUrl = event.target.result;
      setEditFormData((prev) => ({ ...prev, avatarUrl: dataUrl }));
    };
    reader.readAsDataURL(file);
  };

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    if (!editFormData.name.trim()) {
      setEditError('Patient name is required.');
      return;
    }
    try {
      setIsSavingEdit(true);
      setEditError(null);

      const effectiveWeight = editFormData.weight.trim()
        ? editFormData.weight.trim().toLowerCase().endsWith('kg')
          ? editFormData.weight.trim()
          : `${editFormData.weight.trim()} kg`
        : 'Not recorded';

      const updatedPayload = {
        name: editFormData.name.trim(),
        age: editFormData.age ? parseInt(editFormData.age, 10) : patient.age,
        gender: editFormData.gender,
        dateOfBirth: editFormData.dateOfBirth || patient.dateOfBirth,
        diagnosis: editFormData.diagnosis,
        healthIssue: editFormData.healthIssue.trim() || patient.healthIssue,
        notes: editFormData.notes.trim() || patient.notes,
        weight: effectiveWeight,
        diabetic: editFormData.diabetic,
        nutritionDiet: editFormData.nutritionDiet,
        alcoholLevel: editFormData.alcoholLevel,
        smokingStatus: editFormData.smokingStatus,
        avatarUrl: editFormData.avatarUrl,
        emergencyContact: {
          name: editFormData.emergencyContact.name.trim() || patient.emergencyContact?.name || 'Primary Guardian',
          relationship: editFormData.emergencyContact.relationship.trim() || patient.emergencyContact?.relationship || 'Guardian',
          phone: editFormData.emergencyContact.phone.trim() || patient.emergencyContact?.phone || '',
        },
      };

      await updatePatient(patient.id, updatedPayload);
      setPatient((prev) => ({
        ...prev,
        ...updatedPayload,
      }));
      setIsSavingEdit(false);
      setShowEditModal(false);
    } catch (err) {
      setEditError(err?.message || 'Failed to save patient changes.');
      setIsSavingEdit(false);
    }
  };

  const handleDeletePatient = async () => {
    try {
      setIsDeleting(true);
      setDeleteError(null);
      await deletePatient(patient.id);
      navigate('/dashboard');
    } catch (err) {
      setDeleteError(err?.message || 'Failed to delete patient profile.');
      setIsDeleting(false);
    }
  };

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
      case 'working_memory':
      case 'episodic_memory':
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
      case 'market_trip':
        return 'Market Trip';
      case 'tap_target':
        return 'Tap Target';
      case 'visual_search':
        return 'Visual Search';
      case 'word_association':
        return 'Word Association';
      default:
        return gameType
          ? gameType.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
          : 'Cognitive Game';
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
            {/* Large Circular Photo / Avatar with Initials Fallback & Photo Upload */}
            <div className="relative shrink-0 group">
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
                className={`absolute bottom-0.5 right-0.5 w-4 h-4 rounded-full ${activeConditionConfig.dotColor} ring-2 ring-surface dark:ring-ink transition-colors duration-200 z-10`}
                aria-label={`Status: ${activeConditionConfig.label}`}
              />

              {/* Hover Camera Overlay for quick direct upload */}
              <label
                htmlFor="direct-photo-input"
                className="absolute inset-0 rounded-full bg-black/50 text-cream flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer z-20 backdrop-blur-2xs"
                title="Click to upload or change patient photo"
              >
                <Camera className="w-5 h-5 text-cream drop-shadow" />
                <span className="text-[9px] font-bold uppercase tracking-wider mt-0.5 text-cream">Photo</span>
                <input
                  id="direct-photo-input"
                  type="file"
                  accept="image/*"
                  onChange={handleDirectPhotoUpload}
                  className="sr-only"
                />
              </label>

              {/* Mobile photo trigger badge */}
              <label
                htmlFor="direct-photo-input"
                className="sm:hidden absolute -bottom-1 -left-1 w-6 h-6 rounded-full bg-terracotta text-cream flex items-center justify-center shadow-xs cursor-pointer z-20"
                title="Upload Photo"
              >
                <Camera className="w-3.5 h-3.5" />
              </label>
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

              {/* Demographics bar: Age, Gender, Weight, DOB */}
              <div className="flex flex-wrap items-center gap-x-3 gap-y-1 mt-1 text-xs sm:text-sm text-ink-soft dark:text-cream/70">
                <span>{patient.age} years old</span>
                <span>•</span>
                <span>{patient.gender || 'Not specified'}</span>
                {patient.weight && patient.weight !== 'Not recorded' && (
                  <>
                    <span>•</span>
                    <span className="inline-flex items-center gap-1 font-medium text-ink dark:text-cream">
                      <Scale className="w-3.5 h-3.5 text-terracotta/80" />
                      <span>{patient.weight}</span>
                    </span>
                  </>
                )}
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

          {/* Top-Right Action Controls: Paired Device Code, Profile Synced, Delete Patient */}
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
                    <code className="font-mono text-xs sm:text-sm font-bold text-ink dark:text-cream tracking-wider">
                      {pairedCode}
                    </code>
                  </div>
                </div>
              </div>
            </div>

            {/* Top Action Controls: Edit Profile, Profile Synced, Delete Patient */}
            <div className="flex items-center flex-wrap gap-2">
              <button
                type="button"
                onClick={openEditModal}
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-terracotta/10 hover:bg-terracotta/20 text-terracotta border border-terracotta/30 text-[11px] font-semibold transition-colors cursor-pointer select-none"
                title="Edit Patient Details"
              >
                <Pencil className="w-3.5 h-3.5" />
                <span>Edit Profile</span>
              </button>

              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-sage/15 text-sage border border-sage/30 text-[11px] font-semibold shadow-2xs">
                <ShieldCheck className="w-3.5 h-3.5" />
                <span>Profile Synced</span>
              </div>

              <button
                type="button"
                onClick={() => setShowDeleteModal(true)}
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-alert/10 hover:bg-alert/20 text-alert border border-alert/30 text-[11px] font-semibold transition-colors cursor-pointer select-none"
                title="Delete Patient Profile"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Delete</span>
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* 2. Physical Health & Lifestyle Profile Section */}
      <section
        aria-label="Physical Health and Lifestyle Profile"
        className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 shadow-sm transition-colors"
      >
        <div className="flex items-center justify-between gap-2 mb-4 pb-3 border-b border-border/60 dark:border-ink-soft/30">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 flex items-center justify-center text-terracotta shrink-0 shadow-xs">
              <Activity className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base font-bold text-ink dark:text-cream">
                Physical Health & Lifestyle Profile
              </h2>
              <p className="text-[11px] text-ink-soft dark:text-cream/60">
                Metabolic baseline, nutritional patterns, and lifestyle risk factors for daily care.
              </p>
            </div>
          </div>
          <span className="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-sage/15 text-sage border border-sage/30 text-xs font-semibold">
            <CheckCircle2 className="w-3.5 h-3.5" />
            <span>Vitals Active</span>
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3.5">
          {/* 1. Body Weight */}
          <div className="p-3.5 sm:p-4 rounded-xl bg-cream/40 dark:bg-ink-soft/25 border border-border/70 dark:border-ink-soft/30 flex flex-col justify-between h-full transition-all shadow-2xs">
            <div className="flex items-center justify-between gap-2 pb-2.5 border-b border-border/50 dark:border-ink-soft/30">
              <span className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider truncate">
                Body Weight
              </span>
              <div className="w-6 h-6 rounded-md bg-terracotta/10 text-terracotta flex items-center justify-center shrink-0">
                <Scale className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="py-2.5 flex-1 flex flex-col justify-center min-h-[44px]">
              <p className="text-sm sm:text-base font-bold text-ink dark:text-cream leading-snug truncate" title={patient.weight || 'Not recorded'}>
                {patient.weight || 'Not recorded'}
              </p>
            </div>
            <div className="pt-2 border-t border-border/40 dark:border-ink-soft/20 flex items-center">
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border bg-terracotta/15 text-terracotta border-terracotta/30">
                Physical Baseline
              </span>
            </div>
          </div>

          {/* 2. Diabetic Status */}
          <div className="p-3.5 sm:p-4 rounded-xl bg-cream/40 dark:bg-ink-soft/25 border border-border/70 dark:border-ink-soft/30 flex flex-col justify-between h-full transition-all shadow-2xs">
            <div className="flex items-center justify-between gap-2 pb-2.5 border-b border-border/50 dark:border-ink-soft/30">
              <span className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider truncate">
                Diabetic Status
              </span>
              <div className="w-6 h-6 rounded-md bg-sage/10 text-sage flex items-center justify-center shrink-0">
                <Activity className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="py-2.5 flex-1 flex flex-col justify-center min-h-[44px]">
              <p className="text-sm sm:text-base font-bold text-ink dark:text-cream leading-snug line-clamp-2" title={patient.diabetic || 'Non-Diabetic'}>
                {patient.diabetic || 'Non-Diabetic'}
              </p>
            </div>
            <div className="pt-2 border-t border-border/40 dark:border-ink-soft/20 flex items-center">
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${
                (patient.diabetic || '').toLowerCase().includes('non')
                  ? 'bg-sage/15 text-sage border-sage/30'
                  : 'bg-gold/15 text-gold border-gold/30'
              }`}>
                {(patient.diabetic || '').toLowerCase().includes('non') ? 'Normal Range' : 'Managed Care'}
              </span>
            </div>
          </div>

          {/* 3. Nutrition & Diet */}
          <div className="p-3.5 sm:p-4 rounded-xl bg-cream/40 dark:bg-ink-soft/25 border border-border/70 dark:border-ink-soft/30 flex flex-col justify-between h-full transition-all shadow-2xs">
            <div className="flex items-center justify-between gap-2 pb-2.5 border-b border-border/50 dark:border-ink-soft/30">
              <span className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider truncate">
                Nutrition & Diet
              </span>
              <div className="w-6 h-6 rounded-md bg-gold/10 text-gold flex items-center justify-center shrink-0">
                <Apple className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="py-2.5 flex-1 flex flex-col justify-center min-h-[44px]">
              <p className="text-xs sm:text-sm font-bold text-ink dark:text-cream leading-snug line-clamp-2" title={patient.nutritionDiet || 'Healthy & Balanced'}>
                {patient.nutritionDiet || 'Healthy & Balanced'}
              </p>
            </div>
            <div className="pt-2 border-t border-border/40 dark:border-ink-soft/20 flex items-center">
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${
                (patient.nutritionDiet || '').toLowerCase().includes('healthy') || (patient.nutritionDiet || '').toLowerCase().includes('balanced')
                  ? 'bg-sage/15 text-sage border-sage/30'
                  : (patient.nutritionDiet || '').toLowerCase().includes('specialized')
                  ? 'bg-terracotta/15 text-terracotta border-terracotta/30'
                  : 'bg-gold/15 text-gold border-gold/30'
              }`}>
                {(patient.nutritionDiet || '').toLowerCase().includes('healthy') || (patient.nutritionDiet || '').toLowerCase().includes('balanced')
                  ? 'Eats Healthy: Yes'
                  : (patient.nutritionDiet || '').toLowerCase().includes('specialized')
                  ? 'Specialized Diet'
                  : 'Needs Monitoring'}
              </span>
            </div>
          </div>

          {/* 4. Alcohol Intake */}
          <div className="p-3.5 sm:p-4 rounded-xl bg-cream/40 dark:bg-ink-soft/25 border border-border/70 dark:border-ink-soft/30 flex flex-col justify-between h-full transition-all shadow-2xs">
            <div className="flex items-center justify-between gap-2 pb-2.5 border-b border-border/50 dark:border-ink-soft/30">
              <span className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider truncate">
                Alcohol Intake
              </span>
              <div className="w-6 h-6 rounded-md bg-terracotta/10 text-terracotta flex items-center justify-center shrink-0">
                <Wine className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="py-2.5 flex-1 flex flex-col justify-center min-h-[44px]">
              <p className="text-sm sm:text-base font-bold text-ink dark:text-cream leading-snug line-clamp-2" title={patient.alcoholLevel || 'None / Non-Drinker'}>
                {patient.alcoholLevel || 'None / Non-Drinker'}
              </p>
            </div>
            <div className="pt-2 border-t border-border/40 dark:border-ink-soft/20 flex items-center">
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${
                (patient.alcoholLevel || '').toLowerCase().includes('none')
                  ? 'bg-sage/15 text-sage border-sage/30'
                  : 'bg-cream dark:bg-ink-soft/50 text-ink-soft dark:text-cream/80 border-border/60'
              }`}>
                {(patient.alcoholLevel || '').toLowerCase().includes('none') ? 'Zero Intake' : 'Tracked Intake'}
              </span>
            </div>
          </div>

          {/* 5. Smoking Status */}
          <div className="p-3.5 sm:p-4 rounded-xl bg-cream/40 dark:bg-ink-soft/25 border border-border/70 dark:border-ink-soft/30 flex flex-col justify-between h-full transition-all shadow-2xs sm:col-span-2 lg:col-span-1">
            <div className="flex items-center justify-between gap-2 pb-2.5 border-b border-border/50 dark:border-ink-soft/30">
              <span className="text-[11px] font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider truncate">
                Smoking Status
              </span>
              <div className="w-6 h-6 rounded-md bg-gold/10 text-gold flex items-center justify-center shrink-0">
                <Cigarette className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="py-2.5 flex-1 flex flex-col justify-center min-h-[44px]">
              <p className="text-sm sm:text-base font-bold text-ink dark:text-cream leading-snug line-clamp-2" title={patient.smokingStatus || 'Non-Smoker'}>
                {patient.smokingStatus || 'Non-Smoker'}
              </p>
            </div>
            <div className="pt-2 border-t border-border/40 dark:border-ink-soft/20 flex items-center">
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${
                (patient.smokingStatus || '').toLowerCase().includes('non') || (patient.smokingStatus || '').toLowerCase().includes('quit')
                  ? 'bg-sage/15 text-sage border-sage/30'
                  : 'bg-alert/15 text-alert border-alert/30'
              }`}>
                {(patient.smokingStatus || '').toLowerCase().includes('non') ? 'Non-Smoker' : (patient.smokingStatus || '').toLowerCase().includes('quit') ? 'Former Smoker' : 'Active Smoker'}
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* 3 & 4. Secondary Info Section: Emergency Contact & Device Pairing */}
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
                <CheckCircle2 className="w-3.5 h-3.5" />
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
                    Paired Device Code: <span className="font-bold text-ink dark:text-cream">{pairedCode}</span>
                  </p>
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
                Paired device code is ready to connect.
              </p>
              <div className="flex items-center gap-2">
                <code className="font-mono font-bold text-xs bg-cream dark:bg-ink-soft/40 px-2.5 py-1 rounded border border-border/80 text-ink dark:text-cream">
                  {pairedCode}
                </code>
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

      {/* 5. Delete Patient Confirmation Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="bg-surface dark:bg-ink border border-border/80 dark:border-ink-soft/60 rounded-2xl max-w-md w-full p-6 shadow-xl space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-alert/15 text-alert flex items-center justify-center shrink-0">
                <AlertCircle className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-lg font-bold text-ink dark:text-cream">
                  Delete Patient Profile
                </h3>
                <p className="text-xs text-ink-soft dark:text-cream/60">
                  Confirm patient removal
                </p>
              </div>
            </div>

            <p className="text-sm text-ink-soft dark:text-cream/80 leading-relaxed">
              Are you sure you want to delete <strong className="text-ink dark:text-cream">{patient.name}</strong> ({patient.id})? This will permanently remove their profile, cognitive telemetry records, and device pairing token.
            </p>

            {deleteError && (
              <p className="text-xs text-alert font-medium bg-alert/10 p-2.5 rounded-lg border border-alert/30">
                {deleteError}
              </p>
            )}

            <div className="flex items-center justify-end gap-2.5 pt-2">
              <button
                type="button"
                disabled={isDeleting}
                onClick={() => setShowDeleteModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-ink-soft dark:text-cream/70 hover:bg-cream dark:hover:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isDeleting}
                onClick={handleDeletePatient}
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-semibold text-cream bg-alert hover:bg-red-700 active:scale-95 transition-all shadow-xs disabled:opacity-60 disabled:cursor-not-allowed"
              >
                {isDeleting ? (
                  <>
                    <div className="w-3.5 h-3.5 border-2 border-cream border-t-transparent rounded-full animate-spin" />
                    <span>Deleting...</span>
                  </>
                ) : (
                  <>
                    <Trash2 className="w-3.5 h-3.5" />
                    <span>Delete Patient</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 6. Edit Patient Details Modal */}
      {showEditModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="bg-surface dark:bg-ink border border-border/80 dark:border-ink-soft/60 rounded-2xl max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
            {/* Modal Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-border/60 dark:border-ink-soft/30 bg-cream/40 dark:bg-ink-soft/20">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-terracotta/15 text-terracotta flex items-center justify-center shrink-0">
                  <Pencil className="w-4 h-4" />
                </div>
                <div>
                  <h3 className="text-base sm:text-lg font-bold text-ink dark:text-cream">
                    Edit Patient Profile
                  </h3>
                  <p className="text-[11px] text-ink-soft dark:text-cream/60">
                    Update demographics, health condition, lifestyle vitals, and emergency contact.
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setShowEditModal(false)}
                className="w-8 h-8 rounded-full flex items-center justify-center text-ink-soft dark:text-cream/70 hover:bg-cream dark:hover:bg-ink-soft/40 transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Modal Body - Scrollable */}
            <form id="edit-patient-form" onSubmit={handleSaveEdit} className="flex-1 overflow-y-auto p-6 space-y-6">
              {editError && (
                <div className="p-3 rounded-xl bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2 font-medium">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  <span>{editError}</span>
                </div>
              )}

              {/* Photo Upload Section */}
              <div className="flex items-center gap-4 p-3.5 rounded-xl bg-cream/40 dark:bg-ink-soft/20 border border-border/70 dark:border-ink-soft/30">
                <div className="relative shrink-0">
                  {editFormData.avatarUrl ? (
                    <img
                      src={editFormData.avatarUrl}
                      alt="Preview"
                      className="w-16 h-16 rounded-full object-cover border-2 border-border/80 dark:border-ink-soft/40 shadow-xs"
                    />
                  ) : (
                    <div className="w-16 h-16 rounded-full bg-cream dark:bg-ink-soft/40 border-2 border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta font-bold text-lg select-none">
                      {getInitials(editFormData.name || patient.name)}
                    </div>
                  )}
                </div>
                <div className="space-y-1.5 flex-1 min-w-0">
                  <p className="text-xs font-semibold text-ink dark:text-cream">Patient Profile Photo</p>
                  <p className="text-[11px] text-ink-soft dark:text-cream/60">JPG, PNG, or WEBP up to 5MB.</p>
                  <div className="flex items-center gap-2 pt-1">
                    <label
                      htmlFor="modal-photo-upload"
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-terracotta hover:bg-terracotta-dark text-cream text-xs font-medium cursor-pointer transition-colors shadow-2xs"
                    >
                      <Upload className="w-3.5 h-3.5" />
                      <span>{editFormData.avatarUrl ? 'Change Photo' : 'Upload Photo'}</span>
                      <input
                        id="modal-photo-upload"
                        type="file"
                        accept="image/*"
                        onChange={handleEditModalPhotoUpload}
                        className="sr-only"
                      />
                    </label>
                    {editFormData.avatarUrl && (
                      <button
                        type="button"
                        onClick={() => setEditFormData((prev) => ({ ...prev, avatarUrl: null }))}
                        className="px-2.5 py-1.5 rounded-lg bg-cream dark:bg-ink-soft/40 hover:bg-alert/10 hover:text-alert text-ink-soft dark:text-cream/70 text-xs font-medium transition-colors border border-border/60 dark:border-ink-soft/40"
                      >
                        Remove
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Personal Demographics */}
              <div className="space-y-3">
                <h4 className="text-xs font-bold uppercase tracking-wider text-terracotta">
                  Personal & Demographics
                </h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="sm:col-span-2">
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Full Name *
                    </label>
                    <input
                      type="text"
                      value={editFormData.name}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, name: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Age (Years)
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="120"
                      value={editFormData.age}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, age: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Gender
                    </label>
                    <select
                      value={editFormData.gender}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, gender: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 cursor-pointer"
                    >
                      {GENDER_OPTIONS.map((g) => (
                        <option key={g} value={g} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                          {g}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="sm:col-span-2">
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Date of Birth
                    </label>
                    <input
                      type="text"
                      value={editFormData.dateOfBirth}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, dateOfBirth: e.target.value }))}
                      placeholder="e.g. March 14, 1954"
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                    />
                  </div>
                </div>
              </div>

              {/* Clinical Profile */}
              <div className="space-y-3">
                <h4 className="text-xs font-bold uppercase tracking-wider text-terracotta">
                  Clinical Diagnosis & Condition
                </h4>
                <div className="space-y-3">
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Primary Diagnosis
                    </label>
                    <select
                      value={editFormData.diagnosis}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, diagnosis: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 cursor-pointer"
                    >
                      {DIAGNOSIS_OPTIONS.map((opt) => (
                        <option key={opt} value={opt} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                          {opt}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Health Condition Summary
                    </label>
                    <input
                      type="text"
                      value={editFormData.healthIssue}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, healthIssue: e.target.value }))}
                      placeholder="e.g. Mild Cognitive Impairment (MCI) • Early-stage recall decline"
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Caregiver Routine Notes
                    </label>
                    <textarea
                      rows={2}
                      value={editFormData.notes}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, notes: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 resize-y"
                    />
                  </div>
                </div>
              </div>

              {/* Physical Vitals & Lifestyle */}
              <div className="space-y-3">
                <h4 className="text-xs font-bold uppercase tracking-wider text-terracotta">
                  Physical Vitals & Lifestyle Factors
                </h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Body Weight (kg)
                    </label>
                    <input
                      type="number"
                      step="0.1"
                      value={editFormData.weight}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, weight: e.target.value }))}
                      placeholder="e.g. 68"
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Diabetic Status
                    </label>
                    <select
                      value={editFormData.diabetic}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, diabetic: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 cursor-pointer"
                    >
                      {DIABETIC_OPTIONS.map((opt) => (
                        <option key={opt} value={opt} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                          {opt}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="sm:col-span-2">
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Nutrition & Diet (Healthy Eating Status)
                    </label>
                    <select
                      value={editFormData.nutritionDiet}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, nutritionDiet: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 cursor-pointer"
                    >
                      {NUTRITION_DIET_OPTIONS.map((opt) => (
                        <option key={opt} value={opt} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                          {opt}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Alcohol Level / Intake
                    </label>
                    <select
                      value={editFormData.alcoholLevel}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, alcoholLevel: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 cursor-pointer"
                    >
                      {ALCOHOL_OPTIONS.map((opt) => (
                        <option key={opt} value={opt} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                          {opt}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Smoking Status
                    </label>
                    <select
                      value={editFormData.smokingStatus}
                      onChange={(e) => setEditFormData((prev) => ({ ...prev, smokingStatus: e.target.value }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 cursor-pointer"
                    >
                      {SMOKING_OPTIONS.map((opt) => (
                        <option key={opt} value={opt} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                          {opt}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>

              {/* Emergency Contact */}
              <div className="space-y-3">
                <h4 className="text-xs font-bold uppercase tracking-wider text-terracotta">
                  Emergency Contact
                </h4>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Contact Name
                    </label>
                    <input
                      type="text"
                      value={editFormData.emergencyContact.name}
                      onChange={(e) => setEditFormData((prev) => ({
                        ...prev,
                        emergencyContact: { ...prev.emergencyContact, name: e.target.value }
                      }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Relationship
                    </label>
                    <input
                      type="text"
                      value={editFormData.emergencyContact.relationship}
                      onChange={(e) => setEditFormData((prev) => ({
                        ...prev,
                        emergencyContact: { ...prev.emergencyContact, relationship: e.target.value }
                      }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1">
                      Phone Number
                    </label>
                    <input
                      type="tel"
                      value={editFormData.emergencyContact.phone}
                      onChange={(e) => setEditFormData((prev) => ({
                        ...prev,
                        emergencyContact: { ...prev.emergencyContact, phone: e.target.value }
                      }))}
                      className="w-full px-3 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
                    />
                  </div>
                </div>
              </div>
            </form>

            {/* Modal Footer */}
            <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-border/60 dark:border-ink-soft/30 bg-cream/40 dark:bg-ink-soft/20">
              <button
                type="button"
                onClick={() => setShowEditModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-ink-soft dark:text-cream/70 hover:bg-cream dark:hover:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                form="edit-patient-form"
                disabled={isSavingEdit}
                className="inline-flex items-center gap-1.5 px-5 py-2 rounded-xl text-xs font-semibold text-cream bg-terracotta hover:bg-terracotta-dark active:scale-95 transition-all shadow-xs disabled:opacity-60 disabled:cursor-not-allowed"
              >
                {isSavingEdit ? (
                  <>
                    <div className="w-3.5 h-3.5 border-2 border-cream border-t-transparent rounded-full animate-spin" />
                    <span>Saving...</span>
                  </>
                ) : (
                  <>
                    <Save className="w-3.5 h-3.5" />
                    <span>Save Changes</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PatientDetails;
