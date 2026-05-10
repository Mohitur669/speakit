import { Injectable, signal, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';
import { TtsService } from './tts';

export interface AuthResponse {
  token: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = `${environment.apiUrl}/api/auth`;
  
  // Use signals for reactive state
  currentUser = signal<string | null>(localStorage.getItem('username'));
  token = signal<string | null>(localStorage.getItem('token'));

  // Use inject to avoid circular dependency if TtsService also needs AuthService
  private ttsService = inject(TtsService);

  constructor(private http: HttpClient) {}

  register(credentials: { username: string; email: string; password: string }): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/register`, credentials).pipe(
      tap(res => this.setSession(res.token, credentials.username))
    );
  }

  login(credentials: { username: string; password: string }): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login`, credentials).pipe(
      tap(res => this.setSession(res.token, credentials.username))
    );
  }

  forgotPassword(email: string): Observable<void> {
    return this.http.post<void>(`${this.apiUrl}/forgot-password`, { email });
  }

  logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    this.ttsService.clearCache();
    this.token.set(null);
    this.currentUser.set(null);
  }

  private setSession(token: string, username: string) {
    this.ttsService.clearCache();
    localStorage.setItem('token', token);
    localStorage.setItem('username', username);
    this.token.set(token);
    this.currentUser.set(username);
  }

  isLoggedIn(): boolean {
    return !!this.token();
  }
}
