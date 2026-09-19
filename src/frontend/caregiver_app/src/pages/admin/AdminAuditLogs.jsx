import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { getAdminAuditLogs } from '../../services/adminService';
import {
  ShieldAlert,
  ArrowLeft,
  RefreshCw,
  Search,
  Filter,
  FileText,
  User,
  Key,
  Users,
  CheckCircle,
  AlertCircle,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';

export const AdminAuditLogs = () => {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [actionFilter, setActionFilter] = useState('all');
  const [expandedLogId, setExpandedLogId] = useState(null);

  const fetchLogs = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getAdminAuditLogs(100);
      setLogs(data || []);
    } catch (err) {
      setError(err?.message || 'Failed to fetch administrative audit logs.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
    document.title = 'Smriti Kunj | Admin Audit Trail';
    return () => {
      document.title = 'Smriti Kunj | Caregiver Portal';
    };
  }, []);

  const filteredLogs = useMemo(() => {
    return logs.filter((log) => {
      if (actionFilter !== 'all' && log.action !== actionFilter) {
        return false;
      }
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const matchesActor =
          log.actor_name?.toLowerCase().includes(q) ||
          log.actor_email?.toLowerCase().includes(q);
        const matchesTarget =
          log.target_name?.toLowerCase().includes(q) ||
          log.target_id?.toLowerCase().includes(q);
        const matchesAction = log.action?.toLowerCase().includes(q);
        return matchesActor || matchesTarget || matchesAction;
      }
      return true;
    });
  }, [logs, actionFilter, searchQuery]);

  const formatTimestamp = (isoStr) => {
    if (!isoStr) return '—';
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) return isoStr;
    return d.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      hour12: true,
    });
  };

  const getActionBadge = (action) => {
    switch (action) {
      case 'create_caregiver':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-sage/15 text-sage border border-sage/30">
            <User className="w-3 h-3" />
            Created Caregiver
          </span>
        );
      case 'reset_password':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-terracotta/15 text-terracotta border border-terracotta/30">
            <Key className="w-3 h-3" />
            Password Reset
          </span>
        );
      case 'assign_caregivers':
      case 'reassign_patient':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-gold/15 text-gold border border-gold/30">
            <Users className="w-3 h-3" />
            Patient Assignment
          </span>
        );
      case 'deactivate_caregiver':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-alert/15 text-alert border border-alert/30">
            <AlertCircle className="w-3 h-3" />
            Deactivated Account
          </span>
        );
      case 'activate_caregiver':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-sage/15 text-sage border border-sage/30">
            <CheckCircle className="w-3 h-3" />
            Activated Account
          </span>
        );
      default:
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-cream/70 dark:bg-ink-soft/30 text-ink-soft dark:text-cream/70 border border-border/80">
            <FileText className="w-3 h-3" />
            {action}
          </span>
        );
    }
  };

  return (
    <div className="space-y-6 sm:space-y-8 font-sans">
      {/* Header Banner */}
      <header className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-4 border-b border-border/60 dark:border-ink-soft/30 pb-4">
        <div>
          <div className="flex items-center gap-2 mb-2">
            <Link
              to="/admin/dashboard"
              className="inline-flex items-center gap-1 text-xs font-medium text-ink-soft dark:text-cream/70 hover:text-terracotta transition-colors"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>Back to Admin Dashboard</span>
            </Link>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-card bg-cream dark:bg-ink-soft/30 border border-border/80 dark:border-ink-soft/40 flex items-center justify-center text-terracotta shadow-xs">
              <ShieldAlert className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-ink dark:text-cream">
                System Audit Trail
              </h1>
              <p className="text-xs sm:text-sm text-ink-soft dark:text-cream/70 mt-0.5">
                Immutable chronological log of administrative modifications, assignments, and credential events
              </p>
            </div>
          </div>
        </div>

        <button
          type="button"
          onClick={fetchLogs}
          disabled={loading}
          className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full text-xs font-medium text-ink-soft dark:text-cream/80 hover:text-ink dark:hover:text-cream bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 hover:bg-cream dark:hover:bg-ink-soft/35 active:scale-95 transition-all self-start sm:self-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 text-terracotta ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Trail</span>
        </button>
      </header>

      {/* Filter Bar */}
      <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-ink-soft dark:text-cream/60 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by admin name, email, target, or action..."
            className="w-full pl-9 pr-4 py-2 text-xs sm:text-sm rounded-xl bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-ink dark:text-cream placeholder:text-ink-soft/60 focus:outline-none focus:ring-2 focus:ring-terracotta/40"
          />
        </div>

        <div className="flex items-center gap-2">
          <Filter className="w-4 h-4 text-ink-soft dark:text-cream/60 shrink-0" />
          <select
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
            className="text-xs sm:text-sm rounded-xl px-3 py-2 bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 text-ink dark:text-cream focus:outline-none focus:ring-2 focus:ring-terracotta/40"
          >
            <option value="all">All Actions</option>
            <option value="create_caregiver">Create Caregiver</option>
            <option value="reset_password">Reset Password</option>
            <option value="assign_caregivers">Assign Caregivers</option>
            <option value="deactivate_caregiver">Deactivate Caregiver</option>
            <option value="activate_caregiver">Activate Caregiver</option>
            <option value="reassign_patient">Reassign Patient</option>
          </select>
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-card bg-alert/10 border border-alert/30 text-alert text-xs flex items-center gap-2">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Audit Log Table */}
      <div className="rounded-card bg-surface dark:bg-ink-soft/20 border border-border/80 dark:border-ink-soft/40 shadow-sm overflow-hidden transition-colors">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs sm:text-sm">
            <thead className="bg-cream/40 dark:bg-ink-soft/30 border-b border-border/80 dark:border-ink-soft/40 text-ink-soft dark:text-cream/70 text-xs font-semibold uppercase tracking-wider">
              <tr>
                <th className="py-3 px-4">Timestamp</th>
                <th className="py-3 px-4">Admin Actor</th>
                <th className="py-3 px-4">Action</th>
                <th className="py-3 px-4">Target</th>
                <th className="py-3 px-4 text-right">Details</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60 dark:divide-ink-soft/30 text-ink dark:text-cream">
              {filteredLogs.map((log) => {
                const isExpanded = expandedLogId === log.id;
                return (
                  <React.Fragment key={log.id}>
                    <tr
                      onClick={() => setExpandedLogId(isExpanded ? null : log.id)}
                      className="hover:bg-cream/30 dark:hover:bg-ink-soft/10 cursor-pointer transition-colors"
                    >
                      <td className="py-3 px-4 text-xs font-mono text-ink-soft dark:text-cream/70 whitespace-nowrap">
                        {formatTimestamp(log.timestamp)}
                      </td>
                      <td className="py-3 px-4">
                        <div className="font-semibold text-ink dark:text-cream">
                          {log.actor_name || 'Administrator'}
                        </div>
                        <div className="text-[11px] text-ink-soft dark:text-cream/60">
                          {log.actor_email}
                        </div>
                      </td>
                      <td className="py-3 px-4 whitespace-nowrap">
                        {getActionBadge(log.action)}
                      </td>
                      <td className="py-3 px-4">
                        <div className="font-medium text-ink dark:text-cream">
                          {log.target_name || log.target_id}
                        </div>
                        <div className="text-[10px] text-ink-soft dark:text-cream/60 font-mono">
                          {log.target_type}: {log.target_id?.slice(0, 8)}...
                        </div>
                      </td>
                      <td className="py-3 px-4 text-right">
                        <button
                          type="button"
                          className="text-xs text-terracotta hover:underline inline-flex items-center gap-1"
                        >
                          <span>{isExpanded ? 'Hide' : 'Inspect'}</span>
                          {isExpanded ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                        </button>
                      </td>
                    </tr>

                    {/* Expandable JSON details row */}
                    {isExpanded && (
                      <tr className="bg-cream/20 dark:bg-ink-soft/30">
                        <td colSpan={5} className="py-3 px-6 text-xs">
                          <div className="p-3 rounded-lg bg-surface dark:bg-ink/60 border border-border/80 dark:border-ink-soft/40 font-mono text-[11px] overflow-x-auto text-ink-soft dark:text-cream/80">
                            <pre>{JSON.stringify(log.details || {}, null, 2)}</pre>
                          </div>
                        </td>
                      </tr>
                    )}
                  </React.Fragment>
                );
              })}

              {filteredLogs.length === 0 && !loading && (
                <tr>
                  <td colSpan={5} className="py-10 text-center text-ink-soft dark:text-cream/60">
                    No administrative actions matching your query found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default AdminAuditLogs;
