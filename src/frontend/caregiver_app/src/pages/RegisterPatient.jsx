import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  UserPlus,
  User,
  HeartPulse,
  Phone,
  CheckCircle2,
  AlertCircle,
  Calendar,
  Languages,
  FileText,
  ShieldCheck,
  Sparkles,
  ExternalLink,
  Scale,
  Activity,
  Apple,
  Wine,
  Cigarette,
  Utensils,
  Camera,
  Upload,
} from 'lucide-react';
import { registerPatient } from '../services/patientService';
import { addFamilyMember } from '../services/carePlanService';
import { StyledSelect } from '../components/StyledSelect';

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

const LANGUAGE_OPTIONS = [
  { value: 'English', label: 'English' },
  { value: 'Assamese', label: 'Assamese (অসমীয়া)' },
  { value: 'Bengali', label: 'Bengali (বাংলা)' },
  { value: 'Bodo', label: 'Bodo (बड़ो)' },
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
    preferredLanguage: 'English',
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

  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [registeredPatient, setRegisteredPatient] = useState(null);

  // Auto-calculate age from DOB if DOB changes
  const handleDobChange = (eOrVal) => {
    const dob = typeof eOrVal === 'string' ? eOrVal : eOrVal?.target?.value || '';
    let computedAge = formData.age;
    if (dob) {
      const parts = dob.split('-');
      if (parts.length === 3) {
        const birthYear = parseInt(parts[0], 10);
        const birthMonth = parseInt(parts[1], 10) - 1;
        const birthDay = parseInt(parts[2], 10);

        if (!isNaN(birthYear) && !isNaN(birthMonth) && !isNaN(birthDay)) {
          const today = new Date();
          let age = today.getFullYear() - birthYear;
          const monthDiff = today.getMonth() - birthMonth;
          if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDay)) {
            age--;
          }
          if (age >= 0 && age <= 125) {
            computedAge = String(age);
          }
        }
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
    if (computedAge && errors.age) {
      setErrors((prev) => ({ ...prev, age: '' }));
    }
  };

  // Auto-calculate estimated DOB from Age if Age changes (vice versa)
  const handleAgeChange = (eOrVal) => {
    const val = typeof eOrVal === 'string' ? eOrVal : eOrVal?.target?.value || '';
    let computedDob = formData.dateOfBirth;

    if (val !== '') {
      const ageNum = parseInt(val, 10);
      if (!isNaN(ageNum) && ageNum >= 0 && ageNum <= 125) {
        const today = new Date();
        let month = today.getMonth();
        let day = today.getDate();

        // If a valid dateOfBirth already exists, preserve the chosen month and day
        if (formData.dateOfBirth) {
          const parts = formData.dateOfBirth.split('-');
          if (parts.length === 3) {
            const existingMonth = parseInt(parts[1], 10) - 1;
            const existingDay = parseInt(parts[2], 10);
            if (!isNaN(existingMonth) && !isNaN(existingDay)) {
              month = existingMonth;
              day = existingDay;
            }
          }
        }

        // Determine birth year so that on `today`, age equals `ageNum`
        let birthYear = today.getFullYear() - ageNum;
        const hasHadBirthdayThisYear =
          today.getMonth() > month ||
          (today.getMonth() === month && today.getDate() >= day);

        if (!hasHadBirthdayThisYear) {
          birthYear--;
        }

        const mm = String(month + 1).padStart(2, '0');
        const dd = String(day).padStart(2, '0');
        computedDob = `${birthYear}-${mm}-${dd}`;
      }
    }

    setFormData((prev) => ({
      ...prev,
      age: val,
      dateOfBirth: computedDob,
    }));

    if (errors.age) {
      setErrors((prev) => ({ ...prev, age: '' }));
    }
    if (computedDob && errors.dateOfBirth) {
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

    if (!formData.dateOfBirth) {
      newErrors.dateOfBirth = 'Date of birth is required';
    }

    if (formData.emergencyContact.phone.trim() && !/^[+0-9\s-]{7,16}$/.test(formData.emergencyContact.phone.trim())) {
      newErrors.emergency_phone = 'Please enter a valid phone number (e.g. +91 98765 43210)';
    }

    setErrors(newErrors);

    if (Object.keys(newErrors).length > 0) {
      const firstField = Object.keys(newErrors)[0];
      const targetId =
        firstField === 'name' ? 'patient-name' :
        firstField === 'dateOfBirth' ? 'patient-dob' :
        firstField === 'age' ? 'patient-age' :
        firstField === 'emergency_phone' ? 'emergency-phone' : null;
      if (targetId) {
        const el = document.getElementById(targetId);
        if (el) {
          el.scrollIntoView({ behavior: 'smooth', block: 'center' });
          el.focus();
        }
      }
      return false;
    }

    return true;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setIsSubmitting(true);

    // Format DOB display string (matching "March 14, 1954" format in MOCK_PATIENTS)
    let formattedDob = formData.dateOfBirth;
    if (formData.dateOfBirth) {
      try {
        const parts = formData.dateOfBirth.split('-');
        if (parts.length === 3) {
          const dateObj = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
          formattedDob = dateObj.toLocaleDateString('en-US', {
            month: 'long',
            day: 'numeric',
            year: 'numeric',
          });
        }
      } catch (err) {
        formattedDob = formData.dateOfBirth;
      }
    }

    // Generate unique ID following schema (e.g. p103)
    const newPatientId = `p${Math.floor(103 + Math.random() * 890)}`;
    const pairingToken = `PAIR-${Math.floor(100000 + Math.random() * 900000)}`;

    const effectiveHealthIssue =
      formData.healthIssue.trim() ||
      `${formData.diagnosis} • Initial registration record • Routine baseline active`;

    const effectiveEmergencyName = formData.emergencyContact.name.trim() || 'Family Guardian';
    const effectiveEmergencyRel = formData.emergencyContact.relationship.trim() || 'Primary Guardian';
    const effectiveEmergencyPhone = formData.emergencyContact.phone.trim() || '+91 98765 43210';

    const effectiveWeight = formData.weight.trim()
      ? formData.weight.trim().toLowerCase().endsWith('kg')
        ? formData.weight.trim()
        : `${formData.weight.trim()} kg`
      : 'Not recorded';

    const newPatientRecord = {
      id: newPatientId,
      name: formData.name.trim(),
      age: parseInt(formData.age, 10),
      gender: formData.gender,
      dateOfBirth: formattedDob || 'Not specified',
      diagnosis: formData.diagnosis,
      healthIssue: effectiveHealthIssue,
      avatarUrl: formData.avatarUrl || null,
      lastCheckIn: 'Just registered',
      notes: formData.notes.trim() || 'Initial registration record. Baseline routine scheduled.',
      preferredLanguage: formData.preferredLanguage,
      weight: effectiveWeight,
      diabetic: formData.diabetic,
      nutritionDiet: formData.nutritionDiet,
      alcoholLevel: formData.alcoholLevel,
      smokingStatus: formData.smokingStatus,
      pairingToken,
      careStatus: 'normal',
      statusLabel: 'Registration completed',
      emergencyContact: {
        name: effectiveEmergencyName,
        relationship: effectiveEmergencyRel,
        phone: effectiveEmergencyPhone,
      },
      deviceStatus: {
        linked: false,
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
    try {
      await addFamilyMember({
        patientId: newPatientId,
        name: effectiveEmergencyName,
        relation: effectiveEmergencyRel,
        photoUrl: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300" viewBox="0 0 400 300"><rect width="400" height="300" fill="%23FBF5EA"/><circle cx="200" cy="120" r="55" fill="%23B5562F"/><path d="M100 250 C100 185, 300 185, 300 250 Z" fill="%23B5562F"/><text x="200" y="280" font-family="sans-serif" font-size="18" font-weight="bold" fill="%232E2A24" text-anchor="middle">Family</text></svg>',
      });
    } catch (err) {
      console.warn('Could not seed initial memory card:', err);
    }

    setIsSubmitting(false);
    setRegisteredPatient(newPatientRecord);
    window.scrollTo({ top: 0, behavior: 'smooth' });
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

          {/* Lifestyle & Physical Vitals Summary Card */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 p-3.5 bg-cream/40 dark:bg-ink-soft/20 border border-border/70 dark:border-ink-soft/30 rounded-xl text-xs">
            <div>
              <span className="text-ink-soft dark:text-cream/60 font-medium">Weight:</span>
              <p className="font-semibold text-ink dark:text-cream mt-0.5">{registeredPatient.weight || 'Not recorded'}</p>
            </div>
            <div>
              <span className="text-ink-soft dark:text-cream/60 font-medium">Diabetic:</span>
              <p className="font-semibold text-ink dark:text-cream mt-0.5">{registeredPatient.diabetic || 'Non-Diabetic'}</p>
            </div>
            <div>
              <span className="text-ink-soft dark:text-cream/60 font-medium">Alcohol Level:</span>
              <p className="font-semibold text-ink dark:text-cream mt-0.5">{registeredPatient.alcoholLevel || 'None'}</p>
            </div>
            <div>
              <span className="text-ink-soft dark:text-cream/60 font-medium">Smoking Status:</span>
              <p className="font-semibold text-ink dark:text-cream mt-0.5">{registeredPatient.smokingStatus || 'Non-Smoker'}</p>
            </div>
            <div className="col-span-2 sm:col-span-4 pt-1.5 border-t border-border/40 dark:border-ink-soft/20 flex items-center justify-between gap-2">
              <div>
                <span className="text-ink-soft dark:text-cream/60 font-medium">Nutrition & Diet:</span>
                <p className="font-semibold text-ink dark:text-cream mt-0.5">{registeredPatient.nutritionDiet || 'Healthy & Balanced'}</p>
              </div>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-sage/15 text-sage border border-sage/30">
                Healthy Tracking Active
              </span>
            </div>
          </div>

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
                  preferredLanguage: 'English',
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
                  Enroll an elderly participant under your clinical care. Configure their cognitive diagnosis profile, language preferences, emergency contacts, and paired patient device.
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
              {/* Patient Profile Photo Uploader */}
              <div className="sm:col-span-2 flex items-center gap-4 p-3.5 bg-cream/30 dark:bg-ink-soft/20 border border-border/70 dark:border-ink-soft/30 rounded-xl">
                <div className="relative shrink-0">
                  {formData.avatarUrl ? (
                    <img
                      src={formData.avatarUrl}
                      alt="Patient preview"
                      className="w-16 h-16 rounded-full object-cover border-2 border-border/80 dark:border-ink-soft/40 shadow-xs"
                    />
                  ) : (
                    <div className="w-16 h-16 rounded-full bg-cream dark:bg-ink-soft/40 border-2 border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta font-bold text-lg select-none">
                      <User className="w-7 h-7" />
                    </div>
                  )}
                </div>
                <div className="space-y-1 flex-1 min-w-0">
                  <span className="block text-xs font-semibold text-ink dark:text-cream">
                    Patient Profile Photo (Optional)
                  </span>
                  <p className="text-[11px] text-ink-soft dark:text-cream/60">
                    Helps identification across dashboard, care plan, and daily memory activities.
                  </p>
                  <div className="flex items-center gap-2 pt-1">
                    <label
                      htmlFor="register-photo-upload"
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-terracotta hover:bg-terracotta-dark text-cream text-xs font-medium cursor-pointer transition-colors shadow-2xs"
                    >
                      <Camera className="w-3.5 h-3.5" />
                      <span>{formData.avatarUrl ? 'Change Photo' : 'Upload Photo'}</span>
                      <input
                        id="register-photo-upload"
                        type="file"
                        accept="image/*"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (!file) return;
                          if (file.size > 5 * 1024 * 1024) {
                            alert('Photo exceeds 5MB limit.');
                            return;
                          }
                          const reader = new FileReader();
                          reader.onload = (event) => {
                            handleChange('avatarUrl', event.target.result);
                          };
                          reader.readAsDataURL(file);
                        }}
                        className="sr-only"
                      />
                    </label>
                    {formData.avatarUrl && (
                      <button
                        type="button"
                        onClick={() => handleChange('avatarUrl', null)}
                        className="px-2.5 py-1.5 rounded-lg bg-cream dark:bg-ink-soft/40 hover:bg-alert/10 hover:text-alert text-ink-soft dark:text-cream/70 text-xs font-medium transition-colors border border-border/60 dark:border-ink-soft/40"
                      >
                        Remove
                      </button>
                    )}
                  </div>
                </div>
              </div>

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
                    errors.name ? 'border-alert dark:border-gold/70 focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.name)}
                />
                {errors.name && (
                  <p className="text-xs text-alert dark:text-gold flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5 text-alert dark:text-gold" />
                    <span>{errors.name}</span>
                  </p>
                )}
              </div>

              {/* Date of Birth */}
              <div>
                <label htmlFor="patient-dob" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Date of Birth <span className="text-terracotta">*</span>
                </label>
                <input
                  id="patient-dob"
                  type="date"
                  value={formData.dateOfBirth}
                  onChange={(e) => handleDobChange(e.target.value)}
                  max={new Date().toISOString().split('T')[0]}
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.dateOfBirth ? 'border-alert dark:border-gold/70 focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.dateOfBirth)}
                />
                {errors.dateOfBirth && (
                  <p className="text-xs text-alert dark:text-gold flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5 text-alert dark:text-gold" />
                    <span>{errors.dateOfBirth}</span>
                  </p>
                )}
              </div>

              {/* Age (Auto-calculated, Read-only / Editable) */}
              <div>
                <label htmlFor="patient-age" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Age <span className="text-terracotta">*</span>
                </label>
                <input
                  id="patient-age"
                  type="number"
                  min="1"
                  max="125"
                  value={formData.age}
                  onChange={(e) => handleAgeChange(e.target.value)}
                  placeholder="e.g. 72"
                  className={`w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 transition-colors shadow-xs ${
                    errors.age ? 'border-alert dark:border-gold/70 focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.age)}
                />
                {errors.age && (
                  <p className="text-xs text-alert dark:text-gold flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5 text-alert dark:text-gold" />
                    <span>{errors.age}</span>
                  </p>
                )}
              </div>

              {/* Gender */}
              <div>
                <label htmlFor="patient-gender" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Gender
                </label>
                <StyledSelect
                  id="patient-gender"
                  value={formData.gender}
                  onChange={(val) => handleChange('gender', val)}
                  options={GENDER_OPTIONS}
                />
              </div>

              {/* Preferred Language / Regional Dialect */}
              <div>
                <label htmlFor="patient-language" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Preferred Language (Voice Prompts)
                </label>
                <StyledSelect
                  id="patient-language"
                  value={formData.preferredLanguage}
                  onChange={(val) => handleChange('preferredLanguage', val)}
                  options={LANGUAGE_OPTIONS}
                />
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
                <StyledSelect
                  id="patient-diagnosis"
                  value={formData.diagnosis}
                  onChange={(val) => handleChange('diagnosis', val)}
                  options={DIAGNOSIS_OPTIONS}
                />
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
                    errors.healthIssue ? 'border-alert dark:border-gold/70 focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.healthIssue)}
                />
                {errors.healthIssue ? (
                  <p className="text-xs text-alert dark:text-gold flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5 text-alert dark:text-gold" />
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

          {/* Form Section 3: Lifestyle & Physical Health Vitals */}
          <section className="bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-card p-6 sm:p-7 shadow-card space-y-5">
            <div className="flex items-center gap-2.5 pb-2 border-b border-border/60 dark:border-ink-soft/30">
              <div className="w-8 h-8 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shrink-0 shadow-xs">
                <Activity className="w-4 h-4" />
              </div>
              <div>
                <h2 className="text-base font-bold text-ink dark:text-cream">Lifestyle & Physical Health Vitals</h2>
                <p className="text-[11px] text-ink-soft dark:text-cream/60">
                  Key metabolic metrics, nutritional patterns, and lifestyle factors for comprehensive care monitoring.
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Body Weight */}
              <div>
                <label htmlFor="patient-weight" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Body Weight (kg)
                </label>
                <div className="relative">
                  <input
                    id="patient-weight"
                    type="number"
                    step="0.1"
                    min="20"
                    max="250"
                    value={formData.weight}
                    onChange={(e) => handleChange('weight', e.target.value)}
                    placeholder="e.g. 68"
                    className="w-full px-3.5 py-2.5 bg-cream/40 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl text-sm text-ink dark:text-cream placeholder:text-ink-soft/50 dark:placeholder:text-cream/30 focus:outline-none focus:ring-2 focus:ring-terracotta/40 focus:border-terracotta transition-colors shadow-xs pr-12"
                  />
                  <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-xs font-bold text-ink-soft dark:text-cream/50 pointer-events-none">
                    kg
                  </span>
                </div>
                <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                  Physical baseline for nutrition and mobility tracking.
                </span>
              </div>

              {/* Diabetic Status */}
              <div>
                <label htmlFor="patient-diabetic" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Diabetic Status
                </label>
                <StyledSelect
                  id="patient-diabetic"
                  value={formData.diabetic}
                  onChange={(val) => handleChange('diabetic', val)}
                  options={DIABETIC_OPTIONS}
                />
                <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                  Affects medication scheduling and vascular risk assessment.
                </span>
              </div>

              {/* Nutrition Diet (Healthy Eating Habit) - Full Width */}
              <div className="sm:col-span-2">
                <div className="flex items-center justify-between mb-1.5">
                  <label htmlFor="patient-nutrition-diet" className="block text-xs font-semibold text-ink-soft dark:text-cream/80">
                    Nutrition & Diet (Healthy Eating Assessment)
                  </label>
                  <span className={`inline-flex items-center gap-1 text-[10px] font-semibold px-2 py-0.5 rounded-full ${
                    formData.nutritionDiet.toLowerCase().includes('healthy') || formData.nutritionDiet.toLowerCase().includes('balanced')
                      ? 'bg-sage/15 text-sage border border-sage/30'
                      : formData.nutritionDiet.toLowerCase().includes('specialized')
                      ? 'bg-terracotta/15 text-terracotta border border-terracotta/30'
                      : 'bg-gold/15 text-gold border border-gold/30'
                  }`}>
                    {formData.nutritionDiet.toLowerCase().includes('healthy') || formData.nutritionDiet.toLowerCase().includes('balanced')
                      ? '✓ Healthy Adherence'
                      : formData.nutritionDiet.toLowerCase().includes('specialized')
                      ? '★ Specialized Clinical Diet'
                      : '⚠ Needs Monitoring'}
                  </span>
                </div>
                <StyledSelect
                  id="patient-nutrition-diet"
                  value={formData.nutritionDiet}
                  onChange={(val) => handleChange('nutritionDiet', val)}
                  options={NUTRITION_DIET_OPTIONS}
                />
                <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                  Records whether patient maintains regular, balanced, nutritious meals for cognitive vitality.
                </span>
              </div>

              {/* Alcohol Consumption Level */}
              <div>
                <label htmlFor="patient-alcohol" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Alcohol Level / Intake
                </label>
                <StyledSelect
                  id="patient-alcohol"
                  value={formData.alcoholLevel}
                  onChange={(val) => handleChange('alcoholLevel', val)}
                  options={ALCOHOL_OPTIONS}
                />
                <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                  Baseline intake frequency for cognitive health monitoring.
                </span>
              </div>

              {/* Smoking Status */}
              <div>
                <label htmlFor="patient-smoking" className="block text-xs font-semibold text-ink-soft dark:text-cream/80 mb-1.5">
                  Smoking Status
                </label>
                <StyledSelect
                  id="patient-smoking"
                  value={formData.smokingStatus}
                  onChange={(val) => handleChange('smokingStatus', val)}
                  options={SMOKING_OPTIONS}
                />
                <span className="text-[11px] text-ink-soft dark:text-cream/60 block mt-1">
                  Cardiovascular and cognitive health risk factor.
                </span>
              </div>
            </div>
          </section>

          {/* Form Section 4: Emergency Contact */}
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
                    errors.emergency_name ? 'border-alert dark:border-gold/70 focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.emergency_name)}
                />
                {errors.emergency_name && (
                  <p className="text-xs text-alert dark:text-gold flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5 text-alert dark:text-gold" />
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
                    errors.emergency_relationship ? 'border-alert dark:border-gold/70 focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.emergency_relationship)}
                />
                {errors.emergency_relationship && (
                  <p className="text-xs text-alert dark:text-gold flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5 text-alert dark:text-gold" />
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
                    errors.emergency_phone ? 'border-alert dark:border-gold/70 focus:border-alert' : 'border-border/80 dark:border-ink-soft/40 focus:border-terracotta'
                  }`}
                  aria-invalid={Boolean(errors.emergency_phone)}
                />
                {errors.emergency_phone && (
                  <p className="text-xs text-alert dark:text-gold flex items-center gap-1 mt-1 font-medium">
                    <AlertCircle className="w-3.5 h-3.5 text-alert dark:text-gold" />
                    <span>{errors.emergency_phone}</span>
                  </p>
                )}
              </div>
            </div>
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
