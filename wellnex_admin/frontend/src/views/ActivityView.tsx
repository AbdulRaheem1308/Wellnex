import React from "react";
import { AlertTriangle, Trash2 } from "lucide-react";

export const ActivityView: React.FC<any> = ({ activities, steps, onDeleteActivity }) => {
  return (
    <div className="space-y-6 animate-fade-in" style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h3 className="card-title">Anti-Cheat & Activity Validation</h3>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "24px" }}>
        {/* Raw Activities */}
        <div className="glass-panel" style={{ padding: "32px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "700", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "24px" }}>Flagged / Raw Activities</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "12px", maxHeight: "500px", overflowY: "auto" }}>
            {activities && activities.map((act: any) => {
              // Simple heuristic to flag
              const isFlagged = act.distanceKm > 30 || act.caloriesBurned > 1500;
              return (
                <div key={act.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", background: isFlagged ? "rgba(244,63,94,0.1)" : "var(--bg-surface-light)", padding: "16px", borderRadius: "12px", border: isFlagged ? "1px solid rgba(244,63,94,0.3)" : "1px solid var(--border-color)", transition: "all 0.2s ease" }} className="hover:border-primary">
                  <div>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                      <span style={{ fontWeight: "700", color: "#fff", fontSize: "0.9rem" }}>{act.user?.name || "Unknown"}</span>
                      {isFlagged && <AlertTriangle className="w-4 h-4 text-rose-500" />}
                    </div>
                    <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginTop: "6px" }}>
                      {act.type.toUpperCase()} • {act.durationMinutes} min • {act.distanceKm} km
                    </div>
                    <div style={{ fontSize: "0.75rem", color: "var(--accent)", marginTop: "8px", fontWeight: "700" }}>Source: {act.source}</div>
                  </div>
                  <button onClick={() => onDeleteActivity(act.id)} className="btn-icon" style={{ padding: "6px", color: "var(--error)" }}>
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              );
            })}
            {(!activities || activities.length === 0) && (
              <div style={{ color: "var(--text-muted)", fontSize: "0.85rem", textAlign: "center", padding: "24px", fontWeight: "500" }}>No activities recorded.</div>
            )}
          </div>
        </div>

        {/* Step Logs */}
        <div className="glass-panel" style={{ padding: "32px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "700", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "24px" }}>Daily Step Logs</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "8px", maxHeight: "500px", overflowY: "auto" }}>
            {steps && steps.map((s: any) => {
              const isFlagged = s.stepCount > 50000;
              return (
                <div key={s.id} style={{ display: "flex", justifyContent: "space-between", padding: "16px", background: isFlagged ? "rgba(244,63,94,0.1)" : "var(--bg-surface-light)", borderRadius: "8px", border: isFlagged ? "1px solid rgba(244,63,94,0.3)" : "1px solid var(--border-color)", fontSize: "0.8rem", transition: "all 0.2s ease" }} className="hover:border-primary">
                  <div>
                    <span style={{ color: "#fff", fontWeight: "700" }}>{s.user?.name || "Unknown"}</span>
                    <div style={{ color: "var(--text-muted)", marginTop: "4px" }}>{new Date(s.date).toLocaleDateString()}</div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <span style={{ color: isFlagged ? "var(--error)" : "var(--success)", fontWeight: "700", fontSize: "0.9rem" }}>
                      {s.stepCount.toLocaleString()} Steps
                    </span>
                    <div style={{ color: "var(--text-muted)", marginTop: "4px" }}>{s.source}</div>
                  </div>
                </div>
              );
            })}
            {(!steps || steps.length === 0) && (
              <div style={{ color: "var(--text-muted)", fontSize: "0.85rem", textAlign: "center", padding: "24px", fontWeight: "500" }}>No step logs recorded.</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
