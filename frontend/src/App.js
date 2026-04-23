import React, { useState } from "react";
import Auth from "./components/Auth";
import TodoList from "./components/TodoList";
import { api } from "./api";

const styles = {
  header: {
    background: "#2563eb",
    color: "#fff",
    padding: "14px 24px",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
  },
  btn: {
    background: "rgba(255,255,255,0.2)",
    color: "#fff",
    border: "1px solid rgba(255,255,255,0.4)",
    borderRadius: 6,
    padding: "6px 16px",
    cursor: "pointer",
    fontSize: 14,
  },
};

export default function App() {
  // Persist auth state in localStorage so a page refresh keeps the user logged in.
  const [token, setToken] = useState(() => localStorage.getItem("token"));
  const [username, setUsername] = useState(() => localStorage.getItem("username"));

  function handleAuth({ token, username }) {
    localStorage.setItem("token", token);
    localStorage.setItem("username", username);
    setToken(token);
    setUsername(username);
  }

  async function handleLogout() {
    try {
      await api.logout();
    } catch {
      // Ignore — we still clear local state even if the server call fails
    }
    localStorage.removeItem("token");
    localStorage.removeItem("username");
    setToken(null);
    setUsername(null);
  }

  if (!token) {
    return <Auth onAuth={handleAuth} />;
  }

  return (
    <div>
      <header style={styles.header}>
        <span style={{ fontWeight: 600, fontSize: 18 }}>Todo App</span>
        <span>
          Hi, {username}&nbsp;&nbsp;
          <button style={styles.btn} onClick={handleLogout}>
            Sign Out
          </button>
        </span>
      </header>
      <TodoList />
    </div>
  );
}
