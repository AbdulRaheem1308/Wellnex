import React, { useState } from "react";
import { Plus } from "lucide-react";

export const OffersView: React.FC<any> = ({ offers, adViews, onToggleOffer, onCreateOffer }) => {
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ title: "", description: "", providerName: "", rewardCoins: 0, offerType: "SURVEY" });

  const handleSubmit = (e: any) => {
    e.preventDefault();
    onCreateOffer(form);
    setShowModal(false);
    setForm({ title: "", description: "", providerName: "", rewardCoins: 0, offerType: "SURVEY" });
  };

  return (
    <div className="space-y-6 animate-fade-in" style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h3 className="card-title">Offers & Monetization</h3>
        <button onClick={() => setShowModal(true)} className="btn btn-primary">
          <Plus className="w-4 h-4" />
          <span>New Offer</span>
        </button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "24px" }}>
        {/* Active Offers */}
        <div className="glass-panel" style={{ padding: "24px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "600", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "16px" }}>Monetization Offers</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
            {offers && offers.length > 0 ? offers.map((offer: any) => (
              <div key={offer.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", background: "var(--bg-surface-light)", padding: "16px", borderRadius: "8px", border: "1px solid var(--border-color)" }}>
                <div>
                  <h5 style={{ fontWeight: "600", color: "#fff", fontSize: "0.9rem" }}>{offer.title}</h5>
                  <span style={{ fontSize: "0.75rem", color: "var(--primary-light)", fontWeight: "600" }}>{offer.offerType} • {offer.rewardCoins} Coins</span>
                </div>
                <button onClick={() => onToggleOffer(offer.id)} className={`btn ${offer.isActive ? "btn-secondary" : "btn-primary"}`} style={{ padding: "6px 12px", fontSize: "0.75rem" }}>
                  {offer.isActive ? "Disable" : "Enable"}
                </button>
              </div>
            )) : (
               <div style={{ color: "var(--text-muted)", fontSize: "0.8rem", textAlign: "center", padding: "24px" }}>No offers currently configured.</div>
            )}
          </div>
        </div>

        {/* Ad Analytics */}
        <div className="glass-panel" style={{ padding: "24px" }}>
          <h4 style={{ fontSize: "0.85rem", fontWeight: "600", color: "var(--text-muted)", textTransform: "uppercase", marginBottom: "16px" }}>Recent Ad Impressions</h4>
          <div style={{ display: "flex", flexDirection: "column", gap: "8px", maxHeight: "400px", overflowY: "auto" }}>
            {adViews && adViews.length > 0 ? adViews.map((ad: any) => (
              <div key={ad.id} style={{ display: "flex", justifyContent: "space-between", padding: "12px", background: "var(--bg-surface-light)", borderRadius: "6px", border: "1px solid var(--border-color)", fontSize: "0.75rem" }}>
                <div>
                  <span style={{ color: "#fff", fontWeight: "600" }}>{ad.user?.name || "Unknown"}</span>
                  <div style={{ color: "var(--text-muted)", marginTop: "2px" }}>{ad.adType}</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <span style={{ color: "var(--primary-light)", fontWeight: "600" }}>+{ad.pointsEarned} Points</span>
                  <div style={{ color: "var(--text-muted)", marginTop: "2px" }}>{new Date(ad.completedAt).toLocaleTimeString()}</div>
                </div>
              </div>
            )) : (
               <div style={{ color: "var(--text-muted)", fontSize: "0.8rem", textAlign: "center", padding: "24px" }}>No ad impressions tracked yet.</div>
            )}
          </div>
        </div>
      </div>

      {showModal && (
        <div className="modal-backdrop">
          <div className="modal-dialog">
            <h4 className="modal-title">Create New Offer</h4>
            <form onSubmit={handleSubmit} className="modal-form">
              <input type="text" placeholder="Offer Title" required value={form.title} onChange={e => setForm({...form, title: e.target.value})} className="search-input" style={{ padding: "14px 16px" }} />
              <input type="text" placeholder="Description" required value={form.description} onChange={e => setForm({...form, description: e.target.value})} className="search-input" style={{ padding: "14px 16px" }} />
              <div style={{ display: "flex", gap: "16px" }}>
                <input type="text" placeholder="Provider (e.g. Tapjoy)" required value={form.providerName} onChange={e => setForm({...form, providerName: e.target.value})} className="search-input flex-1" style={{ padding: "14px 16px" }} />
                <input type="number" placeholder="Reward Coins" required value={form.rewardCoins} onChange={e => setForm({...form, rewardCoins: Number(e.target.value)})} className="search-input flex-1" style={{ padding: "14px 16px" }} />
              </div>
              <select value={form.offerType} onChange={e => setForm({...form, offerType: e.target.value})} className="search-input" style={{ padding: "14px 16px" }}>
                <option value="SURVEY">Survey</option>
                <option value="APP_INSTALL">App Install</option>
                <option value="VIDEO_AD">Video Ad</option>
              </select>
              <div style={{ display: "flex", gap: "12px", marginTop: "12px" }}>
                <button type="button" onClick={() => setShowModal(false)} className="btn btn-secondary flex-1" style={{ padding: "12px" }}>Cancel</button>
                <button type="submit" className="btn btn-primary flex-1" style={{ padding: "12px" }}>Publish Offer</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
