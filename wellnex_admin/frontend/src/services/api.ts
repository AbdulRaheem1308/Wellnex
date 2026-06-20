const API_BASE = "https://admin-api.joinwellnex.com/api/admin";

export const getApiKey = (): string => {
  return localStorage.getItem("wellnex_admin_key") || "";
};

export const setApiKey = (key: string) => {
  localStorage.setItem("wellnex_admin_key", key);
};

export const clearApiKey = () => {
  localStorage.removeItem("wellnex_admin_key");
};

export const apiFetch = async (endpoint: string, options: RequestInit = {}) => {
  const apiKey = getApiKey();
  const headers = {
    "Content-Type": "application/json",
    "x-admin-api-key": apiKey,
    ...(options.headers || {})
  };

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers
  });

  if (!response.ok) {
    if (response.status === 401) {
      clearApiKey();
    }
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData.message || `API request failed with status: ${response.status}`);
  }

  return response.json();
};
