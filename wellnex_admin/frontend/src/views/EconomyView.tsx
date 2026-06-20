import React, { useState } from "react";
import { Settings, Save } from "lucide-react";

export const EconomyView: React.FC<any> = ({ transactions, appConfigs, onSaveConfig }) => {
  const [editingConfig, setEditingConfig] = useState<string | null>(null);
  const [configValue, setConfigValue] = useState<string>("");

  return (
    <div className="space-y-6 animate-fade-in" style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h3 className="card-title">Economy & Configuration</h3>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "24px" }}>
        {/* Transaction Ledger */}
        <div className="glass-panel" style={{ padding: "32px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "700", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "24px" }}>Transaction Ledger</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "12px", maxHeight: "400px", overflowY: "auto" }}>
            {transactions && transactions.length > 0 ? transactions.map((tx: any) => (
              <div key={tx.id} style={{ display: "flex", justifyContent: "space-between", padding: "16px", background: "var(--bg-surface-light)", borderRadius: "8px", border: "1px solid var(--border-color)", fontSize: "0.8rem", transition: "all 0.2s ease" }} className="hover:border-primary">
                <div>
                  <span style={{ color: "#fff", fontWeight: "700" }}>{tx.user?.name || "System"}</span>
                  <div style={{ color: "var(--text-muted)", marginTop: "4px" }}>{tx.type} • {tx.description || "No desc"}</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <span style={{ color: tx.points >= 0 ? "var(--success)" : "var(--error)", fontWeight: "700" }}>
                    {tx.points > 0 ? "+" : ""}{tx.points} PTS
                  </span>
                  <div style={{ color: "var(--text-muted)", marginTop: "4px" }}>{new Date(tx.createdAt).toLocaleDateString()}</div>
                </div>
              </div>
            )) : (
              <div style={{ color: "var(--text-muted)", fontSize: "0.85rem", textAlign: "center", padding: "24px", fontWeight: "500" }}>No transactions logged.</div>
            )}
          </div>
        </div>

        {/* App Configs */}
        <div className="glass-panel" style={{ padding: "32px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "700", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "24px" }}>Global App Configuration</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
            {appConfigs && appConfigs.map((cfg: any) => (
              <div key={cfg.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", background: "var(--bg-surface-light)", padding: "16px", borderRadius: "12px", border: "1px solid var(--border-color)", transition: "all 0.2s ease" }} className="hover:border-primary">
                <div style={{ flex: 1 }}>
                  <h5 style={{ fontWeight: "700", color: "#fff", fontSize: "0.9rem", marginBottom: "6px" }}>{cfg.key}</h5>
                  {editingConfig === cfg.key ? (
                    <div style={{ display: "flex", gap: "8px", marginTop: "12px" }}>
                      <input type="text" value={configValue} onChange={e => setConfigValue(e.target.value)} className="search-input" style={{ paddingLeft: "12px", padding: "10px", width: "100%" }} />
                      <button onClick={() => { onSaveConfig(cfg.key, configValue); setEditingConfig(null); }} className="btn btn-primary" style={{ padding: "10px" }}><Save className="w-4 h-4" /></button>
                    </div>
                  ) : (
                    <div style={{ fontSize: "0.8rem", color: "var(--primary-light)", fontFamily: "monospace", fontWeight: "700", letterSpacing: "0.5px" }}>{cfg.value}</div>
                  )}
                </div>
                {editingConfig !== cfg.key && (
                  <button onClick={() => { setEditingConfig(cfg.key); setConfigValue(cfg.value); }} className="btn-icon" style={{ padding: "8px" }}><Settings className="w-4 h-4" /></button>
                )}
              </div>
            ))}
            
            <div style={{ borderTop: "1px solid var(--border-color)", paddingTop: "24px", marginTop: "16px" }}>
              <h5 style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginBottom: "16px", fontWeight: "700" }}>ADD NEW CONFIG</h5>
              <div style={{ display: "flex", gap: "12px" }}>
                <input type="text" placeholder="Key" id="newConfigKey" className="search-input w-1/3" style={{ paddingLeft: "16px", padding: "12px" }} />
                <input type="text" placeholder="Value" id="newConfigValue" className="search-input flex-1" style={{ paddingLeft: "16px", padding: "12px" }} />
                <button onClick={() => {
                  const key = (document.getElementById("newConfigKey") as HTMLInputElement).value;
                  const val = (document.getElementById("newConfigValue") as HTMLInputElement).value;
                  if (key && val) {
                    onSaveConfig(key, val);
                    (document.getElementById("newConfigKey") as HTMLInputElement).value = "";
                    (document.getElementById("newConfigValue") as HTMLInputElement).value = "";
                  }
                }} className="btn btn-primary" style={{ padding: "12px 24px" }}>Add</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
