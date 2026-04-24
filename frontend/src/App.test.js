import { render, screen } from "@testing-library/react";
import App from "./App";

// Mock the API module so tests don't make real HTTP calls
jest.mock("./api", () => ({
  __esModule: true,
  api: {
    logout: jest.fn().mockResolvedValue({}),
    getTodos: jest.fn().mockResolvedValue([]),
  },
}));

describe("App", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  test("shows sign-in form when not authenticated", () => {
    render(<App />);
    expect(screen.getByPlaceholderText("Username")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Password")).toBeInTheDocument();
  });

  test("shows todo list and sign out button when authenticated", () => {
    localStorage.setItem("token", "fake-jwt-token");
    localStorage.setItem("username", "testuser");
    render(<App />);
    expect(screen.getByText(/testuser/i)).toBeInTheDocument();
    expect(screen.getByText("Sign Out")).toBeInTheDocument();
  });

  test("shows sign up link on the auth screen", () => {
    render(<App />);
    expect(screen.getByText("Sign up")).toBeInTheDocument();
  });
});
