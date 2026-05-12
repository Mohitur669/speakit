import { Injectable, signal, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';
import { TtsService } from './tts';

export interface AuthResponse {
  token: string;
  username: string;
  hasNaturalVoiceAccess: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = `${environment.apiUrl}/api/auth`;
  private readonly SESSION_DURATION = 2 * 60 * 60 * 1000; // 2 hours in ms
  private timeoutId?: any;
  
  // Use signals for reactive state
  currentUser = signal<string | null>(localStorage.getItem('username'));
  token = signal<string | null>(localStorage.getItem('token'));
  hasNaturalAccess = signal<boolean>(localStorage.getItem('hasNaturalAccess') === 'true');

  // Use inject to avoid circular dependency
  private ttsService = inject(TtsService);
  private router = inject(Router);

  constructor(private http: HttpClient) {
    this.checkSessionValidity();
  }

  register(credentials: { username: string; email: string; password: string }): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/register`, credentials).pipe(
      tap(res => this.setSession(res))
    );
  }

  login(credentials: { username: string; password: string }): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, credentials).pipe(
      tap(res => this.setSession(res))
    );
  }

  logout() {
    this.clearSession();
    window.location.href = '/login';
  }

  private clearSession() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
    }
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    localStorage.removeItem('hasNaturalAccess');
    localStorage.removeItem('loginTimestamp');
    this.ttsService.clearCache();
    this.token.set(null);
    this.currentUser.set(null);
    this.hasNaturalAccess.set(false);
  }

  private setSession(res: AuthResponse) {
    const timestamp = Date.now().toString();
    this.ttsService.clearCache();
    localStorage.setItem('token', res.token);
    localStorage.setItem('username', res.username);
    localStorage.setItem('hasNaturalAccess', String(res.hasNaturalVoiceAccess));
    localStorage.setItem('loginTimestamp', timestamp);
    
    this.token.set(res.token);
    this.currentUser.set(res.username);
    this.hasNaturalAccess.set(res.hasNaturalVoiceAccess);
    
    this.startSessionTimer(this.SESSION_DURATION);
  }

  private checkSessionValidity() {
    const loginTimestamp = localStorage.getItem('loginTimestamp');
    if (loginTimestamp) {
      const elapsed = Date.now() - parseInt(loginTimestamp, 10);
      if (elapsed >= this.SESSION_DURATION) {
        this.clearSession();
      } else {
        this.startSessionTimer(this.SESSION_DURATION - elapsed);
      }
    }
  }

  private startSessionTimer(duration: number) {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
    }
    this.timeoutId = setTimeout(() => {
      this.logout();
    }, duration);
  }

  isLoggedIn(): boolean {
    return !!this.token();
  }
}
