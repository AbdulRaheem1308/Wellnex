import React from "react";
import { MessageSquareOff, User } from "lucide-react";

export const MessagingView: React.FC<any> = ({ conversations, onDeleteConversation }) => {
  return (
    <div className="space-y-6 animate-fade-in" style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h3 className="card-title">Direct Messaging Compliance Review</h3>
      </div>

      <div className="glass-panel" style={{ padding: "32px" }}>
        <h4 style={{ fontSize: "0.85rem", fontWeight: "700", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "24px" }}>Flagged / Active Conversations</h4>
        <div style={{ display: "flex", flexDirection: "column", gap: "12px", maxHeight: "600px", overflowY: "auto" }}>
          {conversations && conversations.length > 0 ? conversations.map((conv: any) => (
            <div key={conv.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", background: "var(--bg-surface-light)", padding: "20px", borderRadius: "12px", border: "1px solid var(--border-color)", transition: "all 0.2s ease" }} className="hover:border-primary">
              <div style={{ flex: 1 }}>
                <div style={{ display: "flex", gap: "12px", marginBottom: "12px" }}>
                  {conv.participants?.map((p: any) => (
                    <div key={p.id} style={{ display: "flex", alignItems: "center", gap: "6px", background: "var(--bg-surface)", padding: "6px 10px", borderRadius: "100px", fontSize: "0.75rem", color: "#fff", fontWeight: "600", border: "1px solid var(--border-color)" }}>
                      <User className="w-3.5 h-3.5 text-primary" />
                      {p.user?.name || "Unknown"}
                    </div>
                  ))}
                </div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", fontWeight: "500" }}>
                  Total Messages: <strong style={{ color: "var(--primary-light)", fontWeight: "700" }}>{conv._count?.messages || 0}</strong> • Last active: {new Date(conv.updatedAt).toLocaleDateString()}
                </div>
              </div>
              <button onClick={() => onDeleteConversation(conv.id)} className="btn btn-secondary" style={{ color: "var(--error)" }}>
                <MessageSquareOff className="w-4 h-4 mr-2" /> Wipe Thread
              </button>
            </div>
          )) : (
            <div style={{ color: "var(--text-muted)", fontSize: "0.85rem", textAlign: "center", padding: "48px", fontWeight: "500" }}>No active conversations available for review.</div>
          )}
        </div>
      </div>
    </div>
  );
};
