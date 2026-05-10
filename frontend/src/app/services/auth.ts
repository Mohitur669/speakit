import { Injectable, signal, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
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
  
  // Use signals for reactive state
  currentUser = signal<string | null>(localStorage.getItem('username'));
  token = signal<string | null>(localStorage.getItem('token'));
  hasNaturalAccess = signal<boolean>(localStorage.getItem('hasNaturalAccess') === 'true');

  // Use inject to avoid circular dependency
  private ttsService = inject(TtsService);

  constructor(private http: HttpClient) {}

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

  forgotPassword(email: string): Observable<void> {
    return this.http.post<void>(`${this.apiUrl}/forgot-password`, { email });
  }

  logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    localStorage.removeItem('hasNaturalAccess');
    this.ttsService.clearCache();
    this.token.set(null);
    this.currentUser.set(null);
    this.hasNaturalAccess.set(false);
  }

  private setSession(res: AuthResponse) {
    this.ttsService.clearCache();
    localStorage.setItem('token', res.token);
    localStorage.setItem('username', res.username);
    localStorage.setItem('hasNaturalAccess', String(res.hasNaturalVoiceAccess));
    this.token.set(res.token);
    this.currentUser.set(res.username);
    this.hasNaturalAccess.set(res.hasNaturalVoiceAccess);
  }

  isLoggedIn(): boolean {
    return !!this.token();
  }
}
