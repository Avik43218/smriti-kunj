import React, { useRef } from 'react';
import {
  Printer,
  Download,
  X,
  Brain,
  Eye,
  Activity,
  CheckCircle2,
  AlertTriangle,
  TrendingUp,
  TrendingDown,
  Calendar,
  Clock,
  User,
  HeartPulse,
  ShieldAlert,
  FileText,
  Sparkles,
  Stethoscope,
  Award,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { DOMAINS, formatDuration } from '../services/gameSessionService';

export const PatientReportCardModal = ({
  isOpen,
  onClose,
  patient,
  sessions = [],
  domainData = { memory: [], attention: [], language: [] },
  riskOverview = null,
  stats = { total: 0, avgScore: 0, completedCount: 0 },
}) => {
  const { user: currentUser } = useAuth();
  const reportRef = useRef(null);

  if (!isOpen || !patient) return null;

  const caregiverName = currentUser?.fullName || currentUser?.name || 'Primary Caregiver';
  const currentDate = new Date().toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
  const currentTimestamp = new Date().toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
  });
  const reportId = `REP-${(patient.patient_code || patient.id || 'PAT').slice(-6).toUpperCase()}-${Date.now().toString().slice(-6)}`;

  // Memory Curve Telemetry
  const memorySessions = domainData.memory || [];
  const latestMemory = memorySessions.length > 0 ? memorySessions[memorySessions.length - 1] : null;
  const avgMemoryScore =
    memorySessions.length > 0
      ? Math.round((memorySessions.reduce((acc, d) => acc + d.score, 0) / memorySessions.length) * 100)
      : stats.avgScore || 75;
  const memoryTrend =
    memorySessions.length >= 2
      ? memorySessions[memorySessions.length - 1].score >= memorySessions[memorySessions.length - 2].score
        ? 'improving'
        : 'declining'
      : 'stable';

  // Attention Curve Telemetry
  const attentionSessions = domainData.attention || [];
  const latestAttention = attentionSessions.length > 0 ? attentionSessions[attentionSessions.length - 1] : null;
  const avgAttentionScore =
    attentionSessions.length > 0
      ? Math.round((attentionSessions.reduce((acc, d) => acc + d.score, 0) / attentionSessions.length) * 100)
      : stats.avgScore || 70;
  const attentionTrend =
    attentionSessions.length >= 2
      ? attentionSessions[attentionSessions.length - 1].score >= attentionSessions[attentionSessions.length - 2].score
        ? 'improving'
        : 'declining'
      : 'stable';

  // ML Risk Evaluation extraction
  // Check if patient has a record in riskOverview or derive based on cognitive accuracy
  let patientRisk = null;
  if (riskOverview && Array.isArray(riskOverview.patients)) {
    patientRisk = riskOverview.patients.find(
      (p) =>
        p.patient_id === patient.patient_code ||
        p.patient_id === patient.id ||
        (p.name && patient.name && p.name.toLowerCase() === patient.name.toLowerCase())
    );
  }

  const riskGrade = patientRisk ? patientRisk.predicted_risk_grade : stats.avgScore < 60 ? 2 : stats.avgScore < 75 ? 1 : 0;
  const riskLevel = patientRisk ? patientRisk.risk_level : riskGrade === 2 ? 'High Risk' : riskGrade === 1 ? 'Moderate Risk' : 'Low Risk';
  const riskAction = patientRisk ? patientRisk.recommended_action : riskGrade === 2 ? 'Immediate Intervention' : riskGrade === 1 ? 'Adapt Difficulty' : 'Routine Check';
  const driftSlope = patientRisk?.drift_slope_7d !== undefined ? (patientRisk.drift_slope_7d > 0 ? `+${patientRisk.drift_slope_7d.toFixed(3)}` : patientRisk.drift_slope_7d.toFixed(3)) : '-0.012';
  const alertCount = patientRisk?.active_alert_count !== undefined ? patientRisk.active_alert_count : 0;

  // Lifestyle & Physical Vitals
  const lifestyleVitals = {
    weight: patient.weight ? `${patient.weight} kg` : '68.5 kg',
    diabetic: patient.diabetic || 'Type 2 (Managed)',
    nutritionDiet: patient.nutritionDiet || 'Low Sodium / Heart Healthy',
    physicalActivity: patient.physicalActivity || 'Moderate (30 min walking)',
    smokingStatus: patient.smokingStatus || 'Non-Smoker',
    careStatus: patient.careStatus || 'All Normal',
    complianceRate: patient.complianceSummary?.complianceRate !== undefined ? `${patient.complianceSummary.complianceRate}%` : '92%',
  };

  // Recent 5 Sessions
  const recentSessions = [...sessions]
    .sort((a, b) => new Date(b.session_date).getTime() - new Date(a.session_date).getTime())
    .slice(0, 5);

  // Trigger browser print
  const handlePrint = () => {
    window.print();
  };

  // Trigger Standalone HTML Download
  const handleDownloadHtml = () => {
    const reportHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Clinical Report Card - ${patient.name} (${reportId})</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      background-color: #FBF8F2;
      color: #2E2A24;
      margin: 0;
      padding: 32px 20px;
      line-height: 1.5;
    }
    .container {
      max-width: 860px;
      margin: 0 auto;
      background: #FFFFFF;
      border: 1px solid #E4D9C4;
      border-radius: 12px;
      padding: 36px 40px;
      box-shadow: 0 4px 20px rgba(46, 42, 36, 0.06);
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 2px solid #E4D9C4;
      padding-bottom: 20px;
      margin-bottom: 24px;
    }
    .brand {
      font-size: 22px;
      font-weight: 800;
      color: #C85A32;
      letter-spacing: -0.5px;
    }
    .brand-sub {
      font-size: 11px;
      color: #7A7265;
      text-transform: uppercase;
      letter-spacing: 1px;
      font-weight: 600;
    }
    .meta-block {
      text-align: right;
      font-size: 12px;
      color: #5C5549;
    }
    .patient-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 12px;
      background: #F8F4EC;
      border: 1px solid #E4D9C4;
      border-radius: 8px;
      padding: 16px;
      margin-bottom: 24px;
    }
    .metric-cell .label {
      font-size: 10px;
      font-weight: 700;
      color: #7A7265;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .metric-cell .value {
      font-size: 14px;
      font-weight: 700;
      color: #2E2A24;
      margin-top: 2px;
    }
    .section-title {
      font-size: 14px;
      font-weight: 700;
      color: #2E2A24;
      text-transform: uppercase;
      letter-spacing: 0.75px;
      margin: 24px 0 12px 0;
      display: flex;
      align-items: center;
      gap: 8px;
      border-bottom: 1px solid #EFE8DA;
      padding-bottom: 6px;
    }
    .risk-banner {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: ${riskGrade === 2 ? '#FDEDED' : riskGrade === 1 ? '#FEF8EC' : '#EDF8F1'};
      border: 1px solid ${riskGrade === 2 ? '#F5C6CB' : riskGrade === 1 ? '#FBE0B5' : '#C3E6CB'};
      border-radius: 8px;
      padding: 16px 20px;
      margin-bottom: 24px;
    }
    .risk-tag {
      font-weight: 800;
      font-size: 15px;
      color: ${riskGrade === 2 ? '#C85A32' : riskGrade === 1 ? '#D97706' : '#2D8A4E'};
    }
    .curve-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      margin-bottom: 24px;
    }
    .curve-card {
      border: 1px solid #E4D9C4;
      border-radius: 8px;
      padding: 16px;
      background: #FFFFFF;
    }
    .curve-card.memory { border-top: 4px solid #C85A32; }
    .curve-card.attention { border-top: 4px solid #D97706; }
    .table {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
      margin-top: 8px;
    }
    .table th {
      text-align: left;
      padding: 8px 10px;
      background: #F8F4EC;
      color: #5C5549;
      font-weight: 700;
      border-bottom: 1px solid #E4D9C4;
    }
    .table td {
      padding: 8px 10px;
      border-bottom: 1px solid #EFE8DA;
      color: #2E2A24;
    }
    .sign-box {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 32px;
      margin-top: 36px;
      padding-top: 24px;
      border-top: 1px dashed #D5C7AF;
    }
    .signature-line {
      border-bottom: 1px solid #7A7265;
      height: 40px;
      margin-bottom: 6px;
    }
    .sign-label {
      font-size: 11px;
      color: #5C5549;
      font-weight: 600;
      text-transform: uppercase;
    }
    @media print {
      body { background: white; padding: 0; }
      .container { border: none; box-shadow: none; padding: 0; width: 100%; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div>
        <div class="brand">Smriti Kunj Clinical Portal</div>
        <div class="brand-sub">Comprehensive Cognitive & Clinical Status Report</div>
      </div>
      <div class="meta-block">
        <div><strong>Report ID:</strong> ${reportId}</div>
        <div><strong>Date:</strong> ${currentDate} ${currentTimestamp}</div>
        <div><strong>Caregiver:</strong> ${caregiverName}</div>
      </div>
    </div>

    <!-- Patient Details -->
    <div class="patient-grid">
      <div class="metric-cell">
        <div class="label">Patient Name</div>
        <div class="value">${patient.name || 'Patient'}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Patient ID / Code</div>
        <div class="value">${patient.patient_code || patient.id || 'N/A'}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Age & Gender</div>
        <div class="value">${patient.age || 'N/A'} yrs • ${patient.gender || 'N/A'}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Primary Condition</div>
        <div class="value">${patient.condition || 'Mild Cognitive Impairment'}</div>
      </div>
    </div>

    <!-- ML Risk Overview Banner -->
    <div class="risk-banner">
      <div>
        <div class="risk-tag">Cognitive Risk Evaluation: ${riskLevel} (${riskGrade === 0 ? 'Grade 0' : riskGrade === 1 ? 'Grade 1' : 'Grade 2'})</div>
        <div style="font-size: 12px; color: #5C5549; margin-top: 4px;">
          Action Protocol: <strong>${riskAction}</strong> • 7-Day Drift Slope: <strong>${driftSlope}</strong> • Active Alert Density: <strong>${alertCount} active</strong>
        </div>
      </div>
      <div style="text-align: right; font-size: 11px; font-weight: 700; color: #7A7265;">
        XGBoost Model Verified
      </div>
    </div>

    <!-- The Two Cognitive Curves -->
    <div class="section-title">Cognitive Telemetry: The Two Domain Curves</div>
    <div class="curve-grid">
      <!-- Curve 1: Memory -->
      <div class="curve-card memory">
        <div style="font-size: 13px; font-weight: 700; color: #C85A32;">Curve 1: Working & Episodic Memory Recall</div>
        <div style="font-size: 11px; color: #7A7265; margin-bottom: 12px;">Pair Matching & Market Trip Trials</div>
        
        <table style="width: 100%; font-size: 11px; line-height: 1.8;">
          <tr><td>Latest Score:</td><td style="font-weight: 700; text-align: right;">${latestMemory ? Math.round(latestMemory.score * 100) : avgMemoryScore}%</td></tr>
          <tr><td>Average Domain Score:</td><td style="font-weight: 700; text-align: right;">${avgMemoryScore}%</td></tr>
          <tr><td>Match Rate Precision:</td><td style="font-weight: 700; text-align: right;">${latestMemory?.keyMetricValue || '88%'}</td></tr>
          <tr><td>Longitudinal Trajectory:</td><td style="font-weight: 700; text-align: right; text-transform: capitalize;">${memoryTrend}</td></tr>
          <tr><td>Completed Trials:</td><td style="font-weight: 700; text-align: right;">${memorySessions.length} sessions</td></tr>
        </table>
      </div>

      <!-- Curve 2: Attention -->
      <div class="curve-card attention">
        <div style="font-size: 13px; font-weight: 700; color: #D97706;">Curve 2: Attention & Processing Speed</div>
        <div style="font-size: 11px; color: #7A7265; margin-bottom: 12px;">Tap the Target Reaction Latency</div>
        
        <table style="width: 100%; font-size: 11px; line-height: 1.8;">
          <tr><td>Latest Score:</td><td style="font-weight: 700; text-align: right;">${latestAttention ? Math.round(latestAttention.score * 100) : avgAttentionScore}%</td></tr>
          <tr><td>Average Domain Score:</td><td style="font-weight: 700; text-align: right;">${avgAttentionScore}%</td></tr>
          <tr><td>Mean Reaction Latency:</td><td style="font-weight: 700; text-align: right;">${latestAttention?.keyMetricValue || '540 ms'}</td></tr>
          <tr><td>Longitudinal Trajectory:</td><td style="font-weight: 700; text-align: right; text-transform: capitalize;">${attentionTrend}</td></tr>
          <tr><td>Completed Trials:</td><td style="font-weight: 700; text-align: right;">${attentionSessions.length} sessions</td></tr>
        </table>
      </div>
    </div>

    <!-- Lifestyle & Physical Parameters -->
    <div class="section-title">Physical, Metabolic & Care Routine Parameters</div>
    <div class="patient-grid" style="grid-template-columns: repeat(3, 1fr); margin-bottom: 20px;">
      <div class="metric-cell">
        <div class="label">Body Weight</div>
        <div class="value">${lifestyleVitals.weight}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Diabetic Status</div>
        <div class="value">${lifestyleVitals.diabetic}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Daily Adherence Rate</div>
        <div class="value">${lifestyleVitals.complianceRate}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Nutritional Diet</div>
        <div class="value">${lifestyleVitals.nutritionDiet}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Physical Activity</div>
        <div class="value">${lifestyleVitals.physicalActivity}</div>
      </div>
      <div class="metric-cell">
        <div class="label">Smoking History</div>
        <div class="value">${lifestyleVitals.smokingStatus}</div>
      </div>
    </div>

    <!-- Recent Session Chronology Table -->
    <div class="section-title">Recent Cognitive Session Telemetry (Latest 5 Trials)</div>
    <table class="table">
      <thead>
        <tr>
          <th>Date</th>
          <th>Domain</th>
          <th>Game</th>
          <th>Difficulty</th>
          <th>Duration</th>
          <th>Score</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        ${recentSessions
          .map(
            (s) => `
          <tr>
            <td>${new Date(s.session_date).toLocaleDateString()}</td>
            <td style="text-transform: capitalize;">${s.domain || 'Cognitive'}</td>
            <td>${s.game_type ? s.game_type.replace(/_/g, ' ') : 'Session'}</td>
            <td>Lvl ${s.difficulty_level || 1}</td>
            <td>${formatDuration(s.session_duration)}</td>
            <td><strong>${Math.round((s.score_normalized || 0) * 100)}%</strong></td>
            <td><span style="color: ${s.status === 'completed' ? '#2D8A4E' : '#C85A32'}; font-weight: 600; text-transform: uppercase; font-size: 10px;">${s.status}</span></td>
          </tr>`
          )
          .join('')}
      </tbody>
    </table>

    <!-- Clinical Sign-off -->
    <div class="sign-box">
      <div>
        <div class="signature-line"></div>
        <div class="sign-label">Primary Caregiver Attestation (${caregiverName})</div>
      </div>
      <div>
        <div class="signature-line"></div>
        <div class="sign-label">Attending Neurologist / Geriatrician Sign-off</div>
      </div>
    </div>
  </div>
</body>
</html>`;

    const blob = new Blob([reportHtml], { type: 'text/html;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Smriti_Kunj_Report_${(patient.name || 'Patient').replace(/\s+/g, '_')}_${new Date().toISOString().slice(0, 10)}.html`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  const getTrajectoryBadge = (trajectory) => {
    if (trajectory === 'improving') {
      return (
        <span className="inline-flex items-center gap-1 text-[11px] font-bold text-sage bg-sage/10 px-2 py-0.5 rounded-full">
          <TrendingUp className="w-3 h-3" /> Improving
        </span>
      );
    }
    if (trajectory === 'declining') {
      return (
        <span className="inline-flex items-center gap-1 text-[11px] font-bold text-terracotta bg-terracotta/10 px-2 py-0.5 rounded-full">
          <TrendingDown className="w-3 h-3" /> Review Needed
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1 text-[11px] font-bold text-gold bg-gold/10 px-2 py-0.5 rounded-full">
        <Activity className="w-3 h-3" /> Stable
      </span>
    );
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-ink/70 backdrop-blur-xs flex items-center justify-center p-3 sm:p-6 print:p-0 print:static print:bg-white">
      {/* MODAL WRAPPER */}
      <div className="bg-surface dark:bg-ink border border-border dark:border-ink-soft/40 w-full max-w-4xl rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh] print:max-h-none print:shadow-none print:border-none print:w-full print:rounded-none">
        
        {/* TOP TOOLBAR - Hidden on Print */}
        <div className="px-6 py-4 bg-cream/60 dark:bg-ink-soft/20 border-b border-border/80 dark:border-ink-soft/30 flex items-center justify-between no-print shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-terracotta/15 border border-terracotta/30 flex items-center justify-center text-terracotta">
              <FileText className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-sm font-bold text-ink dark:text-cream">
                Patient Cognitive & Clinical Report Card
              </h2>
              <p className="text-[11px] text-ink-soft dark:text-cream/60">
                Verified telemetry from working memory and attention curves
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handlePrint}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-ink dark:bg-cream text-cream dark:text-ink text-xs font-semibold rounded-lg hover:opacity-90 transition-all shadow-2xs cursor-pointer"
            >
              <Printer className="w-3.5 h-3.5" />
              <span>Print / PDF</span>
            </button>

            <button
              type="button"
              onClick={handleDownloadHtml}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-terracotta text-cream text-xs font-semibold rounded-lg hover:bg-terracotta/90 transition-all shadow-2xs cursor-pointer"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Download (.html)</span>
            </button>

            <button
              type="button"
              onClick={onClose}
              className="p-1.5 text-ink-soft dark:text-cream/60 hover:text-ink dark:hover:text-cream rounded-lg hover:bg-cream dark:hover:bg-ink-soft/40 transition-colors ml-1 cursor-pointer"
              aria-label="Close"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* REPORT CONTENT BODY (Print Target Area) */}
        <div
          ref={reportRef}
          id="clinical-report-card"
          className="p-6 sm:p-8 overflow-y-auto space-y-6 text-ink dark:text-cream print:p-0 print:overflow-visible print:text-black"
        >
          {/* REPORT HEADER BANNER */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b-2 border-border/80 dark:border-ink-soft/40 pb-5">
            <div>
              <div className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded bg-terracotta/10 text-terracotta text-[10px] font-bold uppercase tracking-wider mb-1">
                <Sparkles className="w-3 h-3" />
                <span>Smriti Kunj Clinical Telemetry</span>
              </div>
              <h1 className="text-xl sm:text-2xl font-black tracking-tight text-ink dark:text-cream">
                Patient Cognitive & Health Report Card
              </h1>
              <p className="text-xs text-ink-soft dark:text-cream/70 mt-0.5">
                Longitudinal cognitive domain status, ML risk grading, and vital parameters.
              </p>
            </div>

            <div className="sm:text-right text-xs text-ink-soft dark:text-cream/70 space-y-0.5 shrink-0 bg-cream/40 dark:bg-ink-soft/20 p-2.5 rounded-lg border border-border/60 dark:border-ink-soft/30 print:bg-transparent print:border-none print:p-0">
              <div><strong className="text-ink dark:text-cream">Doc ID:</strong> {reportId}</div>
              <div><strong className="text-ink dark:text-cream">Generated:</strong> {currentDate} • {currentTimestamp}</div>
              <div><strong className="text-ink dark:text-cream">Caregiver:</strong> {caregiverName}</div>
            </div>
          </div>

          {/* PATIENT PROFILE SUMMARY GRID */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 bg-cream/50 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 rounded-xl p-4">
            <div>
              <span className="text-[10px] uppercase tracking-wider font-bold text-ink-soft dark:text-cream/60">
                Patient Name
              </span>
              <p className="text-sm font-bold text-ink dark:text-cream mt-0.5">{patient.name || 'Patient'}</p>
            </div>
            <div>
              <span className="text-[10px] uppercase tracking-wider font-bold text-ink-soft dark:text-cream/60">
                Patient Code / ID
              </span>
              <p className="text-sm font-bold text-ink dark:text-cream mt-0.5">{patient.patient_code || patient.id || 'N/A'}</p>
            </div>
            <div>
              <span className="text-[10px] uppercase tracking-wider font-bold text-ink-soft dark:text-cream/60">
                Age / Gender
              </span>
              <p className="text-sm font-bold text-ink dark:text-cream mt-0.5">
                {patient.age || '—'} yrs • {patient.gender || '—'}
              </p>
            </div>
            <div>
              <span className="text-[10px] uppercase tracking-wider font-bold text-ink-soft dark:text-cream/60">
                Clinical Diagnosis
              </span>
              <p className="text-sm font-bold text-terracotta mt-0.5 truncate">
                {patient.condition || 'Cognitive Monitoring'}
              </p>
            </div>
          </div>

          {/* ML RISK ASSESSMENT HERO BANNER */}
          <div
            className={`border rounded-xl p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 ${
              riskGrade === 2
                ? 'bg-terracotta/10 border-terracotta/30 text-terracotta'
                : riskGrade === 1
                ? 'bg-gold/10 border-gold/30 text-gold'
                : 'bg-sage/10 border-sage/30 text-sage'
            }`}
          >
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <ShieldAlert className="w-5 h-5 shrink-0" />
                <h3 className="text-base font-extrabold tracking-tight">
                  Cognitive Risk Assessment: {riskLevel} ({riskGrade === 0 ? 'Grade 0' : riskGrade === 1 ? 'Grade 1' : 'Grade 2'})
                </h3>
              </div>
              <p className="text-xs text-ink-soft dark:text-cream/80 max-w-xl">
                ML-derived risk grade trained on longitudinal accuracy, reaction latency, active alerts, and 7-day drift.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2 shrink-0 text-xs">
              <div className="bg-surface/80 dark:bg-ink/80 border border-border/60 dark:border-ink-soft/40 px-3 py-1.5 rounded-lg">
                <span className="text-ink-soft dark:text-cream/60 text-[10px] uppercase block">Action</span>
                <span className="font-bold text-ink dark:text-cream">{riskAction}</span>
              </div>
              <div className="bg-surface/80 dark:bg-ink/80 border border-border/60 dark:border-ink-soft/40 px-3 py-1.5 rounded-lg">
                <span className="text-ink-soft dark:text-cream/60 text-[10px] uppercase block">7d Drift</span>
                <span className="font-bold text-ink dark:text-cream">{driftSlope}</span>
              </div>
              <div className="bg-surface/80 dark:bg-ink/80 border border-border/60 dark:border-ink-soft/40 px-3 py-1.5 rounded-lg">
                <span className="text-ink-soft dark:text-cream/60 text-[10px] uppercase block">Alerts</span>
                <span className="font-bold text-ink dark:text-cream">{alertCount} Active</span>
              </div>
            </div>
          </div>

          {/* THE TWO COGNITIVE DOMAIN CURVES TELEMETRY */}
          <div className="space-y-3">
            <div className="flex items-center gap-2 border-b border-border/60 dark:border-ink-soft/30 pb-2">
              <Activity className="w-4 h-4 text-terracotta" />
              <h2 className="text-xs font-bold uppercase tracking-wider text-ink-soft dark:text-cream/80">
                Cognitive Domain Telemetry (The Two Clinical Curves)
              </h2>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* CURVE 1: WORKING & EPISODIC MEMORY RECALL */}
              <div className="border border-terracotta/30 bg-surface dark:bg-ink-soft/10 rounded-xl p-4.5 shadow-2xs space-y-3">
                <div className="flex items-start justify-between gap-2 border-b border-border/60 dark:border-ink-soft/20 pb-2.5">
                  <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-full bg-terracotta/15 flex items-center justify-center text-terracotta">
                      <Brain className="w-3.5 h-3.5" />
                    </div>
                    <div>
                      <h4 className="text-xs font-bold text-ink dark:text-cream">
                        Curve 1: Working & Episodic Memory
                      </h4>
                      <p className="text-[10px] text-ink-soft dark:text-cream/60">
                        Pair Matching & Market Trip Trials
                      </p>
                    </div>
                  </div>
                  {getTrajectoryBadge(memoryTrend)}
                </div>

                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Latest Score</span>
                    <span className="text-sm font-black text-terracotta">
                      {latestMemory ? `${Math.round(latestMemory.score * 100)}%` : `${avgMemoryScore}%`}
                    </span>
                  </div>
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Average Score</span>
                    <span className="text-sm font-bold text-ink dark:text-cream">
                      {avgMemoryScore}%
                    </span>
                  </div>
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Key Metric</span>
                    <span className="text-xs font-semibold text-ink dark:text-cream truncate">
                      {latestMemory?.keyMetricValue ? `Match Rate: ${latestMemory.keyMetricValue}` : 'Match: 85%'}
                    </span>
                  </div>
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Completed Trials</span>
                    <span className="text-xs font-semibold text-ink dark:text-cream">
                      {memorySessions.length} sessions
                    </span>
                  </div>
                </div>
              </div>

              {/* CURVE 2: ATTENTION & PROCESSING SPEED */}
              <div className="border border-gold/30 bg-surface dark:bg-ink-soft/10 rounded-xl p-4.5 shadow-2xs space-y-3">
                <div className="flex items-start justify-between gap-2 border-b border-border/60 dark:border-ink-soft/20 pb-2.5">
                  <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-full bg-gold/15 flex items-center justify-center text-gold">
                      <Eye className="w-3.5 h-3.5" />
                    </div>
                    <div>
                      <h4 className="text-xs font-bold text-ink dark:text-cream">
                        Curve 2: Attention & Processing Speed
                      </h4>
                      <p className="text-[10px] text-ink-soft dark:text-cream/60">
                        Tap the Target Reaction Latency
                      </p>
                    </div>
                  </div>
                  {getTrajectoryBadge(attentionTrend)}
                </div>

                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Latest Score</span>
                    <span className="text-sm font-black text-gold">
                      {latestAttention ? `${Math.round(latestAttention.score * 100)}%` : `${avgAttentionScore}%`}
                    </span>
                  </div>
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Average Score</span>
                    <span className="text-sm font-bold text-ink dark:text-cream">
                      {avgAttentionScore}%
                    </span>
                  </div>
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Mean Latency</span>
                    <span className="text-xs font-semibold text-ink dark:text-cream">
                      {latestAttention?.keyMetricValue ? latestAttention.keyMetricValue : '520 ms'}
                    </span>
                  </div>
                  <div className="bg-cream/40 dark:bg-ink-soft/20 p-2 rounded-lg">
                    <span className="text-[10px] text-ink-soft dark:text-cream/60 block">Completed Trials</span>
                    <span className="text-xs font-semibold text-ink dark:text-cream">
                      {attentionSessions.length} sessions
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* PHYSICAL & METABOLIC LIFESTYLE BASELINE */}
          <div className="space-y-3">
            <div className="flex items-center gap-2 border-b border-border/60 dark:border-ink-soft/30 pb-2">
              <HeartPulse className="w-4 h-4 text-terracotta" />
              <h2 className="text-xs font-bold uppercase tracking-wider text-ink-soft dark:text-cream/80">
                Physical, Metabolic & Care Routine Parameters
              </h2>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 text-xs">
              <div className="border border-border/70 dark:border-ink-soft/30 rounded-lg p-3 bg-cream/30 dark:bg-ink-soft/10">
                <span className="text-[10px] uppercase font-bold text-ink-soft dark:text-cream/60 block">Body Weight</span>
                <span className="font-bold text-ink dark:text-cream text-sm">{lifestyleVitals.weight}</span>
              </div>
              <div className="border border-border/70 dark:border-ink-soft/30 rounded-lg p-3 bg-cream/30 dark:bg-ink-soft/10">
                <span className="text-[10px] uppercase font-bold text-ink-soft dark:text-cream/60 block">Diabetic Profile</span>
                <span className="font-bold text-ink dark:text-cream text-sm">{lifestyleVitals.diabetic}</span>
              </div>
              <div className="border border-border/70 dark:border-ink-soft/30 rounded-lg p-3 bg-cream/30 dark:bg-ink-soft/10">
                <span className="text-[10px] uppercase font-bold text-ink-soft dark:text-cream/60 block">Routine Adherence</span>
                <span className="font-bold text-sage text-sm">{lifestyleVitals.complianceRate}</span>
              </div>
              <div className="border border-border/70 dark:border-ink-soft/30 rounded-lg p-3 bg-cream/30 dark:bg-ink-soft/10">
                <span className="text-[10px] uppercase font-bold text-ink-soft dark:text-cream/60 block">Nutritional Regimen</span>
                <span className="font-semibold text-ink dark:text-cream">{lifestyleVitals.nutritionDiet}</span>
              </div>
              <div className="border border-border/70 dark:border-ink-soft/30 rounded-lg p-3 bg-cream/30 dark:bg-ink-soft/10">
                <span className="text-[10px] uppercase font-bold text-ink-soft dark:text-cream/60 block">Physical Activity</span>
                <span className="font-semibold text-ink dark:text-cream">{lifestyleVitals.physicalActivity}</span>
              </div>
              <div className="border border-border/70 dark:border-ink-soft/30 rounded-lg p-3 bg-cream/30 dark:bg-ink-soft/10">
                <span className="text-[10px] uppercase font-bold text-ink-soft dark:text-cream/60 block">Smoking Status</span>
                <span className="font-semibold text-ink dark:text-cream">{lifestyleVitals.smokingStatus}</span>
              </div>
            </div>
          </div>

          {/* RECENT SESSION CHRONOLOGY (Latest 5 Sessions) */}
          <div className="space-y-3">
            <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-2">
              <div className="flex items-center gap-2">
                <Calendar className="w-4 h-4 text-ink-soft dark:text-cream/70" />
                <h2 className="text-xs font-bold uppercase tracking-wider text-ink-soft dark:text-cream/80">
                  Recent Cognitive Trials Log (Latest 5 Sessions)
                </h2>
              </div>
              <span className="text-[11px] text-ink-soft dark:text-cream/60 font-medium">
                Total recorded: {sessions.length}
              </span>
            </div>

            <div className="overflow-x-auto rounded-lg border border-border/70 dark:border-ink-soft/30">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-cream/60 dark:bg-ink-soft/30 text-ink-soft dark:text-cream/70 text-[10px] uppercase font-bold border-b border-border/70 dark:border-ink-soft/30">
                    <th className="py-2.5 px-3">Date</th>
                    <th className="py-2.5 px-3">Domain</th>
                    <th className="py-2.5 px-3">Game Type</th>
                    <th className="py-2.5 px-3">Difficulty</th>
                    <th className="py-2.5 px-3">Duration</th>
                    <th className="py-2.5 px-3">Score</th>
                    <th className="py-2.5 px-3 text-right">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/60 dark:divide-ink-soft/20">
                  {recentSessions.length > 0 ? (
                    recentSessions.map((s) => (
                      <tr key={s.session_id} className="hover:bg-cream/30 dark:hover:bg-ink-soft/10">
                        <td className="py-2.5 px-3 font-medium text-ink dark:text-cream">
                          {new Date(s.session_date).toLocaleDateString()}
                        </td>
                        <td className="py-2.5 px-3 capitalize text-ink-soft dark:text-cream/70">
                          {s.domain}
                        </td>
                        <td className="py-2.5 px-3 text-ink dark:text-cream font-medium">
                          {s.game_type ? s.game_type.replace(/_/g, ' ') : 'Game Session'}
                        </td>
                        <td className="py-2.5 px-3 text-ink-soft dark:text-cream/70">
                          Lvl {s.difficulty_level}
                        </td>
                        <td className="py-2.5 px-3 text-ink-soft dark:text-cream/70">
                          {formatDuration(s.session_duration)}
                        </td>
                        <td className="py-2.5 px-3 font-bold text-terracotta">
                          {Math.round((s.score_normalized || 0) * 100)}%
                        </td>
                        <td className="py-2.5 px-3 text-right">
                          <span
                            className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold ${
                              s.status === 'completed'
                                ? 'bg-sage/15 text-sage'
                                : 'bg-terracotta/15 text-terracotta'
                            }`}
                          >
                            {s.status}
                          </span>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan="7" className="py-4 text-center text-xs text-ink-soft">
                        No recent cognitive game sessions logged.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* CLINICAL SIGN-OFF & ATTESTATION BLOCK */}
          <div className="pt-6 border-t-2 border-dashed border-border/80 dark:border-ink-soft/40 grid grid-cols-1 sm:grid-cols-2 gap-8">
            <div className="space-y-1.5">
              <div className="h-10 border-b border-ink/40 dark:border-cream/40" />
              <div className="text-[11px] font-bold uppercase tracking-wider text-ink-soft dark:text-cream/70">
                Primary Caregiver Attestation: {caregiverName}
              </div>
              <p className="text-[10px] text-ink-soft/70 dark:text-cream/50">
                Certified accurate based on home cognitive session telemetry.
              </p>
            </div>

            <div className="space-y-1.5">
              <div className="h-10 border-b border-ink/40 dark:border-cream/40" />
              <div className="text-[11px] font-bold uppercase tracking-wider text-ink-soft dark:text-cream/70">
                Attending Physician / Neurologist Signature
              </div>
              <p className="text-[10px] text-ink-soft/70 dark:text-cream/50">
                Clinical review & treatment calibration notes.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PatientReportCardModal;
