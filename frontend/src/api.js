// Base URL is set at build time via REACT_APP_API_URL.
// In production the ALB routes /api/* to the backend service, so the default
// of "/api" works without any extra config in the container.
const BASE = process.env.REACT_APP_API_URL || "/api";

function authHeaders() {
  const token = localStorage.getItem("token");
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json", ...authHeaders() },
    ...options,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Request failed");
  return data;
}

export const api = {
  signup: (username, email, password) =>
    request("/auth/signup", {
      method: "POST",
      body: JSON.stringify({ username, email, password }),
    }),

  login: (username, password) =>
    request("/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),

  logout: () => request("/auth/logout", { method: "POST" }),

  getTodos: () => request("/todos"),

  createTodo: (title) =>
    request("/todos", { method: "POST", body: JSON.stringify({ title }) }),

  updateTodo: (id, patch) =>
    request(`/todos/${id}`, { method: "PUT", body: JSON.stringify(patch) }),

  deleteTodo: (id) => request(`/todos/${id}`, { method: "DELETE" }),
};
