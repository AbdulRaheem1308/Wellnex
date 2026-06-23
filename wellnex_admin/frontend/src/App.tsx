import React, { useState, useEffect } from "react";
import { Sidebar } from "./components/Sidebar";
import { Header } from "./components/Header";
import { Toast } from "./components/Toast";
import { Modal } from "./components/Modal";

// Views
import { LoginView } from "./views/LoginView";
import { DashboardView } from "./views/DashboardView";
import { UsersView } from "./views/UsersView";
import { ChallengesView } from "./views/ChallengesView";
import { AchievementsView } from "./views/AchievementsView";
import { RewardsView } from "./views/RewardsView";
import { QuestsView } from "./views/QuestsView";
import { AnalyticsView } from "./views/AnalyticsView";
import { SocialView } from "./views/SocialView";
import { TeamsView } from "./views/TeamsView";
import { OffersView } from "./views/OffersView";
import { EconomyView } from "./views/EconomyView";
import { ActivityView } from "./views/ActivityView";
import { CorporateView } from "./views/CorporateView";
import { MessagingView } from "./views/MessagingView";
import { AnomaliesView } from "./views/AnomaliesView";

// API
import { getApiKey, setApiKey, clearApiKey, apiFetch } from "./services/api";

interface User {
  id: string;
  name: string | null;
  email: string | null;
  phone: string | null;
  isActive: boolean;
  dailyStepGoal: number;
  fitnessLevel: string | null;
  createdAt: string;
  streak?: { currentStreak: number; longestStreak: number };
  wallet?: { balance: number; lifetimePoints: number };
  _count?: { steps: number; userChallenges: number; userAchievements: number };
}

interface Challenge {
  id: string;
  title: string;
  description: string;
  stepTarget: number;
  rewardCoins: number;
  rewardXp: number;
  durationDays: number;
  challengeType: string;
  difficulty: string;
  imageUrl: string | null;
  isActive: boolean;
}

interface Achievement {
  id: string;
  code: string;
  name: string;
  description: string;
  icon: string;
  category: string;
  pointsReward: number;
  stepsRequired: number | null;
  streakRequired: number | null;
  targetValue: number | null;
  isActive: boolean;
}

interface Reward {
  id: string;
  title: string;
  description: string;
  coinCost: number;
  category: string;
  imageUrl: string | null;
  partnerName: string | null;
  partnerLogoUrl: string | null;
  availableStock: number;
  totalStock: number;
  isActive: boolean;
}

interface Quest {
  id: string;
  title: string;
  description: string;
  imageUrl: string;
  difficulty: string;
  rewardXp: number;
  rewardCoins: number;
  isActive: boolean;
  stages?: QuestStage[];
}

interface QuestStage {
  id: string;
  order: number;
  title: string;
  description: string;
  targetSteps: number;
}

