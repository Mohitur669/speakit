/**
 * Central authentication service managing user login, registration,
 * session state, and JWT token lifecycle with automatic expiration.
 *
 * Optimized with Dynamic Configuration from Environment/Backend:
 * - Activity-Based Session Validation (Tab focus + Dynamic Heartbeat)
 * - Dynamic Idle Timeout (Logs out if no user interaction)
 * - Dynamic Session Duration
 * - WebSocket integration for instant remote logout
 */
import { Injectable, signal, inject, OnDestroy } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { TtsService } from '../services/tts.service';
import { ToastService } from '../services/toast.service';
import { LoggerService } from '../services/logger.service';
import { AuthResponse, LoginCredentials, RegisterCredentials } from './models';
import { environment } from '../../../environments/environment';

const DEFAULT_SESSION_DURATION = 2 * 60 * 60 * 1000; // 2 hours
const DEFAULT_IDLE_TIMEOUT = 60000; // 1 minute

@Injectable({ providedIn: 'root' })
export class AuthService implements OnDestroy {
  private apiUrl = `${environment.apiUrl}/api/auth`;
  private timeoutId?: ReturnType<typeof setTimeout>;
  private idleTimeoutId?: any;
  private visibilityCallback?: () => void;
  private activityListeners: Array<{event: string, handler: any}> = [];
  private isLoggingOut = false;
  private logoutChannel = new BroadcastChannel('auth_logout');
  private ws?: WebSocket;

  // Signal-based reactive state for consumption by UI components
  currentUser = signal<string | null>(localStorage.getItem('username'));
  token = signal<string | null>(localStorage.getItem('token'));
  hasNaturalAccess = signal<boolean>(localStorage.getItem('hasNaturalAccess') === 'true');
  currentSessionVersion = signal<number>(parseInt(localStorage.getItem('sessionVersion') || '0', 10));

  // Dynamic settings from localStorage (sent by backend during login)
  private sessionDuration = parseInt(localStorage.getItem('sessionDurationMs') || String(DEFAULT_SESSION_DURATION), 10);
  private idleTimeout = parseInt(localStorage.getItem('idleTimeoutMs') || String(DEFAULT_IDLE_TIMEOUT), 10);

  private ttsService = inject(TtsService);
  private toastService = inject(ToastService);
  private logger = inject(LoggerService);
  private router = inject(Router);

  constructor(private http: HttpClient) {
    this.checkSessionValidity();
    this.initializeActivityValidation();
    this.setupIdleTimer();
    this.setupBroadcastListener();
    this.setupWebSocket();
  }

  ngOnDestroy(): void {
    this.logoutChannel.close();
    this.ws?.close();
  }

  /**
   * Initializes a WebSocket connection to the backend to listen for instant logout events
   * (e.g., when a user logs in from another device, incrementing their session_version).
   */
  private setupWebSocket(): void {
    if (this.ws) {
      this.ws.close();
    }

    const token = this.token();
    if (!token) return;

    let wsUrl = '';
    if (environment.apiUrl.startsWith('http')) {
      wsUrl = environment.apiUrl.replace(/^http/, 'ws');
    } else {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const host = window.location.host;
      wsUrl = `${protocol}//${host}${environment.apiUrl}`;
    }

    wsUrl += '/ws/logout?token=' + token;
    this.logger.debug('Connecting to WebSocket', { url: wsUrl });

    this.ws = new WebSocket(wsUrl);
    this.ws.onmessage = (event) => {
      if (event.data === 'LOGOUT') {
        this.logout('Another login detected');
      }
    };

    // Reconnect on close if still logged in
    this.ws.onclose = () => {
      if (this.isLoggedIn() && !this.isLoggingOut) {
        setTimeout(() => this.setupWebSocket(), 5000);
      }
    };
  }

  /**
   * Listens for cross-tab logout events to ensure all instances of the application
   * securely drop the session if the user logs out in one tab.
   */
  private setupBroadcastListener(): void {
    this.logoutChannel.onmessage = (event) => {
      if (event.data.type === 'LOGOUT') {
        this.clearSessionAfterLogout(event.data.reason, true);
      }
    };
  }

