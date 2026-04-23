import React, { useState, useEffect } from "react";
import { api } from "../api";

const s = {
  page: { maxWidth: 600, margin: "40px auto", padding: "0 16px" },
  addRow: { display: "flex", gap: 8, marginBottom: 24 },
  input: {
    flex: 1,
    padding: "10px 14px",
    border: "1px solid #d1d5db",
    borderRadius: 8,
    fontSize: 15,
    outline: "none",
  },
  addBtn: {
    padding: "10px 20px",
    background: "#2563eb",
    color: "#fff",
    border: "none",
    borderRadius: 8,
    fontSize: 15,
    fontWeight: 600,
    cursor: "pointer",
  },
  list: { listStyle: "none" },
  item: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    background: "#fff",
    borderRadius: 8,
    padding: "12px 16px",
    marginBottom: 8,
    boxShadow: "0 1px 4px rgba(0,0,0,0.06)",
  },
  checkbox: { width: 18, height: 18, cursor: "pointer", accentColor: "#2563eb" },
  label: { flex: 1, fontSize: 15 },
  done: { flex: 1, fontSize: 15, textDecoration: "line-through", color: "#9ca3af" },
  deleteBtn: {
    background: "none",
    border: "none",
    color: "#ef4444",
    fontSize: 18,
    cursor: "pointer",
    lineHeight: 1,
  },
  empty: { textAlign: "center", color: "#9ca3af", marginTop: 48, fontSize: 15 },
};

export default function TodoList() {
  const [todos, setTodos] = useState([]);
  const [newTitle, setNewTitle] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.getTodos()
      .then(setTodos)
      .finally(() => setLoading(false));
  }, []);

  async function handleAdd(e) {
    e.preventDefault();
    const title = newTitle.trim();
    if (!title) return;
    const todo = await api.createTodo(title);
    // Prepend so newest appears at top, matching the server's DESC order
    setTodos((prev) => [todo, ...prev]);
    setNewTitle("");
  }

  async function handleToggle(todo) {
    const updated = await api.updateTodo(todo.id, { completed: !todo.completed });
    setTodos((prev) => prev.map((t) => (t.id === updated.id ? { ...t, ...updated } : t)));
  }

  async function handleDelete(id) {
    await api.deleteTodo(id);
    setTodos((prev) => prev.filter((t) => t.id !== id));
  }

  if (loading) return <div style={s.empty}>Loading…</div>;

  return (
    <div style={s.page}>
      <form style={s.addRow} onSubmit={handleAdd}>
        <input
          style={s.input}
          placeholder="Add a new todo…"
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
          autoFocus
        />
        <button style={s.addBtn} type="submit">Add</button>
      </form>

      {todos.length === 0 ? (
        <div style={s.empty}>No todos yet. Add one above!</div>
      ) : (
        <ul style={s.list}>
          {todos.map((todo) => (
            <li key={todo.id} style={s.item}>
              <input
                style={s.checkbox}
                type="checkbox"
                checked={todo.completed}
                onChange={() => handleToggle(todo)}
              />
              <span style={todo.completed ? s.done : s.label}>{todo.title}</span>
              <button style={s.deleteBtn} onClick={() => handleDelete(todo.id)} title="Delete">
                ×
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
