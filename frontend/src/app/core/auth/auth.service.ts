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
import { AuthResponse, LoginCredentials, RegisterCredentials, ResetPasswordCredentials } from './models';
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
  currentUserEmail = signal<string | null>(localStorage.getItem('email'));
  currentUserPhone = signal<string | null>(localStorage.getItem('phoneNumber'));
  currentUserPendingEmail = signal<string | null>(localStorage.getItem('pendingEmail'));
  token = signal<string | null>(localStorage.getItem('token'));
  
  // Robust plan type tracking using internal signal + computed fallback
  private planTypeSignal = signal<string | null>(localStorage.getItem('planType'));
  currentPlanType = computed(() => {
    const type = this.planTypeSignal();
    return type || 'FREE';
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
    if (this.ws) {
      this.ws.close();
    }
    const token = this.token();
    if (!token) return;
    let wsUrl = environment.apiUrl.startsWith('http') ? environment.apiUrl.replace(/^http/, 'ws') : `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}${environment.apiUrl}`;
    wsUrl += '/ws/logout?token=' + token;
    this.ws = new WebSocket(wsUrl);
    this.ws.onmessage = (event) => { if (event.data === 'LOGOUT') this.logout('Another login detected'); };
    this.ws.onclose = () => { if (this.isLoggedIn() && !this.isLoggingOut) setTimeout(() => this.setupWebSocket(), 5000); };
  }

  private setupBroadcastListener(): void {
    this.logoutChannel.onmessage = (event) => { if (event.data.type === 'LOGOUT') this.clearSessionAfterLogout(event.data.reason, true); };
  }

  register(credentials: RegisterCredentials): Observable<AuthResponse> {
    this.clearSession(); // Ensure clean slate for new user
    return this.http.post<AuthResponse>(`${this.apiUrl}/register`, credentials);
  }

  login(credentials: LoginCredentials): Observable<AuthResponse> {
    this.clearSession(); // Ensure clean slate for new session
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, credentials).pipe(tap(res => this.setSession(res)));
  }

  verifyEmail(email: string, otp: string): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/verify-email`, { email, otp }).pipe(
      tap(res => this.setSession(res))
    );
  }

  resendOtp(email: string): Observable<void> {
    return this.http.post<void>(`${this.apiUrl}/resend-otp`, { email });
  }

  forgotPassword(email: string): Observable<void> {
    return this.http.post<void>(`${this.apiUrl}/forgot-password`, { email });
  }

  resetPassword(credentials: ResetPasswordCredentials): Observable<void> {
    return this.http.post<void>(`${this.apiUrl}/reset-password`, credentials);
  }

  verifyEmailChange(otp: string): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${environment.apiUrl}/api/v1/users/me/verify-email-change`, { otp }).pipe(
      tap(res => this.setSession(res))
    );
  }

  checkUsername(username: string): Observable<boolean> {
    return this.http.get<boolean>(`${this.apiUrl}/check-username`, { params: { username } });
  }

  checkEmail(email: string): Observable<boolean> {
    return this.http.get<boolean>(`${this.apiUrl}/check-email`, { params: { email } });
  }

  checkPhone(phone: string): Observable<boolean> {
    return this.http.get<boolean>(`${this.apiUrl}/check-phone`, { params: { phone } });
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
    
    // 1. Comprehensive LocalStorage Purge
    localStorage.clear(); // Nuclear option for complete safety

    // 2. Clear Application State
    this.ttsService.clearCache();
    this.token.set(null);
    this.currentUser.set(null);
    this.currentUserEmail.set(null);
    this.currentUserPhone.set(null);
    this.currentUserPendingEmail.set(null);
    this.planTypeSignal.set(null);
    this.currentSessionVersion.set(0);

    // 3. Clear Browser Cache (Best effort via Service Worker if present, or simply reload)
    if ('caches' in window) {
      caches.keys().then(names => {
        for (let name of names) caches.delete(name);
      });
    }
  }

  private setSession(res: AuthResponse): void {
    /* 
    console.log('[Auth] Setting session with:', { 
      username: res.username, 
      email: res.email, 
      phone: res.phoneNumber 
    });
    */

    this.ttsService.clearCache();
    localStorage.setItem('token', res.token);
    localStorage.setItem('username', res.username);
    localStorage.setItem('email', res.email || '');
    localStorage.setItem('phoneNumber', res.phoneNumber || '');
    localStorage.setItem('planType', res.planType || 'FREE');
    localStorage.setItem('loginTimestamp', Date.now().toString());
    localStorage.setItem('sessionVersion', String(res.sessionVersion));
    localStorage.setItem('sessionDurationMs', String(res.sessionDurationMs));
    localStorage.setItem('idleTimeoutMs', String(res.idleTimeoutMs));

    this.token.set(res.token);
    this.currentUser.set(res.username);
    this.currentUserEmail.set(res.email || '');
    this.currentUserPhone.set(res.phoneNumber || '');
    this.currentUserPendingEmail.set(res.pendingEmail || null);
    if (res.pendingEmail) {
      localStorage.setItem('pendingEmail', res.pendingEmail);
    } else {
      localStorage.removeItem('pendingEmail');
    }
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
    events.forEach(event => window.addEventListener(event, handler));
    events.forEach(event => this.activityListeners.push({ event, handler }));
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

  updateProfile(data: any): Observable<AuthResponse> {
    return this.http.put<AuthResponse>(`${environment.apiUrl}/api/v1/users/profile`, data).pipe(
      tap(res => {
        // If password was changed, the backend increments session version and notifies logout.
        // If only profile was updated, we update the local session state.
        this.setSession(res);
        this.toastService.success('Profile updated successfully');
      })
    );
  }

  refreshStatus(): Observable<AuthResponse> {
    return this.http.get<AuthResponse>(`${this.apiUrl}/me`).pipe(
      tap((res) => {
        const oldPlan = this.planTypeSignal();
        this.currentUserEmail.set(res.email || '');
        this.currentUserPhone.set(res.phoneNumber || '');
        this.currentUserPendingEmail.set(res.pendingEmail || null);
        this.planTypeSignal.set(res.planType || 'FREE');
        localStorage.setItem('email', this.currentUserEmail() || '');
        localStorage.setItem('phoneNumber', this.currentUserPhone() || '');
        localStorage.setItem('planType', this.currentPlanType());
        if (res.pendingEmail) {
          localStorage.setItem('pendingEmail', res.pendingEmail);
        } else {
          localStorage.removeItem('pendingEmail');
        }

        // CRITICAL: If plan has changed (e.g. after upgrade), clear the voice cache
        // to ensure the next fetch retrieves the newly unlocked voices.
        if (oldPlan !== res.planType) {
          this.logger.info(`Plan upgraded from ${oldPlan} to ${res.planType}. Clearing voice cache.`);
          this.ttsService.clearCache();
        }
      })
    );
  }
}
