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
    <div class="min-h-screen bg-slate-50 dark:bg-[#0a0e1a] transition-colors duration-500">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-20 font-body">
        <div class="max-w-md w-full space-y-8 p-8 lg:p-12 bg-white dark:bg-[#0f1528] rounded-[2.5rem] border border-slate-200 dark:border-slate-800 shadow-2xl shadow-slate-200/50 dark:shadow-none animate-slide-up">
          <div class="text-center">
            <h2 class="text-4xl font-black text-slate-900 dark:text-white tracking-tighter mb-2 font-heading">Welcome Back</h2>
            <p class="text-slate-500 dark:text-slate-400 font-medium">Log in to continue your studio session</p>
          </div>
          
          <form class="mt-10 space-y-6" (submit)="onSubmit()">
            <div class="space-y-5">
              <div>
                <label class="block text-xs font-black text-slate-400 uppercase tracking-widest mb-2">Username or Email</label>
                <input [(ngModel)]="username" name="username" type="text" required 
                  placeholder="name@example.com"
                  class="block w-full px-5 py-4 bg-slate-50 dark:bg-[#0a0e1a] text-slate-900 dark:text-white border border-slate-100 dark:border-slate-800 rounded-2xl focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all placeholder-slate-400">
              </div>
              <div>
                <div class="flex items-center justify-between mb-2">
                  <label class="block text-xs font-black text-slate-400 uppercase tracking-widest">Password</label>
                  <button type="button" (click)="onForgot()" class="text-[10px] text-amber-500 hover:text-amber-400 font-black uppercase tracking-tighter transition-colors">Forgot password?</button>
                </div>
                <input [(ngModel)]="password" name="password" type="password" required 
                  placeholder="••••••••"
                  class="block w-full px-5 py-4 bg-slate-50 dark:bg-[#0a0e1a] text-slate-900 dark:text-white border border-slate-100 dark:border-slate-800 rounded-2xl focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all placeholder-slate-400">
              </div>
            </div>

            <div *ngIf="error" class="text-red-500 text-xs font-bold text-center bg-red-50 dark:bg-red-900/10 p-4 rounded-2xl border border-red-100 dark:border-red-900/20 animate-shake">
              {{ error }}
            </div>

            <button type="submit" [disabled]="loading"
              class="w-full py-5 bg-slate-900 dark:bg-amber-500 hover:bg-black dark:hover:bg-amber-600 text-white rounded-2xl font-black text-lg transition-all active:scale-[0.98] shadow-xl shadow-slate-900/20 dark:shadow-amber-500/20 flex items-center justify-center gap-2">
              <svg *ngIf="loading" class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
              </svg>
              {{ loading ? 'Authenticating...' : 'Sign In' }}
            </button>

            <div class="relative py-4">
              <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-slate-100 dark:border-slate-800"></div></div>
              <div class="relative flex justify-center text-[10px] font-black uppercase tracking-widest"><span class="bg-white dark:bg-[#0f1528] px-4 text-slate-400">New to SpeakIT?</span></div>
            </div>

            <p class="text-center text-slate-500 dark:text-slate-400 text-sm font-medium">
              Don't have an account? 
              <a routerLink="/signup" class="text-amber-500 hover:text-amber-400 font-black ml-1 transition-colors underline decoration-2 underline-offset-4">Create Account</a>
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

  onForgot() {
    if (!this.username.includes('@')) {
      this.error = 'Please enter your email to reset password.';
      return;
    }
    this.authService.forgotPassword(this.username).subscribe({
      next: () => {
        this.error = '';
        alert('Reset instructions sent to your email.');
      },
      error: () => this.error = 'Account not found with this email.'
    });
  }
}
