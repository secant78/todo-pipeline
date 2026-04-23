import React, { useState } from "react";
import { api } from "../api";

const s = {
  page: {
    minHeight: "100vh",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "#f0f2f5",
  },
  card: {
    background: "#fff",
    borderRadius: 12,
    padding: 36,
    width: 360,
    boxShadow: "0 2px 16px rgba(0,0,0,0.1)",
  },
  title: { fontSize: 24, fontWeight: 700, marginBottom: 24, textAlign: "center" },
  input: {
    width: "100%",
    padding: "10px 12px",
    border: "1px solid #d1d5db",
    borderRadius: 6,
    fontSize: 14,
    marginBottom: 12,
    outline: "none",
  },
  btn: {
    width: "100%",
    padding: "11px",
    background: "#2563eb",
    color: "#fff",
    border: "none",
    borderRadius: 6,
    fontSize: 15,
    fontWeight: 600,
    cursor: "pointer",
    marginTop: 4,
  },
  toggle: {
    marginTop: 16,
    textAlign: "center",
    fontSize: 14,
    color: "#6b7280",
  },
  link: { color: "#2563eb", cursor: "pointer", fontWeight: 500 },
  error: {
    background: "#fee2e2",
    color: "#dc2626",
    borderRadius: 6,
    padding: "8px 12px",
    fontSize: 13,
    marginBottom: 12,
  },
};

export default function Auth({ onAuth }) {
  const [mode, setMode] = useState("login"); // "login" | "signup"
  const [form, setForm] = useState({ username: "", email: "", password: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  function set(field) {
    return (e) => setForm((f) => ({ ...f, [field]: e.target.value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      let result;
      if (mode === "login") {
        result = await api.login(form.username, form.password);
      } else {
        result = await api.signup(form.username, form.email, form.password);
      }
      onAuth(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={s.page}>
      <div style={s.card}>
        <div style={s.title}>{mode === "login" ? "Sign In" : "Create Account"}</div>

        {error && <div style={s.error}>{error}</div>}

        <form onSubmit={handleSubmit}>
          <input
            style={s.input}
            placeholder="Username"
            value={form.username}
            onChange={set("username")}
            required
            autoFocus
          />

          {/* Email field only shown during signup */}
          {mode === "signup" && (
            <input
              style={s.input}
              type="email"
              placeholder="Email"
              value={form.email}
              onChange={set("email")}
              required
            />
          )}

          <input
            style={s.input}
            type="password"
            placeholder="Password"
            value={form.password}
            onChange={set("password")}
            required
          />

          <button style={s.btn} type="submit" disabled={loading}>
            {loading ? "Please wait…" : mode === "login" ? "Sign In" : "Sign Up"}
          </button>
        </form>

        <div style={s.toggle}>
          {mode === "login" ? (
            <>
              No account?{" "}
              <span style={s.link} onClick={() => { setMode("signup"); setError(""); }}>
                Sign up
              </span>
            </>
          ) : (
            <>
              Already have an account?{" "}
              <span style={s.link} onClick={() => { setMode("login"); setError(""); }}>
                Sign in
              </span>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
