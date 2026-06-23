import React from "react";
import { BarChart3, Users, Trophy, Award, Gift, Compass, Activity, Zap, X, MessageSquare, Shield, Tag, DollarSign, AlertTriangle, Building2, MessageSquareOff } from "lucide-react";

interface SidebarProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
  onLogout: () => void;
  isOpen: boolean;
  onClose: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab, onLogout, isOpen, onClose }) => {
  const menuItems = [
    { id: "dashboard", label: "Overview", icon: BarChart3 },
    { id: "users", label: "User Inspector", icon: Users },
    { id: "challenges", label: "Challenges", icon: Trophy },
    { id: "achievements", label: "Achievements", icon: Award },
    { id: "rewards", label: "Rewards Catalog", icon: Gift },
    { id: "quests", label: "Quest Pipelines", icon: Compass },
    { id: "social", label: "Social Feed", icon: MessageSquare },
    { id: "teams", label: "Teams", icon: Shield },
    { id: "corporate", label: "Corporate B2B", icon: Building2 },
    { id: "offers", label: "Offers", icon: Tag },
    { id: "economy", label: "Economy", icon: DollarSign },
    { id: "activity", label: "Anti-Cheat Logs", icon: AlertTriangle },
    { id: "anomalies", label: "Anomalies", icon: AlertTriangle },
    { id: "messaging", label: "DM Compliance", icon: MessageSquareOff },
    { id: "analytics", label: "Interaction Tracking", icon: Activity }
  ];

  const handleTabClick = (tabId: string) => {
    setActiveTab(tabId);
    onClose(); // Automatically close sidebar on mobile when tab is selected
  };

  return (
    <>
      {isOpen && <div className="sidebar-backdrop" onClick={onClose} />}
      <aside className={`sidebar ${isOpen ? "sidebar-open" : ""}`}>
        <div>
          <div className="sidebar-mobile-close">
            <button onClick={onClose} className="btn-icon" title="Close menu">
              <X className="w-4 h-4 text-white" />
            </button>
          </div>
          
          <div className="sidebar-brand">
            <div className="sidebar-logo">
              <Zap className="w-5 h-5 text-white" />
            </div>
            <div>
              <span className="sidebar-title">Wellnex Admin</span>
              <div className="sidebar-subtitle">HQ Operations</div>
            </div>
          </div>

          <nav className="sidebar-menu">
            {menuItems.map(item => {
              const Icon = item.icon;
              const active = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => handleTabClick(item.id)}
                  className={`sidebar-item ${active ? "sidebar-item-active" : ""}`}
                >
                  <Icon className="w-5 h-5 shrink-0" />
                  <span>{item.label}</span>
                </button>
              );
            })}
          </nav>
        </div>

        <div className="sidebar-footer">
          <div className="status-indicator">
            <div className="status-dot"></div>
            <span>Secured Node Connected</span>
          </div>
          <button
            onClick={() => { onClose(); onLogout(); }}
            className="btn btn-danger w-full justify-center"
          >
            Lock Terminal
          </button>
        </div>
      </aside>
    </>
  );
};
