import React, { useState } from "react";
import { Shield, Key, AlertTriangle } from "lucide-react";
import { apiFetch } from "../services/api";

interface LoginViewProps {
  apiKey: string;
  setApiKey: (key: string) => void;
  onLoginSuccess: () => void;
}

export const LoginView: React.FC<LoginViewProps> = ({ apiKey, setApiKey, onLoginSuccess }) => {
  const [authError, setAuthError] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!apiKey) {
      setAuthError("API Key is required.");
      return;
    }

    setLoading(true);
    setAuthError("");

    try {
      setApiKey(apiKey);
      const res = await apiFetch("/analytics/summary");
      if (res.success) {
        onLoginSuccess();
      } else {
        setAuthError("Access Denied. Invalid Admin API Key.");
      }
    } catch (err: any) {
      setAuthError(err.message || "Failed to connect to backend server.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#05070c] relative overflow-hidden" style={{
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      minHeight: "100vh",
      width: "100vw",
      backgroundImage: "radial-gradient(circle at center, rgba(139, 92, 246, 0.15) 0%, transparent 60%)"
    }}>
      <div className="glass-panel max-w-md w-full p-8 text-center animate-fade-in relative z-10" style={{
        boxShadow: "0 20px 40px rgba(0, 0, 0, 0.7), 0 0 30px rgba(139, 92, 246, 0.1)",
        maxWidth: "420px",
        padding: "40px",
        textAlign: "center"
      }}>
        <div style={{
          width: "64px",
          height: "64px",
          borderRadius: "16px",
          background: "linear-gradient(135deg, var(--primary), var(--accent))",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          margin: "0 auto 24px auto",
          boxShadow: "0 4px 20px rgba(147, 51, 234, 0.3)"
        }}>
          <Shield className="w-8 h-8 text-white" />
        </div>
        
        <h1 style={{
          fontSize: "1.75rem",
          fontWeight: 900,
          letterSpacing: "-0.5px",
          marginBottom: "8px",
          background: "linear-gradient(90deg, #ffffff, #c084fc)",
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent"
        }}>
          Wellnex Console
        </h1>
        <p style={{
          fontSize: "0.8rem",
          color: "var(--text-muted)",
          marginBottom: "32px",
          fontWeight: 600
        }}>
          Enter your Secure Cryptographic Admin Token
        </p>

        <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          <div style={{ position: "relative" }}>
            <Key className="absolute left-4 top-1/2 transform -translate-y-1/2 text-slate-400 w-5 h-5" style={{
              position: "absolute",
              left: "16px",
              top: "50%",
              transform: "translateY(-50%)",
              color: "var(--text-muted)"
            }} />
            <input
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder="Secure API Token..."
              className="search-input"
              style={{ paddingLeft: "48px", fontFamily: "monospace" }}
            />
          </div>
          
          {authError && (
            <div style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              color: "var(--error)",
              fontSize: "0.75rem",
              background: "rgba(244, 63, 94, 0.08)",
              border: "1px solid rgba(244, 63, 94, 0.15)",
              padding: "12px",
              borderRadius: "10px",
              textAlign: "left"
            }}>
              <AlertTriangle className="w-4 h-4 shrink-0" />
              <span>{authError}</span>
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="btn btn-primary"
            style={{ width: "100%", padding: "14px", justifyContent: "center", textTransform: "uppercase" }}
          >
            {loading ? "Decrypting..." : "Unlock Console"}
          </button>
        </form>
        
        <div style={{
          marginTop: "32px",
          fontSize: "11px",
          color: "var(--text-muted)",
          borderTop: "1px solid var(--border-color)",
          paddingTop: "16px"
        }}>
          Use the administrator access key provided through your secure team channel.
        </div>
      </div>
    </div>
  );
};
