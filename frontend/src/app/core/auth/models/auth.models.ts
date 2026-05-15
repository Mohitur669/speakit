export interface AuthResponse {
  token: string;
  username: string;
  hasNaturalVoiceAccess: boolean;
  sessionVersion: number;
  sessionDurationMs: number;
  idleTimeoutMs: number;
}

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface RegisterCredentials {
  username: string;
  email: string;
  password: string;
}

export interface User {
  username: string;
  hasNaturalAccess: boolean;
}