import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  UserPlus,
  User,
  HeartPulse,
  Phone,
  Tablet,
  CheckCircle2,
  AlertCircle,
  Calendar,
  Languages,
  FileText,
  ShieldCheck,
  Sparkles,
  QrCode,
  Copy,
  Check,
  ExternalLink,
} from 'lucide-react';
import { registerPatient } from '../services/patientService';
import { addFamilyMember } from '../services/carePlanService';

const DIAGNOSIS_OPTIONS = [
  'Mild Cognitive Impairment (MCI)',
  "Early Stage Alzheimer's",
  'Vascular Dementia',
  'Frontotemporal Dementia',
  'Subjective Cognitive Decline (SCD)',
  'Age-Associated Memory Impairment',
  'Other / Under Observation',
];

const LANGUAGE_OPTIONS = [
  { value: 'Assamese', label: 'Assamese (অসমীয়া)' },
  { value: 'Bengali', label: 'Bengali (বাংলা)' },
  { value: 'Manipuri', label: 'Manipuri (মৈতৈলোন্)' },
  { value: 'English', label: 'English' },
  { value: 'Hindi', label: 'Hindi (हिन्दी)' },
];

const GENDER_OPTIONS = ['Male', 'Female', 'Other', 'Prefer not to say'];

export const RegisterPatient = () => {
  const navigate = useNavigate();

  // Form State matching schema of other patients
  const [formData, setFormData] = useState({
    name: '',
    dateOfBirth: '',
    age: '',
    gender: 'Male',
    preferredLanguage: 'Assamese',
    diagnosis: 'Mild Cognitive Impairment (MCI)',
    healthIssue: '',
    notes: '',
    emergencyContact: {
      name: '',
      relationship: '',
      phone: '',
    },
    deviceStatus: {
      linked: true,
      deviceName: 'Lenovo Tab M10 Plus',
      deviceId: `DEV-M10-${Math.floor(1000 + Math.random() * 9000)}`,
    },
  });

  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [registeredPatient, setRegisteredPatient] = useState(null);
  const [copiedToken, setCopiedToken] = useState(false);

  // Auto-calculate age from DOB if DOB changes
  const handleDobChange = (e) => {
    const dob = e.target.value;
    let computedAge = formData.age;
    if (dob) {
      const birthDate = new Date(dob);
      const today = new Date();
      let age = today.getFullYear() - birthDate.getFullYear();
      const monthDiff = today.getMonth() - birthDate.getMonth();
      if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
        age--;
      }
      if (age >= 0 && age <= 125) {
        computedAge = String(age);
      }
    }
    setFormData((prev) => ({
      ...prev,
      dateOfBirth: dob,
      age: computedAge,
    }));
    if (errors.dateOfBirth) {
      setErrors((prev) => ({ ...prev, dateOfBirth: '' }));
    }
  };

  const handleChange = (field, value) => {
    setFormData((prev) => ({
      ...prev,
      [field]: value,
    }));
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: '' }));
    }
  };

  const handleEmergencyChange = (field, value) => {
    setFormData((prev) => ({
      ...prev,
      emergencyContact: {
        ...prev.emergencyContact,
        [field]: value,
      },
    }));
    if (errors[`emergency_${field}`]) {
      setErrors((prev) => ({ ...prev, [`emergency_${field}`]: '' }));
    }
  };

  const handleDeviceChange = (field, value) => {
    setFormData((prev) => ({
      ...prev,
      deviceStatus: {
        ...prev.deviceStatus,
        [field]: value,
      },
    }));
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Patient full name is required';
    } else if (formData.name.trim().length < 2) {
      newErrors.name = 'Name must be at least 2 characters';
    }

    if (!formData.age || isNaN(formData.age) || Number(formData.age) < 1 || Number(formData.age) > 120) {
      newErrors.age = 'Please enter a valid age (e.g. 70)';
    }

    if (!formData.healthIssue.trim()) {
      newErrors.healthIssue = 'Please provide primary health and cognitive condition notes';
    }

    if (!formData.emergencyContact.name.trim()) {
      newErrors.emergency_name = 'Emergency contact name is required';
    }

    if (!formData.emergencyContact.relationship.trim()) {
      newErrors.emergency_relationship = 'Relationship is required';
    }

    if (!formData.emergencyContact.phone.trim()) {
      newErrors.emergency_phone = 'Contact phone number is required';
    } else if (!/^[+0-9\s-]{7,16}$/.test(formData.emergencyContact.phone.trim())) {
      newErrors.emergency_phone = 'Please enter a valid phone number';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!validateForm()) {
      // Scroll to top of form to show validation errors
      window.scrollTo({ top: 100, behavior: 'smooth' });
      return;
    }

    setIsSubmitting(true);

    // Format DOB display string (matching "March 14, 1954" format in MOCK_PATIENTS)
    let formattedDob = formData.dateOfBirth;
    if (formData.dateOfBirth) {
      try {
        const dateObj = new Date(formData.dateOfBirth);
        formattedDob = dateObj.toLocaleDateString('en-US', {
          month: 'long',
          day: 'numeric',
          year: 'numeric',
        });
      } catch (err) {
        formattedDob = formData.dateOfBirth;
      }
    }

    // Generate unique ID following schema (e.g. p103)
    const newPatientId = `p${Math.floor(103 + Math.random() * 890)}`;
    const pairingToken = `PAIR-${Math.floor(100000 + Math.random() * 900000)}`;

    const newPatientRecord = {
      id: newPatientId,
      name: formData.name.trim(),
      age: parseInt(formData.age, 10),
      gender: formData.gender,
      dateOfBirth: formattedDob || 'Not specified',
      diagnosis: formData.diagnosis,
      healthIssue: formData.healthIssue.trim(),
      avatarUrl: null,
      lastCheckIn: 'Just registered',
      notes: formData.notes.trim() || 'Initial registration record. Baseline routine scheduled.',
      preferredLanguage: formData.preferredLanguage,
      pairingToken,
      careStatus: 'normal',
      statusLabel: formData.deviceStatus.linked ? 'Tablet configured • Ready to pair' : 'Registration completed',
      emergencyContact: {
        name: formData.emergencyContact.name.trim(),
        relationship: formData.emergencyContact.relationship.trim(),
        phone: formData.emergencyContact.phone.trim(),
      },
      deviceStatus: {
        linked: formData.deviceStatus.linked,
        deviceName: formData.deviceStatus.linked
          ? `${formData.deviceStatus.deviceName} (${formData.name.split(' ')[0]}'s Unit)`
          : 'Not linked',
        deviceId: formData.deviceStatus.linked ? formData.deviceStatus.deviceId : 'UNLINKED',
        lastSynced: 'Pending first sync',
      },
      createdAt: new Date().toISOString(),
    };

    // Save to patientService and localStorage for roster synchronization
    try {
      await registerPatient(newPatientRecord);
    } catch (err) {
      console.warn('Could not register patient to service:', err);
    }

    // Seed initial family memory card for the new patient's Care Plan
    if (formData.emergencyContact.name.trim()) {
      try {
        await addFamilyMember({
          patientId: newPatientId,
          name: formData.emergencyContact.name.trim(),
          relation: formData.emergencyContact.relationship.trim() || 'Family Guardian',
          photoUrl: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300" viewBox="0 0 400 300"><rect width="400" height="300" fill="%23FBF5EA"/><circle cx="200" cy="120" r="55" fill="%23B5562F"/><path d="M100 250 C100 185, 300 185, 300 250 Z" fill="%23B5562F"/><text x="200" y="280" font-family="sans-serif" font-size="18" font-weight="bold" fill="%232E2A24" text-anchor="middle">Family</text></svg>',
        });
      } catch (err) {
        console.warn('Could not seed initial memory card:', err);
      }
    }

    setIsSubmitting(false);
    setRegisteredPatient(newPatientRecord);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleCopyPairingToken = () => {
    if (!registeredPatient?.pairingToken) return;
    navigator.clipboard.writeText(registeredPatient.pairingToken);
    setCopiedToken(true);
    setTimeout(() => setCopiedToken(false), 2000);
  };

  return (
    <div className="space-y-6 font-sans max-w-4xl mx-auto pb-12">
      {/* 1. Return to All Patients Dashboard Navigation */}
      <div className="flex items-center justify-between">
        <Link
          to="/dashboard"
          aria-label="Back to all patients dashboard"
          className="inline-flex items-center justify-center gap-1.5 px-3.5 py-2 bg-surface/90 dark:bg-ink/90 backdrop-blur-md border border-border/80 dark:border-ink-soft/40 rounded-full shadow-md text-xs sm:text-sm font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all select-none outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
        >
          <ArrowLeft className="w-4 h-4 text-terracotta shrink-0" />
          <span>All Patients</span>
        </Link>
        <span className="text-xs font-semibold text-ink-soft dark:text-cream/60 uppercase tracking-wider">
          New Enrollment
        </span>
      </div>

      {/* SUCCESS CONFIRMATION STATE */}
      {registeredPatient ? (
        <div className="bg-surface dark:bg-ink-soft/20 border border-sage/40 dark:border-sage/40 rounded-card p-6 sm:p-8 shadow-card space-y-6">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-sage/15 border border-sage/30 flex items-center justify-center text-sage shrink-0 shadow-xs">
              <CheckCircle2 className="w-6 h-6" />
            </div>
            <div>
              <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold tracking-wide uppercase bg-sage/15 text-sage border border-sage/30">
                Enrollment Complete
              </span>
              <h1 className="text-2xl sm:text-3xl font-bold text-ink dark:text-cream tracking-tight mt-1">
                {registeredPatient.name} Registered Successfully
              </h1>
            </div>
          </div>

          <p className="text-sm text-ink-soft dark:text-cream/70 leading-relaxed">
            The patient profile has been created and indexed with standard cognitive baseline routines.
            {registeredPatient.deviceStatus.linked
              ? ' A tablet pairing code has been generated to link their dedicated Assist device.'
              : ''}
          </p>

          {/* Patient Summary Card */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-4 bg-cream/50 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs">
            <div>
              <span className="text-ink-soft dark:text-cream/60 font-medium">Patient ID:</span>
              <p className="font-bold text-ink dark:text-cream text-sm mt-0.5">{registeredPatient.id}</p>
            </div>
            <div>
              <span className="text-ink-soft dark:text-cream/60 font-medium">Age & Gender:</span>
              <p className="font-semibold text-ink dark:text-cream mt-0.5">
                {registeredPatient.age} yrs • {registeredPatient.gender}
              </p>
            </div>
            <div>
              <span className="text-ink-soft dark:text-cream/60 font-medium">Primary Diagnosis:</span>
              <p className="font-semibold text-terracotta mt-0.5">{registeredPatient.diagnosis}</p>
            </div>
          </div>

          {/* Tablet Pairing Code Card */}
          {registeredPatient.deviceStatus.linked && (
            <div className="p-5 bg-surface dark:bg-ink-soft/40 border border-gold/40 rounded-xl shadow-xs space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-gold font-bold text-sm">
                  <QrCode className="w-4 h-4" />
                  <span>Tablet Pairing Code (Patient Device)</span>
                </div>
                <span className="text-[11px] font-semibold text-ink-soft dark:text-cream/60">
                  Unit: {registeredPatient.deviceStatus.deviceId}
                </span>
              </div>
              <p className="text-xs text-ink-soft dark:text-cream/70">
                Turn on the patient tablet, open <strong>Smriti Setu Assist</strong>, and enter this one-time code to lock the device into simplified Patient Mode:
              </p>
              <div className="flex items-center gap-3">
                <div className="px-4 py-2 bg-cream dark:bg-ink border border-border dark:border-ink-soft/60 rounded-lg font-mono font-bold text-lg text-ink dark:text-cream tracking-widest">
                  {registeredPatient.pairingToken}
                </div>
                <button
                  type="button"
                  onClick={handleCopyPairingToken}
                  className="inline-flex items-center gap-1.5 px-3 py-2 bg-surface dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 text-ink dark:text-cream text-xs font-medium rounded-lg border border-border/80 dark:border-ink-soft/40 transition-colors"
                >
                  {copiedToken ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-sage" />
                      <span className="text-sage font-bold">Copied</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5" />
                      <span>Copy Code</span>
                    </>
                  )}
                </button>
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex flex-wrap items-center gap-3 pt-2">
            <Link
              to={`/patients/${registeredPatient.id}/details`}
              className="px-5 py-2.5 bg-terracotta hover:bg-terracotta-dark text-cream font-medium rounded-xl text-xs sm:text-sm shadow-xs transition-colors flex items-center justify-center gap-2"
            >
              <User className="w-4 h-4" />
              <span>View Patient Profile</span>
            </Link>
            <Link
              to="/dashboard"
              className="px-5 py-2.5 bg-surface dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 text-ink dark:text-cream font-medium rounded-xl text-xs sm:text-sm border border-border/80 dark:border-ink-soft/40 transition-colors flex items-center justify-center gap-2"
            >
              <span>Go to Dashboard</span>
            </Link>
            <button
              type="button"
              onClick={() => {
                setRegisteredPatient(null);
                setFormData({
                  name: '',
                  dateOfBirth: '',
                  age: '',
                  gender: 'Male',
                  preferredLanguage: 'Assamese',
                  diagnosis: 'Mild Cognitive Impairment (MCI)',
                  healthIssue: '',
                  notes: '',
                  emergencyContact: {
                    name: '',
                    relationship: '',
                    phone: '',
                  },
                  deviceStatus: {
                    linked: true,
                    deviceName: 'Lenovo Tab M10 Plus',
                    deviceId: `DEV-M10-${Math.floor(1000 + Math.random() * 9000)}`,
                  },
                });
              }}
              className="px-4 py-2.5 bg-surface dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 text-ink-soft dark:text-cream/80 border border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm font-medium transition-colors"
            >
              Enroll Another Patient
            </button>
          </div>
        </div>
      ) : (
        /* REGISTRATION FORM */
        <form onSubmit={handleSubmit} noValidate className="space-y-6">
          {/* Header Banner */}
          <div className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-8 shadow-card">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shrink-0 shadow-xs">
                <UserPlus className="w-6 h-6" />
              </div>
              <div className="space-y-1">
                <h1 className="text-2xl sm:text-3xl font-bold text-ink dark:text-cream tracking-tight">
                  Register New Patient
                </h1>
                <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 leading-relaxed max-w-2xl">
                  Enroll an elderly participant under your clinical care. Configure their cognitive diagnosis profile, language preferences, emergency contacts, and paired tablet device.
                </p>
              </div>
            </div>
          </div>

          {/* Form Section 1: Demographics & Identity */}
          <section className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-7 shadow-card space-y-5">
            <div className="flex items-center gap-2.5 pb-2 border-b border-border/60 dark:border-ink-soft/30">
              <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shrink-0 shadow-xs">
                <User className="w-4 h-4" />
              </div>
              <div>
                <h2 className="text-base font-bold text-ink dark:text-cream">Personal & Demographic Info</h2>
                <p className="text-[11px] text-ink-soft dark:text-cream/60">
                  Basic patient identification and regional communication dialect.
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Full Name */}
              <div className="sm:col-span-2">
                <label htmlFor="patient-name" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Full Name <span className="text-terracotta">*</span>
                </label>
                <input
                  id="patient-name"
                  type="text"
                  value={formData.name}
                  onChange={(e) => handleChange('name', e.target.value)}
                  placeholder="e.g. Aarav Sharma"
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.name ? 'border-alert focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.name)}
                />
                {errors.name && (
                  <p className="text-xs text-alert flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5" />
                    <span>{errors.name}</span>
                  </p>
                )}
              </div>

              {/* Date of Birth */}
              <div>
                <label htmlFor="patient-dob" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Date of Birth
                </label>
                <div className="relative">
                  <input
                    id="patient-dob"
                    type="date"
                    value={formData.dateOfBirth}
                    onChange={handleDobChange}
                    className="w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 focus:border-terracotta transition-colors shadow-xs"
                  />
                </div>
                <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                  Optional. Auto-calculates age.
                </span>
              </div>

              {/* Age */}
              <div>
                <label htmlFor="patient-age" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Age (Years) <span className="text-terracotta">*</span>
                </label>
                <input
                  id="patient-age"
                  type="number"
                  min="40"
                  max="120"
                  value={formData.age}
                  onChange={(e) => handleChange('age', e.target.value)}
                  placeholder="e.g. 72"
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.age ? 'border-alert focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.age)}
                />
                {errors.age && (
                  <p className="text-xs text-alert flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5" />
                    <span>{errors.age}</span>
                  </p>
                )}
              </div>

              {/* Gender */}
              <div>
                <label htmlFor="patient-gender" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Gender
                </label>
                <select
                  id="patient-gender"
                  value={formData.gender}
                  onChange={(e) => handleChange('gender', e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 focus:border-terracotta transition-colors shadow-xs cursor-pointer"
                >
                  {GENDER_OPTIONS.map((g) => (
                    <option key={g} value={g} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                      {g}
                    </option>
                  ))}
                </select>
              </div>

              {/* Preferred Language / Regional Dialect */}
              <div>
                <label htmlFor="patient-language" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Preferred Language (Voice Prompts)
                </label>
                <select
                  id="patient-language"
                  value={formData.preferredLanguage}
                  onChange={(e) => handleChange('preferredLanguage', e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 focus:border-terracotta transition-colors shadow-xs cursor-pointer"
                >
                  {LANGUAGE_OPTIONS.map((lang) => (
                    <option key={lang.value} value={lang.value} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                      {lang.label}
                    </option>
                  ))}
                </select>
                <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                  Used for speech-to-text & conversational check-ins.
                </span>
              </div>
            </div>
          </section>

          {/* Form Section 2: Clinical Profile & Health Issues */}
          <section className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-7 shadow-card space-y-5">
            <div className="flex items-center gap-2.5 pb-2 border-b border-border/60 dark:border-ink-soft/30">
              <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shrink-0 shadow-xs">
                <HeartPulse className="w-4 h-4" />
              </div>
              <div>
                <h2 className="text-base font-bold text-ink dark:text-cream">Clinical Profile & Health Condition</h2>
                <p className="text-[11px] text-ink-soft dark:text-cream/60">
                  Defines game difficulty starting points and drift detection baselines.
                </p>
              </div>
            </div>

            <div className="space-y-4">
              {/* Primary Diagnosis */}
              <div>
                <label htmlFor="patient-diagnosis" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Primary Cognitive Diagnosis <span className="text-terracotta">*</span>
                </label>
                <select
                  id="patient-diagnosis"
                  value={formData.diagnosis}
                  onChange={(e) => handleChange('diagnosis', e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 focus:border-terracotta transition-colors shadow-xs cursor-pointer"
                >
                  {DIAGNOSIS_OPTIONS.map((opt) => (
                    <option key={opt} value={opt} className="bg-surface dark:bg-ink text-ink dark:text-cream">
                      {opt}
                    </option>
                  ))}
                </select>
              </div>

              {/* Health Issue / Condition Summary */}
              <div>
                <label htmlFor="patient-health-issue" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Health Condition & Symptoms Summary <span className="text-terracotta">*</span>
                </label>
                <input
                  id="patient-health-issue"
                  type="text"
                  value={formData.healthIssue}
                  onChange={(e) => handleChange('healthIssue', e.target.value)}
                  placeholder="e.g. Mild Cognitive Impairment (MCI) • Early-stage memory recall decline • Hypertension"
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.healthIssue ? 'border-alert focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.healthIssue)}
                />
                {errors.healthIssue ? (
                  <p className="text-xs text-alert flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5" />
                    <span>{errors.healthIssue}</span>
                  </p>
                ) : (
                  <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                    Displayed prominently on patient overview cards and caregiver dashboard.
                  </span>
                )}
              </div>

              {/* Caregiver Baseline Notes */}
              <div>
                <label htmlFor="patient-notes" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Caregiver Routine & Observational Notes
                </label>
                <textarea
                  id="patient-notes"
                  rows={2}
                  value={formData.notes}
                  onChange={(e) => handleChange('notes', e.target.value)}
                  placeholder="e.g. Morning memory recall exercise completed with 92% accuracy. Best response times before noon."
                  className="w-full px-3.5 py-2 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 focus:border-terracotta transition-colors shadow-xs resize-y"
                />
              </div>
            </div>
          </section>

          {/* Form Section 3: Emergency Contact */}
          <section className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-7 shadow-card space-y-5">
            <div className="flex items-center gap-2.5 pb-2 border-b border-border/60 dark:border-ink-soft/30">
              <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shrink-0 shadow-xs">
                <Phone className="w-4 h-4" />
              </div>
              <div>
                <h2 className="text-base font-bold text-ink dark:text-cream">Primary Guardian & Emergency Contact</h2>
                <p className="text-[11px] text-ink-soft dark:text-cream/60">
                  Direct phone contact for urgent health or cognitive decline alerts.
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              {/* Contact Name */}
              <div>
                <label htmlFor="emergency-name" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Contact Name <span className="text-terracotta">*</span>
                </label>
                <input
                  id="emergency-name"
                  type="text"
                  value={formData.emergencyContact.name}
                  onChange={(e) => handleEmergencyChange('name', e.target.value)}
                  placeholder="e.g. Priya Sharma"
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.emergency_name ? 'border-alert focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.emergency_name)}
                />
                {errors.emergency_name && (
                  <p className="text-xs text-alert flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5" />
                    <span>{errors.emergency_name}</span>
                  </p>
                )}
              </div>

              {/* Relationship */}
              <div>
                <label htmlFor="emergency-rel" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Relationship <span className="text-terracotta">*</span>
                </label>
                <input
                  id="emergency-rel"
                  type="text"
                  value={formData.emergencyContact.relationship}
                  onChange={(e) => handleEmergencyChange('relationship', e.target.value)}
                  placeholder="e.g. Daughter (Primary Guardian)"
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.emergency_relationship ? 'border-alert focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.emergency_relationship)}
                />
                {errors.emergency_relationship && (
                  <p className="text-xs text-alert flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5" />
                    <span>{errors.emergency_relationship}</span>
                  </p>
                )}
              </div>

              {/* Phone Number */}
              <div>
                <label htmlFor="emergency-phone" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Phone Number <span className="text-terracotta">*</span>
                </label>
                <input
                  id="emergency-phone"
                  type="tel"
                  value={formData.emergencyContact.phone}
                  onChange={(e) => handleEmergencyChange('phone', e.target.value)}
                  placeholder="+91 98765 43210"
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.emergency_phone ? 'border-alert focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.emergency_phone)}
                />
                {errors.emergency_phone && (
                  <p className="text-xs text-alert flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5" />
                    <span>{errors.emergency_phone}</span>
                  </p>
                )}
              </div>
            </div>
          </section>

          {/* Form Section 4: Device Linking & Pairing Setup */}
          <section className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-7 shadow-card space-y-5">
            <div className="flex items-center justify-between pb-2 border-b border-border/60 dark:border-ink-soft/30">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shrink-0 shadow-xs">
                  <Tablet className="w-4 h-4" />
                </div>
                <div>
                  <h2 className="text-base font-bold text-ink dark:text-cream">Patient Tablet & Device Linking</h2>
                  <p className="text-[11px] text-ink-soft dark:text-cream/60">
                    Pre-configures the tablet device token and pairing setup.
                  </p>
                </div>
              </div>

              {/* Toggle linked switch */}
              <label className="flex items-center gap-2 cursor-pointer select-none text-xs font-semibold text-ink-soft dark:text-cream/80">
                <span>Pair Tablet Now</span>
                <input
                  type="checkbox"
                  checked={formData.deviceStatus.linked}
                  onChange={(e) => handleDeviceChange('linked', e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-9 h-5 bg-border dark:bg-ink-soft/50 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-sage relative" />
              </label>
            </div>

            {formData.deviceStatus.linked ? (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label htmlFor="device-model" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                    Tablet Model / Name
                  </label>
                  <input
                    id="device-model"
                    type="text"
                    value={formData.deviceStatus.deviceName}
                    onChange={(e) => handleDeviceChange('deviceName', e.target.value)}
                    placeholder="e.g. Lenovo Tab M10 Plus"
                    className="w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 focus:border-terracotta transition-colors shadow-xs"
                  />
                </div>

                <div>
                  <label htmlFor="device-id" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                    Device Identifier (Assigned)
                  </label>
                  <input
                    id="device-id"
                    type="text"
                    readOnly
                    value={formData.deviceStatus.deviceId}
                    className="w-full px-3.5 py-2.5 bg-cream/60 dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm font-mono text-ink dark:text-cream shadow-xs cursor-not-allowed"
                  />
                  <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                    Auto-generated for hardware identification.
                  </span>
                </div>
              </div>
            ) : (
              <p className="text-xs text-ink-soft dark:text-cream/60 italic">
                Device linking skipped. You can pair a tablet anytime later from the patient's profile.
              </p>
            )}
          </section>

          {/* Form Actions Footer */}
          <div className="flex flex-col-reverse sm:flex-row sm:items-center justify-end gap-3 pt-2">
            <Link
              to="/dashboard"
              className="px-5 py-2.5 bg-surface dark:bg-ink-soft/30 hover:bg-cream dark:hover:bg-ink-soft/50 text-ink-soft dark:text-cream/80 border border-border/80 dark:border-ink-soft/40 rounded-xl font-medium text-xs sm:text-sm transition-colors text-center"
            >
              Cancel
            </Link>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-6 py-2.5 bg-terracotta hover:bg-terracotta-dark text-cream font-medium rounded-xl text-xs sm:text-sm shadow-xs transition-colors flex items-center justify-center gap-2 focus:outline-none focus:ring-2 focus:ring-terracotta/40 disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {isSubmitting ? (
                <>
                  <div className="w-4 h-4 border-2 border-cream border-t-transparent rounded-full animate-spin" />
                  <span>Enrolling Patient...</span>
                </>
              ) : (
                <>
                  <UserPlus className="w-4 h-4" />
                  <span>Register Patient</span>
                </>
              )}
            </button>
          </div>
        </form>
      )}
    </div>
  );
};

export default RegisterPatient;
