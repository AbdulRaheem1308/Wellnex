import React, { useState } from "react";
import { Trash2, Plus } from "lucide-react";

export const SocialView: React.FC<any> = ({ feedPosts, invitations, onDeletePost, onCreatePost }) => {
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ content: "", imageUrl: "" });

  const handleSubmit = (e: any) => {
    e.preventDefault();
    onCreatePost(form.content, form.imageUrl);
    setShowModal(false);
    setForm({ content: "", imageUrl: "" });
  };

  return (
    <div className="space-y-6 animate-fade-in" style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h3 className="card-title">Social Feed & Community</h3>
        <button onClick={() => setShowModal(true)} className="btn btn-primary">
          <Plus className="w-4 h-4" />
          <span>New System Post</span>
        </button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr", gap: "24px" }}>
        {/* Feed Posts */}
        <div className="glass-panel" style={{ padding: "24px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "600", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "16px" }}>Recent Feed Activity</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
            {feedPosts && feedPosts.length > 0 ? feedPosts.map((post: any) => (
              <div key={post.id} style={{ display: "flex", alignItems: "flex-start", gap: "16px", background: "var(--bg-surface-light)", padding: "16px", borderRadius: "8px", border: "1px solid var(--border-color)" }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span style={{ fontWeight: "600", fontSize: "0.85rem", color: "#fff" }}>{post.user?.name || "System"}</span>
                    <span style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>{new Date(post.createdAt).toLocaleDateString()}</span>
                  </div>
                  <p style={{ fontSize: "0.85rem", color: "var(--text-muted)" }}>{post.content}</p>
                  <div style={{ display: "flex", gap: "12px", marginTop: "12px", fontSize: "0.75rem", color: "var(--primary-light)", fontWeight: "600" }}>
                    <span>Likes: {post._count?.reactions || 0}</span>
                    <span>Comments: {post._count?.comments || 0}</span>
                  </div>
                </div>
                <button onClick={() => onDeletePost(post.id)} className="btn-icon" style={{ padding: "6px", color: "var(--error)" }}>
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            )) : (
              <div style={{ color: "var(--text-muted)", fontSize: "0.8rem", textAlign: "center", padding: "24px" }}>No recent posts found.</div>
            )}
          </div>
        </div>

        {/* Invitations */}
        <div className="glass-panel" style={{ padding: "24px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "600", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "16px" }}>Recent Invitations</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
            {invitations && invitations.length > 0 ? invitations.map((inv: any) => (
              <div key={inv.id} style={{ padding: "12px", background: "var(--bg-surface-light)", borderRadius: "6px", border: "1px solid var(--border-color)", fontSize: "0.75rem" }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "4px" }}>
                  <span style={{ color: "#fff", fontWeight: "600" }}>Code: {inv.referralCode}</span>
                  <span style={{ color: inv.status === "ACCEPTED" ? "var(--success)" : "var(--primary-light)", fontWeight: "600" }}>{inv.status}</span>
                </div>
                <div style={{ color: "var(--text-muted)" }}>{new Date(inv.sentAt).toLocaleDateString()}</div>
              </div>
            )) : (
              <div style={{ color: "var(--text-muted)", fontSize: "0.8rem", textAlign: "center" }}>No invitations logged.</div>
            )}
          </div>
        </div>
      </div>

      {showModal && (
        <div className="modal-backdrop">
          <div className="modal-dialog">
            <h4 className="modal-title">Create System Post</h4>
            <form onSubmit={handleSubmit} className="modal-form">
              <textarea placeholder="Post content..." required value={form.content} onChange={e => setForm({...form, content: e.target.value})} className="search-input" style={{ padding: "16px", minHeight: "120px", resize: "none" }} />
              <input type="text" placeholder="Image URL (Optional)" value={form.imageUrl} onChange={e => setForm({...form, imageUrl: e.target.value})} className="search-input" style={{ padding: "14px 16px" }} />
              <div style={{ display: "flex", gap: "12px", marginTop: "12px" }}>
                <button type="button" onClick={() => setShowModal(false)} className="btn btn-secondary flex-1" style={{ padding: "12px" }}>Cancel</button>
                <button type="submit" className="btn btn-primary flex-1" style={{ padding: "12px" }}>Publish Post</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