  /**
   * Registers a new user and automatically logs them in upon success.
   */
  register(credentials: RegisterCredentials): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/register`, credentials).pipe(
      tap(res => this.setSession(res))
    );
  }

  /**
   * Authenticates a user against the backend, establishes a local session,
   * and initializes activity tracking and WebSockets.
   */
  login(credentials: LoginCredentials): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, credentials).pipe(
      tap(res => this.setSession(res))
    );
  }

  /**
   * Securely terminates the session. Notifies the backend to invalidate the token,
   * clears local state, and redirects to the login screen.
   */
  logout(reason?: string): void {
    if (this.isLoggingOut) return;
    this.isLoggingOut = true;

    this.http.post(`${this.apiUrl}/logout`, {}).subscribe({
      next: () => this.clearSessionAfterLogout(reason),
      error: () => this.clearSessionAfterLogout(reason)
    });
  }

  /**
   * Internal mechanism to wipe localStorage and broadcast the logout to other tabs.
   */
  private clearSessionAfterLogout(reason?: string, isExternal = false): void {
    this.clearSession();
    this.isLoggingOut = false;

    // Notify other tabs if this logout originated here
    if (!isExternal) {
      this.logoutChannel.postMessage({ type: 'LOGOUT', reason });
    }

    if (reason || isExternal) {
      // Show info message for external/reason-based logouts (e.g. session expired, multi-login)
      this.toastService.info(reason || 'Session expired. Please log in again', 2000);
      setTimeout(() => {
        this.router.navigate(['/login']);
      }, 1500);
    } else {
      // Manual logout
      this.toastService.success('Successfully logged out');
      setTimeout(() => {
        this.router.navigate(['/login']);
      }, 500);
    }
  }

  /**
   * Wipes all authentication signals, cache configurations, and localStorage items.
   */
  private clearSession(): void {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    if (this.idleTimeoutId) clearTimeout(this.idleTimeoutId);

    this.ws?.close();
    this.removeActivityListeners();

    if (this.visibilityCallback) {
      document.removeEventListener('visibilitychange', this.visibilityCallback);
      this.visibilityCallback = undefined;
    }
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    localStorage.removeItem('hasNaturalAccess');
    localStorage.removeItem('loginTimestamp');
    localStorage.removeItem('sessionVersion');
    localStorage.removeItem('sessionDurationMs');
    localStorage.removeItem('idleTimeoutMs');

    this.ttsService.clearCache();
    this.token.set(null);
    this.currentUser.set(null);
    this.hasNaturalAccess.set(false);
    this.currentSessionVersion.set(0);
  }

  /**
   * Hydrates the session state from the backend AuthResponse and starts local timers.
   */
  private setSession(res: AuthResponse): void {
    this.logger.info('Setting dynamic session', {
      version: res.sessionVersion,
      duration: res.sessionDurationMs,
      idle: res.idleTimeoutMs
    });

    this.ttsService.clearCache();

    // Store settings in localStorage
    localStorage.setItem('token', res.token);
    localStorage.setItem('username', res.username);
    localStorage.setItem('hasNaturalAccess', String(res.hasNaturalVoiceAccess));
    localStorage.setItem('loginTimestamp', Date.now().toString());
    localStorage.setItem('sessionVersion', String(res.sessionVersion));
    localStorage.setItem('sessionDurationMs', String(res.sessionDurationMs));
    localStorage.setItem('idleTimeoutMs', String(res.idleTimeoutMs));

    // Update active service state
    this.token.set(res.token);
    this.currentUser.set(res.username);
    this.hasNaturalAccess.set(res.hasNaturalVoiceAccess);
    this.currentSessionVersion.set(res.sessionVersion);

    this.sessionDuration = res.sessionDurationMs;
    this.idleTimeout = res.idleTimeoutMs;

    this.startSessionTimer(this.sessionDuration);
    this.initializeActivityValidation();
    this.setupIdleTimer();
    this.setupWebSocket();
  }

  /**
   * Tracks user interaction with the page to prevent timeouts while active.
   */
  private setupIdleTimer(): void {
    if (!this.isLoggedIn()) return;

    this.resetIdleTimer();

    const events = ['mousedown', 'mousemove', 'keypress', 'touchstart', 'scroll'];
    this.removeActivityListeners();

    const handler = () => this.resetIdleTimer();
    events.forEach(event => {
      window.addEventListener(event, handler);
      this.activityListeners.push({ event, handler });
    });
  }

  private resetIdleTimer(): void {
    if (this.idleTimeoutId) clearTimeout(this.idleTimeoutId);
    if (!this.isLoggedIn()) return;

    this.idleTimeoutId = setTimeout(() => {
      const minutes = Math.round(this.idleTimeout / 60000);
      this.logout(`Logged out due to ${minutes} minute(s) of inactivity`);
    }, this.idleTimeout);
  }

  private removeActivityListeners(): void {
    this.activityListeners.forEach(l => window.removeEventListener(l.event, l.handler));
    this.activityListeners = [];
  }

  /**
   * Listens for tab visibility changes to reset idle timers when the user returns.
   */
  private initializeActivityValidation(): void {
    if (!this.isLoggedIn()) return;

    if (this.visibilityCallback) {
      document.removeEventListener('visibilitychange', this.visibilityCallback);
    }
    this.visibilityCallback = () => {
      if (document.visibilityState === 'visible') {
        this.resetIdleTimer();
      }
    };
    document.addEventListener('visibilitychange', this.visibilityCallback);
  }

  /**
   * Validates if the local session has exceeded the hard duration limit on startup.
   */
  private checkSessionValidity(): void {
    const loginTimestamp = localStorage.getItem('loginTimestamp');
    if (loginTimestamp) {
      const elapsed = Date.now() - parseInt(loginTimestamp, 10);
      if (elapsed >= this.sessionDuration) {
        this.clearSession();
      } else {
        this.startSessionTimer(this.sessionDuration - elapsed);
      }
    }
  }

  private startSessionTimer(duration: number): void {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    this.timeoutId = setTimeout(() => this.logout('Session timeout'), duration);
  }

  /**
   * Reactive helper to check current authentication state.
   */
  isLoggedIn(): boolean {
    return !!this.token();
  }

  /**
   * Refreshes the current user's profile and status from the backend.
   * Useful after payments or plan changes to update the UI immediately.
   */
  refreshStatus(): void {
    if (!this.isLoggedIn()) return;

    this.http.get<AuthResponse>(`${this.apiUrl}/me`).subscribe({
      next: (res) => {
        this.logger.info('Refreshing user status', { hasNaturalAccess: res.hasNaturalVoiceAccess });
        
        // Update signals
        this.hasNaturalAccess.set(res.hasNaturalVoiceAccess);
        
        // Update localStorage
        localStorage.setItem('hasNaturalAccess', String(res.hasNaturalVoiceAccess));
        
        // Broadcast change if needed (though signals handle most of it)
      },
      error: (err) => this.logger.error('Failed to refresh user status', err)
    });
  }
}
