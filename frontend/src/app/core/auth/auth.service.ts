/**
 * Central authentication service managing user login, registration,
 * session state, and JWT token lifecycle with automatic expiration.
 */
import { Injectable, signal, inject, OnDestroy, computed } from '@angular/core';
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
  
  // Robust plan type tracking using internal signal + computed fallback
  private planTypeSignal = signal<string | null>(localStorage.getItem('planType'));
  currentPlanType = computed(() => {
    const type = this.planTypeSignal();
    if (type && type !== 'FREE') return type;
    return this.hasNaturalAccess() ? 'PRO' : 'FREE';
  });

  currentSessionVersion = signal<number>(parseInt(localStorage.getItem('sessionVersion') || '0', 10));

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

  private setupWebSocket(): void {
    if (this.ws) this.ws.close();
    const token = this.token();
    if (!token) return;
    let wsUrl = environment.apiUrl.startsWith('http') ? environment.apiUrl.replace(/^http/, 'ws') : `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}${environment.apiUrl}`;
    wsUrl += '/ws/logout?token=' + token;
    this.ws = new WebSocket(wsUrl);
    this.ws.onmessage = (e) => { if (e.data === 'LOGOUT') this.logout('Another login detected'); };
    this.ws.onclose = () => { if (this.isLoggedIn() && !this.isLoggingOut) setTimeout(() => this.setupWebSocket(), 5000); };
  }

  private setupBroadcastListener(): void {
    this.logoutChannel.onmessage = (e) => { if (e.data.type === 'LOGOUT') this.clearSessionAfterLogout(e.data.reason, true); };
  }

  register(credentials: RegisterCredentials): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/register`, credentials).pipe(tap(res => this.setSession(res)));
  }

  login(credentials: LoginCredentials): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, credentials).pipe(tap(res => this.setSession(res)));
  }

  logout(reason?: string): void {
    if (this.isLoggingOut) return;
    this.isLoggingOut = true;
    this.http.post(`${this.apiUrl}/logout`, {}).subscribe({
      next: () => this.clearSessionAfterLogout(reason),
      error: () => this.clearSessionAfterLogout(reason)
    });
  }

  private clearSessionAfterLogout(reason?: string, isExternal = false): void {
    this.clearSession();
    this.isLoggingOut = false;
    if (!isExternal) this.logoutChannel.postMessage({ type: 'LOGOUT', reason });
    if (reason || isExternal) {
      this.toastService.info(reason || 'Session expired. Please log in again', 2000);
      setTimeout(() => this.router.navigate(['/login']), 1500);
    } else {
      this.toastService.success('Successfully logged out');
      setTimeout(() => this.router.navigate(['/login']), 500);
    }
  }

  private clearSession(): void {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    if (this.idleTimeoutId) clearTimeout(this.idleTimeoutId);
    this.ws?.close();
    this.removeActivityListeners();
    if (this.visibilityCallback) document.removeEventListener('visibilitychange', this.visibilityCallback);
    
    ['token', 'username', 'hasNaturalAccess', 'planType', 'loginTimestamp', 'sessionVersion', 'sessionDurationMs', 'idleTimeoutMs']
      .forEach(k => localStorage.removeItem(k));

    this.ttsService.clearCache();
    this.token.set(null);
    this.currentUser.set(null);
    this.hasNaturalAccess.set(false);
    this.planTypeSignal.set(null);
    this.currentSessionVersion.set(0);
  }

  private setSession(res: AuthResponse): void {
    this.ttsService.clearCache();
    localStorage.setItem('token', res.token);
    localStorage.setItem('username', res.username);
    localStorage.setItem('hasNaturalAccess', String(res.hasNaturalVoiceAccess));
    localStorage.setItem('planType', res.planType || 'FREE');
    localStorage.setItem('loginTimestamp', Date.now().toString());
    localStorage.setItem('sessionVersion', String(res.sessionVersion));
    localStorage.setItem('sessionDurationMs', String(res.sessionDurationMs));
    localStorage.setItem('idleTimeoutMs', String(res.idleTimeoutMs));

    this.token.set(res.token);
    this.currentUser.set(res.username);
    this.hasNaturalAccess.set(res.hasNaturalVoiceAccess);
    this.planTypeSignal.set(res.planType || 'FREE');
    this.currentSessionVersion.set(res.sessionVersion);
    this.sessionDuration = res.sessionDurationMs;
    this.idleTimeout = res.idleTimeoutMs;

    this.startSessionTimer(this.sessionDuration);
    this.initializeActivityValidation();
    this.setupIdleTimer();
    this.setupWebSocket();
  }

  private setupIdleTimer(): void {
    if (!this.isLoggedIn()) return;
    this.resetIdleTimer();
    const events = ['mousedown', 'mousemove', 'keypress', 'touchstart', 'scroll'];
    this.removeActivityListeners();
    const handler = () => this.resetIdleTimer();
    events.forEach(e => window.addEventListener(e, handler));
    events.forEach(e => this.activityListeners.push({ event: e, handler }));
  }

  private resetIdleTimer(): void {
    if (this.idleTimeoutId) clearTimeout(this.idleTimeoutId);
    if (this.isLoggedIn()) this.idleTimeoutId = setTimeout(() => this.logout(`Logged out due to inactivity`), this.idleTimeout);
  }

  private removeActivityListeners(): void {
    this.activityListeners.forEach(l => window.removeEventListener(l.event, l.handler));
    this.activityListeners = [];
  }

  private initializeActivityValidation(): void {
    if (!this.isLoggedIn()) return;
    if (this.visibilityCallback) document.removeEventListener('visibilitychange', this.visibilityCallback);
    this.visibilityCallback = () => { if (document.visibilityState === 'visible') this.resetIdleTimer(); };
    document.addEventListener('visibilitychange', this.visibilityCallback);
  }

  private checkSessionValidity(): void {
    const loginTimestamp = localStorage.getItem('loginTimestamp');
    if (loginTimestamp) {
      const elapsed = Date.now() - parseInt(loginTimestamp, 10);
      if (elapsed >= this.sessionDuration) this.clearSession();
      else this.startSessionTimer(this.sessionDuration - elapsed);
    }
  }

  private startSessionTimer(duration: number): void {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    this.timeoutId = setTimeout(() => this.logout('Session timeout'), duration);
  }

  isLoggedIn(): boolean { return !!this.token(); }

  refreshStatus(): void {
    if (!this.isLoggedIn()) return;
    this.http.get<AuthResponse>(`${this.apiUrl}/me`).subscribe({
      next: (res) => {
        this.hasNaturalAccess.set(res.hasNaturalVoiceAccess);
        this.planTypeSignal.set(res.planType || (res.hasNaturalVoiceAccess ? 'PRO' : 'FREE'));
        localStorage.setItem('hasNaturalAccess', String(res.hasNaturalVoiceAccess));
        localStorage.setItem('planType', this.currentPlanType());
      },
      error: (err) => this.logger.error('Failed to refresh user status', err)
    });
  }
}
