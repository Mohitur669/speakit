/**
 * Central authentication service managing user login, registration,
 * session state, and JWT token lifecycle with automatic expiration.
 */
import { Injectable, signal, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { TtsService } from '../services/tts.service';
import { ToastService } from '../services/toast.service';
import { AuthResponse, LoginCredentials, RegisterCredentials } from './models';
import { environment } from '../../../environments/environment';

const SESSION_DURATION = 2 * 60 * 60 * 1000; // 2 hours in ms

@Injectable({ providedIn: 'root' })
export class AuthService {
  private apiUrl = `${environment.apiUrl}/api/auth`;
  private timeoutId?: ReturnType<typeof setTimeout>;
  private visibilityCallback?: () => void;
  private isLoggingOut = false;

  currentUser = signal<string | null>(localStorage.getItem('username'));
  token = signal<string | null>(localStorage.getItem('token'));
  hasNaturalAccess = signal<boolean>(localStorage.getItem('hasNaturalAccess') === 'true');
  currentSessionVersion = signal<number>(parseInt(localStorage.getItem('sessionVersion') || '0', 10));

  private ttsService = inject(TtsService);
  private toastService = inject(ToastService);
  private router = inject(Router);

  constructor(private http: HttpClient) {
    this.checkSessionValidity();
    this.setupVisibilityHandler();
  }

  register(credentials: RegisterCredentials): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/register`, credentials).pipe(
      tap(res => this.setSession(res))
    );
  }

  login(credentials: LoginCredentials): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, credentials).pipe(
      tap(res => this.setSession(res))
    );
  }

  logout(reason?: string): void {
    if (this.isLoggingOut) return;
    this.isLoggingOut = true;

    // Call server-side logout to invalidate all tokens
    this.http.post(`${this.apiUrl}/logout`, {}).subscribe({
      next: () => {
        this.clearSessionAfterLogout(reason);
      },
      error: () => {
        // Even if server call fails, clear local session
        this.clearSessionAfterLogout(reason);
      }
    });
  }

  private clearSessionAfterLogout(reason?: string): void {
    this.clearSession();
    this.isLoggingOut = false;
    if (reason) {
      this.toastService.info(reason);
    }
    // 2 seconds delay as requested to let the toast be seen
    setTimeout(() => {
      window.location.href = '/login';
    }, 2000);
  }

  private clearSession(): void {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    if (this.visibilityCallback) {
      document.removeEventListener('visibilitychange', this.visibilityCallback);
      this.visibilityCallback = undefined;
    }
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    localStorage.removeItem('hasNaturalAccess');
    localStorage.removeItem('loginTimestamp');
    localStorage.removeItem('sessionVersion');
    localStorage.removeItem('currentSessionVersion');
    this.ttsService.clearCache();
    this.token.set(null);
    this.currentUser.set(null);
    this.hasNaturalAccess.set(false);
    this.currentSessionVersion.set(0);
  }

  private setSession(res: AuthResponse): void {
    console.log('Setting session with version:', res.sessionVersion);
    const timestamp = Date.now().toString();
    this.ttsService.clearCache();
    localStorage.setItem('token', res.token);
    localStorage.setItem('username', res.username);
    localStorage.setItem('hasNaturalAccess', String(res.hasNaturalVoiceAccess));
    localStorage.setItem('loginTimestamp', timestamp);
    localStorage.setItem('sessionVersion', String(res.sessionVersion));
    this.token.set(res.token);
    this.currentUser.set(res.username);
    this.hasNaturalAccess.set(res.hasNaturalVoiceAccess);
    this.currentSessionVersion.set(res.sessionVersion);
    this.startSessionTimer(SESSION_DURATION);
    this.setupVisibilityHandler();
  }

  private setupVisibilityHandler(): void {
    // Remove existing listener if any
    if (this.visibilityCallback) {
      document.removeEventListener('visibilitychange', this.visibilityCallback);
    }

    // Only check session when user returns to the tab (not when leaving)
    this.visibilityCallback = () => {
      if (document.visibilityState === 'visible' && this.isLoggedIn()) {
        this.verifySessionOnResume();
      }
    };
    document.addEventListener('visibilitychange', this.visibilityCallback);
  }

  private verifySessionOnResume(): void {
    // Quick check only when user comes back to the app
    this.http.get<{ sessionVersion: number }>(`${this.apiUrl}/session-status`).subscribe({
      next: (res) => {
        if (res.sessionVersion !== this.currentSessionVersion()) {
          this.logout('Session invalidated by another login');
        }
      },
      error: (err) => {
        if (err.status === 401 || err.status === 403) {
          this.logout('Session invalidated by another login');
        }
      }
    });
  }

  private checkSessionValidity(): void {
    const loginTimestamp = localStorage.getItem('loginTimestamp');
    if (loginTimestamp) {
      const elapsed = Date.now() - parseInt(loginTimestamp, 10);
      if (elapsed >= SESSION_DURATION) {
        this.clearSession();
      } else {
        this.startSessionTimer(SESSION_DURATION - elapsed);
      }
    }
  }

  private startSessionTimer(duration: number): void {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    this.timeoutId = setTimeout(() => this.logout(), duration);
  }

  isLoggedIn(): boolean {
    return !!this.token();
  }
}
