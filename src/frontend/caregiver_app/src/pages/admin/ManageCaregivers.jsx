import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  getCaregivers,
  getAllPatients, // Added to fetch patients for the nested cards
  createCaregiver,
  updateCaregiver,
  deleteCaregiver,
} from '../../services/adminService';
import { StyledSelect } from '../../components/StyledSelect';
import {
  Users,
  UserPlus,
  Search,
  Edit2,
  Trash2,
  CheckCircle,
  XCircle,
  AlertCircle,
  RefreshCw,
  X,
  ArrowLeft,
  ChevronDown,
  ChevronUp,
  Tablet,
  HeartHandshake
} from 'lucide-react';

export const ManageCaregivers = () => {
  const [caregivers, setCaregivers] = useState([]);
  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');

  // Track which caregiver's card is expanded
  const [expandedCaregiverId, setExpandedCaregiverId] = useState(null);

  // Modals
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingCaregiver, setEditingCaregiver] = useState(null);
  const [deletingCaregiver, setDeletingCaregiver] = useState(null);

  // Form states
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    region_language: 'en',
    status: 'active',
  });
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [cgData, ptData] = await Promise.all([
        getCaregivers(),
        getAllPatients()
      ]);
      setCaregivers(cgData || []);
      setPatients(ptData || []);
    } catch (err) {
      setError(err?.message || 'Failed to fetch caregiver records.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const filteredCaregivers = useMemo(() => {
    if (!searchQuery.trim()) return caregivers;
    const query = searchQuery.toLowerCase().trim();
    return caregivers.filter(
      (c) =>
        c.name?.toLowerCase().includes(query) ||
        c.email?.toLowerCase().includes(query)
    );
  }, [caregivers, searchQuery]);

  const getCaregiverPatients = (caregiverId) => {
    return patients.filter(p => String(p.caregiver_id) === String(caregiverId));
  };

  const toggleExpand = (id) => {
    setExpandedCaregiverId(prev => prev === id ? null : id);
  };

  // Open Add Modal
  const handleOpenAddModal = () => {
    setFormData({ name: '', email: '', password: '', region_language: 'en', status: 'active' });
    setFormError(null);
    setIsAddModalOpen(true);
  };

  // Open Edit Modal
  const handleOpenEditModal = (cg, e) => {
    e.stopPropagation();
    setEditingCaregiver(cg);
    setFormData({
      name: cg.name,
      email: cg.email,
      password: '',
      region_language: cg.region_language || 'en',
      status: cg.status || 'active',
    });
    setFormError(null);
  };

  // Handle Add Submit
  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    setFormSubmitting(true);
    setFormError(null);
    try {
      await createCaregiver(formData);
      setSuccessMessage(`Caregiver account created successfully.`);
      setIsAddModalOpen(false);
      await loadData();
    } catch (err) {
      setFormError(err?.message || 'Failed to create caregiver.');
    } finally {
      setFormSubmitting(false);
    }
  };

  // Handle Edit Submit
  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!editingCaregiver) return;
    setFormSubmitting(true);
    setFormError(null);
    try {
      await updateCaregiver(editingCaregiver.id, {
        name: formData.name,
        email: formData.email,
        region_language: formData.region_language,
        status: formData.status,
      });
      setSuccessMessage(`Caregiver updated successfully.`);
      setEditingCaregiver(null);
      await loadData();
    } catch (err) {
      setFormError(err?.message || 'Failed to update caregiver.');
    } finally {
      setFormSubmitting(false);
    }
  };

  // Quick Toggle Status
  const handleToggleStatus = async (cg, e) => {
    e.stopPropagation();
    const newStatus = cg.status === 'active' ? 'disabled' : 'active';
    try {
      await updateCaregiver(cg.id, { status: newStatus });
      setSuccessMessage(`Caregiver status updated.`);
      await loadData();
    } catch (err) {
      setError(err?.message || 'Failed to toggle status.');
    }
  };

  // Confirm Delete
  const handleConfirmDelete = async () => {
    if (!deletingCaregiver) return;
    setFormSubmitting(true);
    setFormError(null);
    try {
      if (deletingCaregiver.patient_count > 0) {
        throw new Error(`Cannot delete caregiver with active patients.`);
      }
      await deleteCaregiver(deletingCaregiver.id);
      setSuccessMessage(`Caregiver removed.`);
      setDeletingCaregiver(null);
      await loadData();
    } catch (err) {
      setFormError(err?.message || 'Failed to delete caregiver.');
    } finally {
      setFormSubmitting(false);
    }
  };

  return (
    <div className="space-y-6 sm:space-y-8 font-sans pb-10">
      {/* Return to Admin Dashboard Button (Matches PatientLayout All Patients floating pill button) */}
      <Link
        to="/admin/dashboard"
        aria-label="Back to Admin Dashboard"
        className="fixed top-3.5 left-3.5 sm:top-5 sm:left-6 z-40 inline-flex items-center justify-center gap-1.5 w-8 h-8 sm:w-auto sm:h-auto sm:px-3.5 sm:py-2 bg-surface/90 dark:bg-ink/90 backdrop-blur-md border border-border/80 dark:border-ink-soft/40 rounded-full shadow-md text-xs sm:text-sm font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all select-none outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
      >
        <ArrowLeft className="w-4 h-4 text-terracotta shrink-0" />
        <span className="hidden sm:inline">Back to Admin</span>
      </Link>

      <header className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border/60 dark:border-ink-soft/30 pb-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream">
            Manage Caregivers
          </h1>
          <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-0.5">
            Provision caregiver credentials, configure access status, and balance patient workloads.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={loadData}
            disabled={loading}
            aria-label="Refresh caregiver list"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all outline-none focus-visible:ring-1 focus-visible:ring-terracotta"
          >
            <RefreshCw className={`w-3.5 h-3.5 text-terracotta ${loading ? 'animate-spin' : ''}`} />
            <span className="hidden sm:inline">Refresh</span>
          </button>
          <button
            type="button"
            onClick={handleOpenAddModal}
            className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-terracotta hover:bg-terracotta-dark text-cream text-xs sm:text-sm font-medium rounded-xl shadow-xs transition-colors shrink-0 outline-none focus-visible:ring-2 focus-visible:ring-terracotta/40"
          >
            <UserPlus className="w-4 h-4" />
            <span>Add New Caregiver</span>
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

      {/* Search Bar */}
      <div className="flex flex-col sm:flex-row items-center gap-3">
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 text-ink-soft/70 dark:text-cream/50 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search caregivers by name or email..."
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
        <span className="text-xs text-ink-soft dark:text-cream/60 font-medium shrink-0">
          Showing {filteredCaregivers.length} of {caregivers.length} caregivers
        </span>
      </div>

      {/* Caregiver Cards Grid */}
      <div className="grid grid-cols-1 gap-4">
        {filteredCaregivers.map((cg) => {
          const isExpanded = expandedCaregiverId === cg.id;
          const assignedPatients = getCaregiverPatients(cg.id);

          return (
            <div
              key={cg.id}
              className="rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden"
            >
              {/* Card Header / Main Info */}
              <div
                className="p-5 sm:p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4 cursor-pointer hover:bg-cream/20 dark:hover:bg-ink-soft/10 transition-colors"
                onClick={() => toggleExpand(cg.id)}
              >
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full bg-terracotta/15 text-terracotta font-bold flex items-center justify-center text-lg shadow-xs">
                    {cg.name ? cg.name[0].toUpperCase() : 'C'}
                  </div>
                  <div>
                    <h3 className="text-base sm:text-lg font-bold text-ink dark:text-cream flex items-center gap-2">
                      {cg.name}
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold border ${cg.status === 'active' ? 'bg-sage/15 text-sage border-sage/30' : 'bg-alert/15 text-alert border-alert/30'
                        }`}>
                        {cg.status === 'active' ? 'Active' : 'Disabled'}
                      </span>
                    </h3>
                    <div className="flex items-center gap-3 mt-1 text-xs text-ink-soft dark:text-cream/60">
                      <span>{cg.email}</span>
                      <span className="text-[10px] bg-border dark:bg-ink-soft/30 px-1.5 py-0.5 rounded uppercase font-mono">
                        {cg.region_language || 'EN'}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center justify-between sm:justify-end gap-6 w-full sm:w-auto">
                  {/* Patients Counter */}
                  <div className="flex flex-col items-center sm:items-end">
                    <span className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream leading-none">{cg.patient_count ?? 0}</span>
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/50 mt-1">Patients</span>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-2" onClick={e => e.stopPropagation()}>
                    <button
                      onClick={(e) => handleToggleStatus(cg, e)}
                      title="Toggle Status"
                      className="p-2 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 text-ink-soft hover:text-ink dark:text-cream/70 dark:hover:text-cream transition-colors shadow-xs"
                    >
                      {cg.status === 'active' ? <CheckCircle className="w-4 h-4 text-sage" /> : <XCircle className="w-4 h-4 text-alert" />}
                    </button>
                    <button
                      onClick={(e) => handleOpenEditModal(cg, e)}
                      title="Edit Caregiver"
                      className="p-2 rounded-full bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 text-ink-soft hover:text-ink dark:text-cream/70 dark:hover:text-cream transition-colors shadow-xs"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setDeletingCaregiver(cg);
                        setFormError(null);
                      }}
                      title="Delete Caregiver"
                      className="p-2 rounded-full bg-alert/10 border border-alert/20 text-alert hover:bg-alert hover:text-cream transition-colors shadow-xs"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>

                    {/* Expand Chevron */}
                    <div className="ml-2 pl-2 border-l border-border dark:border-ink-soft/30 text-ink-soft dark:text-cream/50">
                      {isExpanded ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
                    </div>
                  </div>
                </div>
              </div>

              {/* Expanded Nested Patients Area */}
              {isExpanded && (
                <div className="bg-cream/40 dark:bg-ink-soft/10 border-t border-border/60 dark:border-ink-soft/30 p-5 sm:p-6">
                  <h4 className="text-xs sm:text-sm font-bold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-3 flex items-center gap-2">
                    <HeartHandshake className="w-3.5 h-3.5 text-terracotta" /> Assigned Patients Roster
                  </h4>

                  {assignedPatients.length === 0 ? (
                    <div className="text-center p-6 border border-dashed border-border/80 dark:border-ink-soft/40 rounded-xl text-xs sm:text-sm text-ink-soft dark:text-cream/60">
                      No patients are currently assigned to this caregiver.
                    </div>
                  ) : (
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                      {assignedPatients.map(pt => (
                        <div key={pt.id || pt.uuid_id} className="bg-surface dark:bg-ink-soft/25 border border-border/80 dark:border-ink-soft/40 p-3.5 rounded-xl shadow-xs flex gap-3 transition-colors">
                          <div className="w-10 h-10 shrink-0 rounded-lg bg-gold/15 text-gold-dark font-bold flex items-center justify-center text-sm uppercase shadow-xs">
                            {pt.name ? pt.name[0] : 'P'}
                          </div>
                          <div className="flex-1 min-w-0">
                            <h5 className="text-sm font-bold text-ink dark:text-cream truncate">{pt.name}</h5>
                            <p className="text-[11px] text-ink-soft dark:text-cream/60 truncate mb-1">
                              {pt.diagnosis || 'Dementia / Memory Care'} • {pt.age ? `${pt.age}y` : 'Age N/A'}
                            </p>
                            <div className="flex items-center justify-between">
                              <span className={`text-[10px] font-semibold px-2 py-0.5 rounded border ${pt.status === 'stable' || pt.status === 'normal' || pt.status === 'active' ? 'bg-sage/15 text-sage border-sage/30' : 'bg-alert/15 text-alert border-alert/30'
                                }`}>
                                {pt.status_label || 'Active'}
                              </span>
                              <span className="text-[10px] font-mono text-ink-soft dark:text-cream/50 flex items-center gap-1">
                                <Tablet className="w-2.5 h-2.5" /> {pt.patient_code || 'No Code'}
                              </span>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}

        {filteredCaregivers.length === 0 && !loading && (
          <div className="py-12 text-center border-2 border-dashed border-border dark:border-ink-soft/30 rounded-xl text-ink-soft dark:text-cream/60">
            No caregivers found matching your search.
          </div>
        )}
      </div>

      {/* Add / Edit / Delete Modals */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink/60 backdrop-blur-xs animate-in fade-in duration-150">
          <div className="w-full max-w-md bg-surface dark:bg-ink-soft/20 backdrop-blur-2xl border border-border/80 dark:border-ink-soft/40 rounded-card shadow-card p-6 sm:p-7 space-y-4">
            <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-3">
              <div className="flex items-center gap-2">
                <UserPlus className="w-5 h-5 text-terracotta" />
                <h3 className="text-base sm:text-lg font-bold text-ink dark:text-cream">Add Caregiver</h3>
              </div>
              <button onClick={() => setIsAddModalOpen(false)} className="text-ink-soft hover:text-ink dark:hover:text-cream transition-colors">
                <X className="w-4 h-4" />
              </button>
            </div>
            {formError && (
              <div className="p-3 rounded-lg bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{formError}</span>
              </div>
            )}
            <form onSubmit={handleCreateSubmit} className="space-y-3.5 text-xs sm:text-sm">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Full Name</label>
                <input required type="text" value={formData.name} onChange={(e) => setFormData({ ...formData, name: e.target.value })} placeholder="Dr. Sarah Jenkins" className="w-full px-3.5 py-2 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-xs sm:text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors" />
              </div>
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Email</label>
                <input required type="email" value={formData.email} onChange={(e) => setFormData({ ...formData, email: e.target.value })} placeholder="caregiver@smritikunj.org" className="w-full px-3.5 py-2 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-xs sm:text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors" />
              </div>
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Password</label>
                <input required type="password" minLength={8} value={formData.password} onChange={(e) => setFormData({ ...formData, password: e.target.value })} placeholder="Minimum 8 characters" className="w-full px-3.5 py-2 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-xs sm:text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Language</label>
                  <StyledSelect
                    value={formData.region_language}
                    onChange={(val) => setFormData({ ...formData, region_language: val })}
                    options={[
                      { value: 'en', label: 'English' },
                      { value: 'bn', label: 'Bengali' },
                      { value: 'as', label: 'Assamese' },
                      { value: 'brx', label: 'Bodo' },
                    ]}
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Status</label>
                  <StyledSelect
                    value={formData.status}
                    onChange={(val) => setFormData({ ...formData, status: val })}
                    options={[
                      { value: 'active', label: 'Active' },
                      { value: 'disabled', label: 'Disabled' },
                    ]}
                  />
                </div>
              </div>
              <div className="flex items-center justify-end gap-2 pt-3 border-t border-border/60 dark:border-ink-soft/30">
                <button type="button" onClick={() => setIsAddModalOpen(false)} className="px-4 py-2 rounded-full border border-border/80 dark:border-ink-soft/40 text-xs font-medium text-ink-soft dark:text-cream/70 hover:bg-cream dark:hover:bg-ink-soft/30 transition-colors">Cancel</button>
                <button type="submit" disabled={formSubmitting} className="px-4 py-2 rounded-full bg-terracotta hover:bg-terracotta-dark text-cream text-xs font-semibold shadow-xs transition-colors focus:outline-none focus:ring-2 focus:ring-terracotta/40">Create</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {editingCaregiver && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink/60 backdrop-blur-xs animate-in fade-in duration-150">
          <div className="w-full max-w-md bg-surface dark:bg-ink-soft/20 backdrop-blur-2xl border border-border/80 dark:border-ink-soft/40 rounded-card shadow-card p-6 sm:p-7 space-y-4">
            <div className="flex items-center justify-between border-b border-border/60 dark:border-ink-soft/30 pb-3">
              <div className="flex items-center gap-2">
                <Edit2 className="w-5 h-5 text-terracotta" />
                <h3 className="text-base sm:text-lg font-bold text-ink dark:text-cream">Edit Caregiver</h3>
              </div>
              <button onClick={() => setEditingCaregiver(null)} className="text-ink-soft hover:text-ink dark:hover:text-cream transition-colors">
                <X className="w-4 h-4" />
              </button>
            </div>
            {formError && (
              <div className="p-3 rounded-lg bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{formError}</span>
              </div>
            )}
            <form onSubmit={handleEditSubmit} className="space-y-3.5 text-xs sm:text-sm">
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Full Name</label>
                <input required type="text" value={formData.name} onChange={(e) => setFormData({ ...formData, name: e.target.value })} className="w-full px-3.5 py-2 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-xs sm:text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors" />
              </div>
              <div>
                <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Email</label>
                <input required type="email" value={formData.email} onChange={(e) => setFormData({ ...formData, email: e.target.value })} className="w-full px-3.5 py-2 rounded-lg bg-cream/70 dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-xs sm:text-sm text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-1 focus:ring-terracotta transition-colors" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Language</label>
                  <StyledSelect
                    value={formData.region_language}
                    onChange={(val) => setFormData({ ...formData, region_language: val })}
                    options={[
                      { value: 'en', label: 'English' },
                      { value: 'bn', label: 'Bengali' },
                      { value: 'as', label: 'Assamese' },
                      { value: 'brx', label: 'Bodo' },
                    ]}
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wider text-ink-soft dark:text-cream/70 mb-1">Status</label>
                  <StyledSelect
                    value={formData.status}
                    onChange={(val) => setFormData({ ...formData, status: val })}
                    options={[
                      { value: 'active', label: 'Active' },
                      { value: 'disabled', label: 'Disabled' },
                    ]}
                  />
                </div>
              </div>
              <div className="flex items-center justify-end gap-2 pt-3 border-t border-border/60 dark:border-ink-soft/30">
                <button type="button" onClick={() => setEditingCaregiver(null)} className="px-4 py-2 rounded-full border border-border/80 dark:border-ink-soft/40 text-xs font-medium text-ink-soft dark:text-cream/70 hover:bg-cream dark:hover:bg-ink-soft/30 transition-colors">Cancel</button>
                <button type="submit" disabled={formSubmitting} className="px-4 py-2 rounded-full bg-terracotta hover:bg-terracotta-dark text-cream text-xs font-semibold shadow-xs transition-colors focus:outline-none focus:ring-2 focus:ring-terracotta/40">Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {deletingCaregiver && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink/60 backdrop-blur-xs animate-in fade-in duration-150">
          <div className="w-full max-w-sm bg-surface dark:bg-ink-soft/20 backdrop-blur-2xl border border-border/80 dark:border-ink-soft/40 rounded-card shadow-card p-6 space-y-4">
            <div className="flex items-center gap-3 text-alert">
              <div className="w-10 h-10 rounded-full bg-alert/15 border border-alert/20 flex items-center justify-center shrink-0"><Trash2 className="w-5 h-5" /></div>
              <div>
                <h3 className="text-base font-bold text-ink dark:text-cream">Delete Caregiver</h3>
                <p className="text-xs text-ink-soft dark:text-cream/70">Confirm account deletion</p>
              </div>
            </div>
            {formError ? (
              <div className="p-3 rounded-lg bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2"><AlertCircle className="w-4 h-4 shrink-0" /><span>{formError}</span></div>
            ) : (
              <p className="text-xs sm:text-sm text-ink dark:text-cream/90 leading-relaxed">
                Are you sure you want to permanently delete <strong className="text-terracotta">{deletingCaregiver.name}</strong>?
              </p>
            )}
            <div className="flex items-center justify-end gap-2 pt-2 border-t border-border/60 dark:border-ink-soft/30">
              <button type="button" onClick={() => setDeletingCaregiver(null)} className="px-4 py-2 rounded-full border border-border/80 dark:border-ink-soft/40 text-xs font-medium text-ink-soft dark:text-cream/70 hover:bg-cream dark:hover:bg-ink-soft/30 transition-colors">Cancel</button>
              <button type="button" disabled={formSubmitting} onClick={handleConfirmDelete} className="px-4 py-2 rounded-full bg-alert hover:bg-alert/90 text-cream text-xs font-semibold shadow-xs transition-colors">Confirm Delete</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ManageCaregivers;