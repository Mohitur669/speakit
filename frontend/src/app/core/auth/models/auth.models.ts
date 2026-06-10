export interface AuthResponse {
  token: string;
  username: string;
  email: string;
  phoneNumber: string;
  planType: string;
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
  phoneNumber: string;
  password: string;
}