export default function App() {
  const [apiKey, setApiKeyState] = useState<string>(getApiKey());
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [activeTab, setActiveTab] = useState<string>("dashboard");
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);
  const [isSidebarOpen, setIsSidebarOpen] = useState<boolean>(false);

  const handleSetApiKey = (key: string) => {
    setApiKey(key);
    setApiKeyState(key);
  };

  // System States
  const [summary, setSummary] = useState<any>(null);
  const [interactions, setInteractions] = useState<any>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [challenges, setChallenges] = useState<Challenge[]>([]);
  const [achievements, setAchievements] = useState<Achievement[]>([]);
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [quests, setQuests] = useState<Quest[]>([]);
  const [feedPosts, setFeedPosts] = useState<any[]>([]);
  const [invitations, setInvitations] = useState<any[]>([]);
  const [teams, setTeams] = useState<any[]>([]);
  const [battles, setBattles] = useState<any[]>([]);
  const [offers, setOffers] = useState<any[]>([]);
  const [adViews, setAdViews] = useState<any[]>([]);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [appConfigs, setAppConfigs] = useState<any[]>([]);
  const [activities, setActivities] = useState<any[]>([]);
  const [steps, setSteps] = useState<any[]>([]);
  const [companies, setCompanies] = useState<any[]>([]);
  const [conversations, setConversations] = useState<any[]>([]);
  const [anomalies, setAnomalies] = useState<any[]>([]);
  const [anomaliesStatusFilter, setAnomaliesStatusFilter] = useState<string>("");

  // Search & Profile Inspectors
  const [userSearch, setUserSearch] = useState<string>("");
  const [selectedUser, setSelectedUser] = useState<any>(null);

  // Modals Forms Config
  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);
  const [modalType, setModalType] = useState<"challenge" | "achievement" | "reward" | "quest" | "stage" | null>(null);
  const [editingItem, setEditingItem] = useState<any>(null);
  const [selectedQuestId, setSelectedQuestId] = useState<string>("");

  // Forms Fields State
  const [challengeForm, setChallengeForm] = useState({
    title: "", description: "", stepTarget: 10000, rewardCoins: 100, rewardXp: 150,
    durationDays: 7, challengeType: "SOLO", difficulty: "MEDIUM", imageUrl: "", isActive: true
  });
  const [achievementForm, setAchievementForm] = useState({
    code: "", name: "", description: "", icon: "trophy", category: "STEPS",
    pointsReward: 50, stepsRequired: "" as any, streakRequired: "" as any, targetValue: "" as any, isActive: true
  });
  const [rewardForm, setRewardForm] = useState({
    title: "", description: "", coinCost: 200, category: "FITNESS", imageUrl: "",
    partnerName: "", partnerLogoUrl: "", availableStock: 100, totalStock: 100, isActive: true
  });
  const [questForm, setQuestForm] = useState({
    title: "", description: "", imageUrl: "", difficulty: "MEDIUM", rewardXp: 200, rewardCoins: 150, isActive: true
  });
  const [stageForm, setStageForm] = useState({
    order: 1, title: "", description: "", targetSteps: 5000
  });

  const showToast = (message: string, type: "success" | "error" = "success") => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3500);
  };

  const handleLoginSuccess = () => {
    setIsAuthenticated(true);
    fetchInitialData();
  };

  const handleLogout = () => {
    clearApiKey();
    setApiKeyState("");
    setIsAuthenticated(false);
  };

  // Central fetch dispatcher
  const fetchInitialData = () => {
    fetchSummary();
    fetchInteractions();
    fetchUsers();
    fetchChallenges();
    fetchAchievements();
    fetchRewards();
    fetchQuests();
    fetchSocial();
    fetchTeams();
    fetchOffers();
    fetchEconomy();
    fetchActivity();
    fetchCorporate();
    fetchMessaging();
    fetchAnomalies();
  };

  const fetchAnomalies = () => {
    let url = "/anomalies?limit=50";
    if (anomaliesStatusFilter) url += `&status=${anomaliesStatusFilter}`;
    apiFetch(url)
      .then(d => { if (d.success) setAnomalies(d.data); })
      .catch(() => {});
  };

  const fetchSummary = () => {
    apiFetch("/analytics/summary")
      .then(d => { if (d.success) setSummary(d.data); })
      .catch(() => {});
  };

  const fetchInteractions = () => {
    apiFetch("/analytics/interactions")
      .then(d => { if (d.success) setInteractions(d.data); })
      .catch(() => {});
  };

  const fetchUsers = () => {
    apiFetch(`/users?search=${userSearch}`)
      .then(d => { if (d.success) setUsers(d.data); })
      .catch(() => {});
  };

  const fetchChallenges = () => {
    apiFetch("/challenges")
      .then(d => { if (d.success) setChallenges(d.data); })
      .catch(() => {});
  };

  const fetchAchievements = () => {
    apiFetch("/achievements")
      .then(d => { if (d.success) setAchievements(d.data); })
      .catch(() => {});
  };

  const fetchRewards = () => {
    apiFetch("/rewards")
      .then(d => { if (d.success) setRewards(d.data); })
      .catch(() => {});
  };

  const fetchQuests = () => {
    apiFetch("/quests")
      .then(d => { if (d.success) setQuests(d.data); })
      .catch(() => {});
  };

  const fetchSocial = () => {
    apiFetch("/social/feed").then(d => { if (d.success) setFeedPosts(d.data); }).catch(() => {});
    apiFetch("/social/invitations").then(d => { if (d.success) setInvitations(d.data); }).catch(() => {});
  };

  const fetchTeams = () => {
    apiFetch("/teams").then(d => { if (d.success) setTeams(d.data); }).catch(() => {});
    apiFetch("/teams/battles").then(d => { if (d.success) setBattles(d.data); }).catch(() => {});
  };

  const fetchOffers = () => {
    apiFetch("/offers").then(d => { if (d.success) setOffers(d.data); }).catch(() => {});
    apiFetch("/offers/ad-views").then(d => { if (d.success) setAdViews(d.data); }).catch(() => {});
  };

  const fetchEconomy = () => {
    apiFetch("/economy/transactions").then(d => { if (d.success) setTransactions(d.data); }).catch(() => {});
    apiFetch("/economy/config").then(d => { if (d.success) setAppConfigs(d.data); }).catch(() => {});
  };

  const fetchActivity = () => {
    apiFetch("/activities").then(d => { if (d.success) setActivities(d.data); }).catch(() => {});
    apiFetch("/activities/steps").then(d => { if (d.success) setSteps(d.data); }).catch(() => {});
  };

  const fetchCorporate = () => {
    apiFetch("/corporate").then(d => { if (d.success) setCompanies(d.data); }).catch(() => {});
  };

  const fetchMessaging = () => {
    apiFetch("/messaging").then(d => { if (d.success) setConversations(d.data); }).catch(() => {});
  };

  useEffect(() => {
    if (apiKey) {
      setIsAuthenticated(true);
      fetchInitialData();
    }
  }, []);

  useEffect(() => {
    if (isAuthenticated) {
      fetchUsers();
    }
  }, [userSearch]);

  useEffect(() => {
    if (isAuthenticated) fetchAnomalies();
  }, [anomaliesStatusFilter]);

  const handleSelectUser = async (userId: string) => {
    try {
      const data = await apiFetch(`/users/${userId}`);
      if (data.success) {
        setSelectedUser(data.data);
      }
    } catch (err) {
      showToast("Failed to fetch detailed profile logs.", "error");
    }
  };

  const handleToggleUserStatus = async (userId: string) => {
    try {
      const data = await apiFetch(`/users/${userId}/toggle-status`, { method: "PUT" });
      if (data.success) {
        showToast(data.message);
        fetchUsers();
        if (selectedUser?.id === userId) {
          handleSelectUser(userId);
        }
      }
    } catch (err) {
      showToast("Communication error.", "error");
    }
  };

  // CRUD Save Functions
  const handleSaveChallenge = async (e: React.FormEvent) => {
    e.preventDefault();
    const method = editingItem ? "PUT" : "POST";
    const endpoint = editingItem ? `/challenges/${editingItem.id}` : "/challenges";

    try {
      const data = await apiFetch(endpoint, {
        method,
        body: JSON.stringify(challengeForm)
      });
      if (data.success) {
        showToast(`Challenge successfully ${editingItem ? "updated" : "created"}.`);
        fetchChallenges();
        fetchSummary();
        setIsModalOpen(false);
        setEditingItem(null);
      }
    } catch (err: any) {
      showToast(err.message || "Failed to save challenge config.", "error");
    }
  };

  const handleDeleteChallenge = async (id: string) => {
    if (!confirm("Are you sure you want to delete this challenge?")) return;
    try {
      const data = await apiFetch(`/challenges/${id}`, { method: "DELETE" });
      if (data.success) {
        showToast("Challenge deleted.");
        fetchChallenges();
        fetchSummary();
      }
    } catch (err) {
      showToast("Failed to delete challenge.", "error");
    }
  };

  const handleSaveAchievement = async (e: React.FormEvent) => {
    e.preventDefault();
    const method = editingItem ? "PUT" : "POST";
    const endpoint = editingItem ? `/achievements/${editingItem.id}` : "/achievements";

    const body = {
      ...achievementForm,
      stepsRequired: achievementForm.stepsRequired ? Number(achievementForm.stepsRequired) : null,
      streakRequired: achievementForm.streakRequired ? Number(achievementForm.streakRequired) : null,
      targetValue: achievementForm.targetValue ? Number(achievementForm.targetValue) : null
    };

    try {
      const data = await apiFetch(endpoint, {
        method,
        body: JSON.stringify(body)
      });
      if (data.success) {
        showToast(`Achievement badge ${editingItem ? "updated" : "created"}.`);
        fetchAchievements();
        setIsModalOpen(false);
        setEditingItem(null);
      }
    } catch (err: any) {
      showToast(err.message || "Failed to save achievement badge.", "error");
    }
  };

  const handleDeleteAchievement = async (id: string) => {
    if (!confirm("Are you sure you want to delete this badge?")) return;
    try {
      const data = await apiFetch(`/achievements/${id}`, { method: "DELETE" });
      if (data.success) {
        showToast("Badge configuration deleted.");
        fetchAchievements();
      }
    } catch (err) {
      showToast("Failed to delete achievement.", "error");
    }
  };

  const handleSaveReward = async (e: React.FormEvent) => {
    e.preventDefault();
    const method = editingItem ? "PUT" : "POST";
    const endpoint = editingItem ? `/rewards/${editingItem.id}` : "/rewards";

    try {
      const data = await apiFetch(endpoint, {
        method,
        body: JSON.stringify(rewardForm)
      });
      if (data.success) {
        showToast(`Reward catalog item ${editingItem ? "updated" : "created"}.`);
        fetchRewards();
        setIsModalOpen(false);
        setEditingItem(null);
      }
    } catch (err: any) {
      showToast(err.message || "Failed to save reward item.", "error");
    }
  };

  const handleDeleteReward = async (id: string) => {
    if (!confirm("Are you sure you want to delete this catalog reward?")) return;
    try {
      const data = await apiFetch(`/rewards/${id}`, { method: "DELETE" });
      if (data.success) {
        showToast("Catalog reward removed.");
        fetchRewards();
      }
    } catch (err) {
      showToast("Failed to delete reward.", "error");
    }
  };

  const handleSaveQuest = async (e: React.FormEvent) => {
    e.preventDefault();
    const method = editingItem ? "PUT" : "POST";
    const endpoint = editingItem ? `/quests/${editingItem.id}` : "/quests";

    try {
      const data = await apiFetch(endpoint, {
        method,
        body: JSON.stringify(questForm)
      });
      if (data.success) {
        showToast(`Quest chain ${editingItem ? "updated" : "created"}.`);
        fetchQuests();
        setIsModalOpen(false);
        setEditingItem(null);
      }
    } catch (err: any) {
      showToast(err.message || "Failed to save quest.", "error");
    }
  };

  const handleDeleteQuest = async (id: string) => {
    if (!confirm("Are you sure you want to delete this quest chain?")) return;
    try {
      const data = await apiFetch(`/quests/${id}`, { method: "DELETE" });
      if (data.success) {
        showToast("Quest deleted.");
        fetchQuests();
      }
    } catch (err) {
      showToast("Failed to delete quest.", "error");
    }
  };

  const handleSaveStage = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const data = await apiFetch(`/quests/${selectedQuestId}/stages`, {
        method: "POST",
        body: JSON.stringify(stageForm)
      });
      if (data.success) {
        showToast("Quest pipeline stage added.");
        fetchQuests();
        setIsModalOpen(false);
      }
    } catch (err) {
      showToast("Failed to add quest stage.", "error");
    }
  };

  const handleDeleteStage = async (stageId: string) => {
    if (!confirm("Delete this stage?")) return;
    try {
      const data = await apiFetch(`/stages/${stageId}`, { method: "DELETE" });
      if (data.success) {
        showToast("Stage removed.");
        fetchQuests();
      }
    } catch (err) {
      showToast("Failed to delete stage.", "error");
    }
  };

  const handleDeletePost = async (id: string) => {
    if (!confirm("Delete this feed post?")) return;
    try {
      await apiFetch(`/social/feed/${id}`, { method: "DELETE" });
      showToast("Post deleted.");
      fetchSocial();
    } catch (err) {}
  };

  const handleDeleteTeam = async (id: string) => {
    if (!confirm("Disband this team?")) return;
    try {
      await apiFetch(`/teams/${id}`, { method: "DELETE" });
      showToast("Team disbanded.");
      fetchTeams();
    } catch (err) {}
  };

  const handleToggleOffer = async (id: string) => {
    try {
      await apiFetch(`/offers/${id}/toggle`, { method: "PATCH" });
      showToast("Offer status toggled.");
      fetchOffers();
    } catch (err) {}
  };

  const handleSaveConfig = async (key: string, value: string) => {
    try {
      await apiFetch(`/economy/config`, { method: "POST", body: JSON.stringify({ key, value }) });
      showToast("Configuration saved.");
      fetchEconomy();
    } catch (err) {}
  };

  const handleDeleteActivity = async (id: string) => {
    if (!confirm("Delete this flagged activity?")) return;
    try {
      await apiFetch(`/activities/${id}`, { method: "DELETE" });
      showToast("Activity removed.");
      fetchActivity();
    } catch (err) {}
  };

  const handleCreateCompany = async (name: string, domain: string) => {
    try {
      await apiFetch("/corporate", { method: "POST", body: JSON.stringify({ name, domain }) });
      showToast("Enterprise onboarded.");
      fetchCorporate();
    } catch (err) {}
  };

  const handleCreateOffer = async (data: any) => {
    try {
      await apiFetch("/offers", { method: "POST", body: JSON.stringify(data) });
      showToast("Offer published successfully.");
      fetchOffers();
    } catch (err) {}
  };

  const handleCreatePost = async (content: string, imageUrl: string) => {
    try {
      await apiFetch("/social/feed", { method: "POST", body: JSON.stringify({ content, imageUrl }) });
      showToast("Post published to feed.");
      fetchSocial();
    } catch (err) {}
  };

  const handleCreateTeam = async (name: string, isPrivate: boolean) => {
    try {
      await apiFetch("/teams", { method: "POST", body: JSON.stringify({ name, isPrivate }) });
      showToast("Team created.");
      fetchTeams();
    } catch (err) {}
  };

  const handleDeleteCompany = async (id: string) => {
    if (!confirm("Revoke this enterprise license?")) return;
    try {
      await apiFetch(`/corporate/${id}`, { method: "DELETE" });
      showToast("License revoked.");
      fetchCorporate();
    } catch (err) {}
  };

  const handleDeleteConversation = async (id: string) => {
    if (!confirm("Wipe this conversation?")) return;
    try {
      await apiFetch(`/messaging/${id}`, { method: "DELETE" });
      showToast("Conversation wiped.");
      fetchMessaging();
    } catch (err) {}
  };

  const handleUpdateAnomalyStatus = async (id: string, status: string) => {
    try {
      await apiFetch(`/anomalies/${id}/status`, { 
        method: "PATCH", 
        body: JSON.stringify({ status }) 
      });
      showToast("Anomaly status updated.");
      fetchAnomalies();
    } catch (err) {}
  };

  // Dialog triggers
  const openModal = (type: "challenge" | "achievement" | "reward" | "quest" | "stage", item: any = null, questId: string = "") => {
    setModalType(type);
    setEditingItem(item);
    setSelectedQuestId(questId);
    
    if (type === "challenge") {
      setChallengeForm(item ? {
        title: item.title, description: item.description, stepTarget: item.stepTarget,
        rewardCoins: item.rewardCoins, rewardXp: item.rewardXp, durationDays: item.durationDays,
        challengeType: item.challengeType, difficulty: item.difficulty, imageUrl: item.imageUrl || "", isActive: item.isActive
      } : {
        title: "", description: "", stepTarget: 10000, rewardCoins: 100, rewardXp: 150,
        durationDays: 7, challengeType: "SOLO", difficulty: "MEDIUM", imageUrl: "", isActive: true
      });
    } else if (type === "achievement") {
      setAchievementForm(item ? {
        code: item.code, name: item.name, description: item.description, icon: item.icon,
        category: item.category, pointsReward: item.pointsReward, stepsRequired: item.stepsRequired || "",
        streakRequired: item.streakRequired || "", targetValue: item.targetValue || "", isActive: item.isActive
      } : {
        code: "", name: "", description: "", icon: "trophy", category: "STEPS",
        pointsReward: 50, stepsRequired: "", streakRequired: "", targetValue: "", isActive: true
      });
    } else if (type === "reward") {
      setRewardForm(item ? {
        title: item.title, description: item.description, coinCost: item.coinCost, category: item.category,
        imageUrl: item.imageUrl || "", partnerName: item.partnerName || "", partnerLogoUrl: item.partnerLogoUrl || "",
        availableStock: item.availableStock, totalStock: item.totalStock, isActive: item.isActive
      } : {
        title: "", description: "", coinCost: 200, category: "FITNESS", imageUrl: "",
        partnerName: "", partnerLogoUrl: "", availableStock: 100, totalStock: 100, isActive: true
      });
    } else if (type === "quest") {
      setQuestForm(item ? {
        title: item.title, description: item.description, imageUrl: item.imageUrl, difficulty: item.difficulty,
        rewardXp: item.rewardXp, rewardCoins: item.rewardCoins, isActive: item.isActive
      } : {
        title: "", description: "", imageUrl: "", difficulty: "MEDIUM", rewardXp: 200, rewardCoins: 150, isActive: true
      });
    } else if (type === "stage") {
      setStageForm({
        order: 1, title: "", description: "", targetSteps: 5000
      });
    }

    setIsModalOpen(true);
  };

  if (!isAuthenticated) {
    return (
      <LoginView 
        apiKey={apiKey} 
        setApiKey={handleSetApiKey} 
        onLoginSuccess={handleLoginSuccess} 
      />
    );
  }

  return (
    <div className="min-h-screen flex bg-[#06080e] text-[#f3f4f6] admin-layout">
      {/* Toast Notification */}
      <Toast toast={toast} />

      {/* Sidebar navigation layout */}
      <Sidebar 
        activeTab={activeTab} 
        setActiveTab={setActiveTab} 
        onLogout={handleLogout}
        isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)}
      />

      {/* Main panel layout */}
      <main className="flex-1 flex flex-col min-h-screen bg-[#07090e] overflow-y-auto main-panel">
        <Header 
          activeTab={activeTab} 
          apiKey={apiKey} 
          onRefresh={fetchInitialData}
          onMenuToggle={() => setIsSidebarOpen(!isSidebarOpen)}
        />

        <div className="content-area">
          {activeTab === "dashboard" && (
            <DashboardView 
              summary={summary} 
              onNavigateToAnalytics={() => setActiveTab("analytics")} 
            />
          )}

          {activeTab === "users" && (
            <UsersView 
              users={users} 
              selectedUser={selectedUser} 
              userSearch={userSearch} 
              setUserSearch={setUserSearch} 
              onSelectUser={handleSelectUser} 
              onToggleStatus={handleToggleUserStatus} 
            />
          )}

          {activeTab === "challenges" && (
            <ChallengesView 
              challenges={challenges} 
              onOpenCreateModal={() => openModal("challenge")} 
              onOpenEditModal={(c) => openModal("challenge", c)} 
              onDeleteChallenge={handleDeleteChallenge} 
            />
          )}

          {activeTab === "achievements" && (
            <AchievementsView 
              achievements={achievements} 
              onOpenCreateModal={() => openModal("achievement")} 
              onOpenEditModal={(a) => openModal("achievement", a)} 
              onDeleteAchievement={handleDeleteAchievement} 
            />
          )}

          {activeTab === "rewards" && (
            <RewardsView 
              rewards={rewards} 
              onOpenCreateModal={() => openModal("reward")} 
              onOpenEditModal={(r) => openModal("reward", r)} 
              onDeleteReward={handleDeleteReward} 
            />
          )}

          {activeTab === "quests" && (
            <QuestsView 
              quests={quests} 
              onOpenCreateModal={() => openModal("quest")} 
              onOpenEditModal={(q) => openModal("quest", q)} 
              onDeleteQuest={handleDeleteQuest} 
              onOpenStageModal={(qId) => openModal("stage", null, qId)} 
              onDeleteStage={handleDeleteStage} 
            />
          )}

          {activeTab === "analytics" && (
            <AnalyticsView interactions={interactions} />
          )}

          {activeTab === "social" && (
            <SocialView feedPosts={feedPosts} invitations={invitations} onDeletePost={handleDeletePost} onCreatePost={handleCreatePost} />
          )}

          {activeTab === "teams" && (
            <TeamsView teams={teams} battles={battles} onDeleteTeam={handleDeleteTeam} onCreateTeam={handleCreateTeam} />
          )}

          {activeTab === "offers" && (
            <OffersView offers={offers} adViews={adViews} onToggleOffer={handleToggleOffer} onCreateOffer={handleCreateOffer} />
          )}

          {activeTab === "economy" && (
            <EconomyView transactions={transactions} appConfigs={appConfigs} onSaveConfig={handleSaveConfig} />
          )}

          {activeTab === "activity" && (
            <ActivityView activities={activities} steps={steps} onDeleteActivity={handleDeleteActivity} />
          )}

          {activeTab === "corporate" && (
            <CorporateView companies={companies} onDeleteCompany={handleDeleteCompany} onCreateCompany={handleCreateCompany} />
          )}

          {activeTab === "messaging" && (
            <MessagingView conversations={conversations} onDeleteConversation={handleDeleteConversation} />
          )}

          {activeTab === "anomalies" && (
            <AnomaliesView 
              anomalies={anomalies} 
              onUpdateStatus={handleUpdateAnomalyStatus}
              statusFilter={anomaliesStatusFilter}
              setStatusFilter={setAnomaliesStatusFilter}
            />
          )}
        </div>
      </main>

      {/* CRUD modalled Forms */}
      <Modal 
        isOpen={isModalOpen} 
        title={`${editingItem ? "Edit" : "Create"} ${modalType}`}
        onClose={() => { setIsModalOpen(false); setEditingItem(null); }}
      >
        {/* Modal Challenge Form */}
        {modalType === "challenge" && (
          <form onSubmit={handleSaveChallenge} className="modal-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Title</label>
                <input type="text" value={challengeForm.title} onChange={e => setChallengeForm({...challengeForm, title: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Difficulty</label>
                <select value={challengeForm.difficulty} onChange={e => setChallengeForm({...challengeForm, difficulty: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }}>
                  <option value="EASY">EASY</option>
                  <option value="MEDIUM">MEDIUM</option>
                  <option value="HARD">HARD</option>
                  <option value="EXTREME">EXTREME</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea value={challengeForm.description} onChange={e => setChallengeForm({...challengeForm, description: e.target.value})} rows={3} className="form-input" style={{ padding: "12px", width: "100%", resize: "none" }} required />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Step Target</label>
                <input type="number" value={challengeForm.stepTarget} onChange={e => setChallengeForm({...challengeForm, stepTarget: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Duration (Days)</label>
                <input type="number" value={challengeForm.durationDays} onChange={e => setChallengeForm({...challengeForm, durationDays: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
            </div>

            <div className="form-row-three">
              <div className="form-group">
                <label className="form-label">Coins Reward</label>
                <input type="number" value={challengeForm.rewardCoins} onChange={e => setChallengeForm({...challengeForm, rewardCoins: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">XP Reward</label>
                <input type="number" value={challengeForm.rewardXp} onChange={e => setChallengeForm({...challengeForm, rewardXp: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Challenge Type</label>
                <select value={challengeForm.challengeType} onChange={e => setChallengeForm({...challengeForm, challengeType: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }}>
                  <option value="SOLO">SOLO</option>
                  <option value="GROUP">GROUP</option>
                  <option value="TIMED">TIMED</option>
                  <option value="CORPORATE">CORPORATE</option>
                </select>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "8px", marginTop: "8px" }}>
              <input type="checkbox" id="isActive" checked={challengeForm.isActive} onChange={e => setChallengeForm({...challengeForm, isActive: e.target.checked})} style={{ width: "16px", height: "16px", accentColor: "var(--primary)" }} />
              <label htmlFor="isActive" className="form-label" style={{ marginBottom: 0 }}>Challenge Active and Live</label>
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: "100%", padding: "14px", marginTop: "16px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.5px" }}>
              Save Challenge Config
            </button>
          </form>
        )}

        {/* Modal Achievement Form */}
        {modalType === "achievement" && (
          <form onSubmit={handleSaveAchievement} className="modal-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Unique Badge Code</label>
                <input type="text" value={achievementForm.code} onChange={e => setAchievementForm({...achievementForm, code: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} required placeholder="e.g. STEPS_100K" />
              </div>
              <div className="form-group">
                <label className="form-label">Badge Name</label>
                <input type="text" value={achievementForm.name} onChange={e => setAchievementForm({...achievementForm, name: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea value={achievementForm.description} onChange={e => setAchievementForm({...achievementForm, description: e.target.value})} rows={2} className="form-input" style={{ padding: "12px", width: "100%", resize: "none" }} required />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Category</label>
                <select value={achievementForm.category} onChange={e => setAchievementForm({...achievementForm, category: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }}>
                  <option value="STEPS">STEPS</option>
                  <option value="STREAK">STREAK</option>
                  <option value="DISTANCE">DISTANCE</option>
                  <option value="SPECIAL">SPECIAL</option>
                  <option value="CHALLENGE">CHALLENGE</option>
                  <option value="COINS">COINS</option>
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Points Reward (Bonus Coins)</label>
                <input type="number" value={achievementForm.pointsReward} onChange={e => setAchievementForm({...achievementForm, pointsReward: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
            </div>

            <div style={{ borderTop: "1px solid var(--border-color)", paddingTop: "16px", marginTop: "8px" }}>
              <p className="form-label" style={{ marginBottom: "12px", textTransform: "uppercase" }}>Trigger Requirements (Define at least one)</p>
              <div className="form-row-three">
                <div className="form-group">
                  <label className="form-label" style={{ fontSize: "0.65rem" }}>Steps Required</label>
                  <input type="number" value={achievementForm.stepsRequired} onChange={e => setAchievementForm({...achievementForm, stepsRequired: e.target.value})} className="form-input" style={{ padding: "10px", width: "100%" }} placeholder="e.g. 50000" />
                </div>
                <div className="form-group">
                  <label className="form-label" style={{ fontSize: "0.65rem" }}>Streak Required</label>
                  <input type="number" value={achievementForm.streakRequired} onChange={e => setAchievementForm({...achievementForm, streakRequired: e.target.value})} className="form-input" style={{ padding: "10px", width: "100%" }} placeholder="e.g. 7" />
                </div>
                <div className="form-group">
                  <label className="form-label" style={{ fontSize: "0.65rem" }}>Generic Target</label>
                  <input type="number" value={achievementForm.targetValue} onChange={e => setAchievementForm({...achievementForm, targetValue: e.target.value})} className="form-input" style={{ padding: "10px", width: "100%" }} placeholder="e.g. 100" />
                </div>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "8px", marginTop: "8px" }}>
              <input type="checkbox" id="badgeActive" checked={achievementForm.isActive} onChange={e => setAchievementForm({...achievementForm, isActive: e.target.checked})} style={{ width: "16px", height: "16px", accentColor: "var(--primary)" }} />
              <label htmlFor="badgeActive" className="form-label" style={{ marginBottom: 0 }}>Badge Config Active and Live</label>
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: "100%", padding: "14px", marginTop: "16px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.5px" }}>
              Save Badge Configuration
            </button>
          </form>
        )}

        {/* Modal Reward Form */}
        {modalType === "reward" && (
          <form onSubmit={handleSaveReward} className="modal-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Item Title</label>
                <input type="text" value={rewardForm.title} onChange={e => setRewardForm({...rewardForm, title: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Category</label>
                <select value={rewardForm.category} onChange={e => setRewardForm({...rewardForm, category: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }}>
                  <option value="FITNESS">FITNESS</option>
                  <option value="FOOD">FOOD</option>
                  <option value="LIFESTYLE">LIFESTYLE</option>
                  <option value="SHOPPING">SHOPPING</option>
                  <option value="TRAVEL">TRAVEL</option>
                  <option value="ENTERTAINMENT">ENTERTAINMENT</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea value={rewardForm.description} onChange={e => setRewardForm({...rewardForm, description: e.target.value})} rows={2} className="form-input" style={{ padding: "12px", width: "100%", resize: "none" }} required />
            </div>

            <div className="form-row-three">
              <div className="form-group">
                <label className="form-label">Coin Cost</label>
                <input type="number" value={rewardForm.coinCost} onChange={e => setRewardForm({...rewardForm, coinCost: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Available Stock</label>
                <input type="number" value={rewardForm.availableStock} onChange={e => setRewardForm({...rewardForm, availableStock: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Total Stock</label>
                <input type="number" value={rewardForm.totalStock} onChange={e => setRewardForm({...rewardForm, totalStock: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Partner Brand Name</label>
                <input type="text" value={rewardForm.partnerName} onChange={e => setRewardForm({...rewardForm, partnerName: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} placeholder="e.g. Nike" />
              </div>
              <div className="form-group">
                <label className="form-label">Brand Logo URL</label>
                <input type="text" value={rewardForm.partnerLogoUrl} onChange={e => setRewardForm({...rewardForm, partnerLogoUrl: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} />
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "8px", marginTop: "8px" }}>
              <input type="checkbox" id="rewardActive" checked={rewardForm.isActive} onChange={e => setRewardForm({...rewardForm, isActive: e.target.checked})} style={{ width: "16px", height: "16px", accentColor: "var(--primary)" }} />
              <label htmlFor="rewardActive" className="form-label" style={{ marginBottom: 0 }}>Reward Catalog Item Active</label>
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: "100%", padding: "14px", marginTop: "16px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.5px" }}>
              Save Catalog Reward
            </button>
          </form>
        )}

        {/* Modal Quest Form */}
        {modalType === "quest" && (
          <form onSubmit={handleSaveQuest} className="modal-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Quest Chain Title</label>
                <input type="text" value={questForm.title} onChange={e => setQuestForm({...questForm, title: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Difficulty</label>
                <select value={questForm.difficulty} onChange={e => setQuestForm({...questForm, difficulty: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }}>
                  <option value="EASY">EASY</option>
                  <option value="MEDIUM">MEDIUM</option>
                  <option value="HARD">HARD</option>
                  <option value="LEGENDARY">LEGENDARY</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea value={questForm.description} onChange={e => setQuestForm({...questForm, description: e.target.value})} rows={3} className="form-input" style={{ padding: "12px", width: "100%", resize: "none" }} required />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label">XP Completion Bonus</label>
                <input type="number" value={questForm.rewardXp} onChange={e => setQuestForm({...questForm, rewardXp: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Coins Completion Bonus</label>
                <input type="number" value={questForm.rewardCoins} onChange={e => setQuestForm({...questForm, rewardCoins: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "8px", marginTop: "8px" }}>
              <input type="checkbox" id="questActive" checked={questForm.isActive} onChange={e => setQuestForm({...questForm, isActive: e.target.checked})} style={{ width: "16px", height: "16px", accentColor: "var(--primary)" }} />
              <label htmlFor="questActive" className="form-label" style={{ marginBottom: 0 }}>Quest Chain Active and Live</label>
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: "100%", padding: "14px", marginTop: "16px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.5px" }}>
              Save Quest Configuration
            </button>
          </form>
        )}

        {/* Modal Stage Form */}
        {modalType === "stage" && (
          <form onSubmit={handleSaveStage} className="modal-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">Stage Order (Index)</label>
                <input type="number" value={stageForm.order} onChange={e => setStageForm({...stageForm, order: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
              <div className="form-group">
                <label className="form-label">Target Steps to Complete</label>
                <input type="number" value={stageForm.targetSteps} onChange={e => setStageForm({...stageForm, targetSteps: Number(e.target.value)})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Stage Title</label>
              <input type="text" value={stageForm.title} onChange={e => setStageForm({...stageForm, title: e.target.value})} className="form-input" style={{ padding: "12px", width: "100%" }} required />
            </div>

            <div className="form-group">
              <label className="form-label">Stage Task Description</label>
              <textarea value={stageForm.description} onChange={e => setStageForm({...stageForm, description: e.target.value})} rows={2} className="form-input" style={{ padding: "12px", width: "100%", resize: "none" }} required />
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: "100%", padding: "14px", marginTop: "16px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.5px" }}>
              Inject Pipeline Stage
            </button>
          </form>
        )}
      </Modal>
    </div>
  );
}
