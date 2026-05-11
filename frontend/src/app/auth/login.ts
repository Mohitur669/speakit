import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../services/auth';
import { NavbarComponent } from '../components/navbar.component';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-[calc(100-5rem)] bg-slate-50 dark:bg-[#090b11] transition-colors duration-500">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-16 font-body">
        <div class="max-w-md w-full space-y-8 p-8 lg:p-10 bg-white dark:bg-[#0f172a] rounded-3xl border border-slate-200 dark:border-slate-800 shadow-xl shadow-slate-200/50 dark:shadow-none animate-slide-up">
          <div class="text-center">
            <h2 class="text-3xl font-bold text-slate-900 dark:text-white tracking-tight mb-2">Welcome Back</h2>
            <p class="text-slate-500 dark:text-slate-400 text-sm font-medium">Log in to your SpeakIT account</p>
          </div>
          
          <form class="mt-8 space-y-6" (submit)="onSubmit()">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-1.5 ml-1">Username or Email</label>
                <input [(ngModel)]="username" name="username" type="text" required 
                  placeholder="name@example.com"
                  class="block w-full px-4 py-3 bg-slate-50 dark:bg-[#1e293b] text-slate-900 dark:text-white border border-slate-200 dark:border-slate-700 rounded-xl focus:outline-none focus:ring-2 focus:ring-amber-500/10 focus:border-amber-500 transition-all placeholder-slate-400 text-sm">
              </div>
              <div>
                <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-1.5 ml-1">Password</label>
                <input [(ngModel)]="password" name="password" type="password" required 
                  placeholder="••••••••"
                  class="block w-full px-4 py-3 bg-slate-50 dark:bg-[#1e293b] text-slate-900 dark:text-white border border-slate-200 dark:border-slate-700 rounded-xl focus:outline-none focus:ring-2 focus:ring-amber-500/10 focus:border-amber-500 transition-all placeholder-slate-400 text-sm">
              </div>
            </div>

            <div *ngIf="error" class="text-red-500 text-xs font-bold text-center bg-red-50 dark:bg-red-900/10 p-3 rounded-xl border border-red-100 dark:border-red-900/20 animate-shake">
              {{ error }}
            </div>

            <button type="submit" [disabled]="loading"
              class="w-full py-3.5 bg-slate-900 dark:bg-amber-500 hover:bg-black dark:hover:bg-amber-600 text-white dark:text-slate-900 rounded-xl font-bold text-base transition-all active:scale-[0.98] shadow-lg shadow-slate-900/10 dark:shadow-amber-500/10 flex items-center justify-center gap-2">
              <svg *ngIf="loading" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
              </svg>
              {{ loading ? 'Authenticating...' : 'Sign In' }}
            </button>

            <div class="relative py-2">
              <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-slate-100 dark:border-slate-800"></div></div>
              <div class="relative flex justify-center text-[10px] font-bold uppercase tracking-widest"><span class="bg-white dark:bg-[#0f172a] px-3 text-slate-400">New to SpeakIT?</span></div>
            </div>

            <p class="text-center text-slate-500 dark:text-slate-400 text-sm font-medium">
              Don't have an account? 
              <a routerLink="/signup" class="text-amber-600 dark:text-amber-500 font-bold ml-1 hover:underline">Create Account</a>
            </p>
          </form>
        </div>
      </div>
    </div>
  `
})
export class LoginComponent {
  username = '';
  password = '';
  loading = false;
  error = '';

  private authService = inject(AuthService);
  private router = inject(Router);

  onSubmit() {
    this.loading = true;
    this.error = '';
    this.authService.login({ username: this.username, password: this.password }).subscribe({
      next: () => this.router.navigate(['/tts']),
      error: (err) => {
        this.error = 'Invalid credentials. Please try again.';
        this.loading = false;
      }
    });
  }
}
