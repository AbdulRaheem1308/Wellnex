import React from "react";
import { Search, AlertTriangle, CheckCircle, XCircle } from "lucide-react";

interface Anomaly {
  id: string;
  user: { id: string; name: string | null; email: string | null; phone: string | null };
  type: string;
  severity: string;
  description: string;
  metadata: any;
  status: string;
  createdAt: string;
}

interface AnomaliesViewProps {
  anomalies: Anomaly[];
  onUpdateStatus: (id: string, status: string) => void;
  statusFilter: string;
  setStatusFilter: (status: string) => void;
}

export const AnomaliesView: React.FC<AnomaliesViewProps> = ({
  anomalies,
  onUpdateStatus,
  statusFilter,
  setStatusFilter
}) => {
  return (
    <div className="space-y-6 animate-fade-in" style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h2 style={{ fontSize: "1.5rem", fontWeight: "700", color: "#fff", display: "flex", alignItems: "center", gap: "8px" }}>
            <AlertTriangle style={{ color: "var(--warning)" }} /> System Anomalies
          </h2>
          <p style={{ color: "var(--text-muted)", fontSize: "0.9rem", marginTop: "4px" }}>
            Monitor and resolve automated flags and user-reported tracking issues.
          </p>
        </div>
        <div style={{ display: "flex", gap: "12px" }}>
          <select 
            className="search-input" 
            style={{ width: "auto" }}
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">All Statuses</option>
            <option value="PENDING">Pending</option>
            <option value="RESOLVED">Resolved</option>
            <option value="IGNORED">Ignored</option>
          </select>
        </div>
      </div>

      <div className="glass-panel overflow-hidden" style={{ borderRadius: "12px" }}>
        <div style={{ padding: "24px", borderBottom: "1px solid var(--border-color)" }}>
          <h3 className="card-title">Anomaly Log</h3>
        </div>
        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "left" }}>
            <thead>
              <tr style={{ borderBottom: "1px solid var(--border-color)", color: "var(--text-muted)", fontSize: "0.8rem", textTransform: "uppercase", letterSpacing: "1px" }}>
                <th style={{ padding: "16px 24px", fontWeight: "600" }}>Date</th>
                <th style={{ padding: "16px 24px", fontWeight: "600" }}>User</th>
                <th style={{ padding: "16px 24px", fontWeight: "600" }}>Type / Severity</th>
                <th style={{ padding: "16px 24px", fontWeight: "600" }}>Description</th>
                <th style={{ padding: "16px 24px", fontWeight: "600" }}>Status</th>
                <th style={{ padding: "16px 24px", fontWeight: "600", textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {anomalies.map(a => (
                <tr key={a.id} style={{ borderBottom: "1px solid rgba(255,255,255,0.05)", transition: "background 0.2s" }} className="hover:bg-white/5">
                  <td style={{ padding: "16px 24px", fontSize: "0.85rem", color: "var(--text-muted)" }}>
                    {new Date(a.createdAt).toLocaleString()}
                  </td>
                  <td style={{ padding: "16px 24px" }}>
                    <div style={{ fontSize: "0.9rem", fontWeight: "500", color: "#fff" }}>{a.user.name || "Unknown"}</div>
                    <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>{a.user.phone || a.user.email}</div>
                  </td>
                  <td style={{ padding: "16px 24px" }}>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      <span className={`badge-status ${a.type === 'SYSTEM_FLAG' ? 'badge-status-inactive' : 'badge-status-active'}`} style={{ width: "fit-content" }}>
                        {a.type.replace('_', ' ')}
                      </span>
                      <span style={{ fontSize: "0.75rem", color: a.severity === 'HIGH' ? 'var(--danger)' : a.severity === 'MEDIUM' ? 'var(--warning)' : 'var(--primary-light)', fontWeight: "600" }}>
                        {a.severity} SEVERITY
                      </span>
                    </div>
                  </td>
                  <td style={{ padding: "16px 24px", fontSize: "0.85rem", color: "var(--text-main)", maxWidth: "300px" }}>
                    {a.description}
                  </td>
                  <td style={{ padding: "16px 24px" }}>
                    <span className={`badge-status ${
                      a.status === 'PENDING' ? 'badge-status-inactive' : 
                      a.status === 'RESOLVED' ? 'badge-status-active' : ''
                    }`}>
                      {a.status}
                    </span>
                  </td>
                  <td style={{ padding: "16px 24px", textAlign: "right" }}>
                    {a.status === 'PENDING' && (
                      <div style={{ display: "flex", gap: "8px", justifyContent: "flex-end" }}>
                        <button 
                          className="btn btn-primary" 
                          style={{ padding: "6px 12px", fontSize: "0.75rem", display: "flex", alignItems: "center", gap: "4px" }}
                          onClick={() => onUpdateStatus(a.id, 'RESOLVED')}
                        >
                          <CheckCircle size={14} /> Resolve
                        </button>
                        <button 
                          className="btn" 
                          style={{ padding: "6px 12px", fontSize: "0.75rem", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)", display: "flex", alignItems: "center", gap: "4px" }}
                          onClick={() => onUpdateStatus(a.id, 'IGNORED')}
                        >
                          <XCircle size={14} /> Ignore
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
              {anomalies.length === 0 && (
                <tr>
                  <td colSpan={6} style={{ padding: "48px 24px", textAlign: "center", color: "var(--text-muted)", fontSize: "0.9rem" }}>
                    No anomalies found.
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
