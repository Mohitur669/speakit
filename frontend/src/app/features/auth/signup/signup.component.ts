/**
 * User registration page component handling new
 * account creation and automatic login on success.
 */
import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';

@Component({
  selector: 'app-signup',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-16">
        <div class="w-full max-w-md animate-fade-in">
          <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden">
            <div class="p-8 pb-0">
              <h1 class="text-2xl font-bold text-primary-900 dark:text-white mb-2">Create your account</h1>
              <p class="text-primary-500 dark:text-primary-400">Start creating professional voiceovers today</p>
            </div>

            <div class="p-8">
              <form (submit)="onSubmit()" class="space-y-6">
                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Username</label>
                  <input [(ngModel)]="username" (input)="username = username.toLowerCase()" name="username" type="text" required
                    placeholder="johndoe"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase">
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Email</label>
                  <input [(ngModel)]="email" (input)="email = email.toLowerCase()" name="email" type="email" required
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase">
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Password</label>
                  <input [(ngModel)]="password" name="password" type="password" required
                    placeholder="••••••••"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
                  <p class="text-xs text-primary-400 mt-2">Must be at least 8 characters</p>
                </div>

                <div *ngIf="error()" class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/30">
                  <p class="text-sm text-red-600 dark:text-red-400 flex items-center gap-2">
                    <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    {{ error() }}
                  </p>
                </div>

                <button type="submit" [disabled]="loading()"
                  class="w-full py-3 px-6 rounded-xl font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-xl active:scale-[0.98] flex items-center justify-center gap-2">
                  <svg *ngIf="loading()" class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                  </svg>
                  {{ loading() ? 'Creating account...' : 'Create account' }}
                </button>
              </form>

              <div class="relative my-8">
                <div class="absolute inset-0 flex items-center">
                  <div class="w-full border-t border-primary-200 dark:border-primary-700"></div>
                </div>
                <div class="relative flex justify-center">
                  <span class="px-4 text-sm text-primary-400 bg-white dark:bg-primary-900">or</span>
                </div>
              </div>

              <p class="text-center text-primary-500 dark:text-primary-400">
                Already have an account?
                <a routerLink="/login" class="font-semibold text-brand-blue hover:text-brand-blue/80 transition-colors">Sign in</a>
              </p>
            </div>
          </div>

          <p class="text-center text-sm text-primary-400 mt-6">
            By creating an account, you agree to our Terms of Service and Privacy Policy.
          </p>
        </div>
      </div>
    </div>
  `
})
export class SignupComponent {
  username = '';
  email = '';
  password = '';
  loading = signal(false);
  error = signal('');

  private authService = inject(AuthService);
  private router = inject(Router);

  ngOnInit(): void {
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/tts']);
    }
  }

  onSubmit(): void {
    this.loading.set(true);
    this.error.set('');
    this.authService.register({ username: this.username, email: this.email, password: this.password }).subscribe({
      next: () => this.router.navigate(['/tts']),
      error: () => {
        this.error.set('Unable to create account. Username or email may already be in use.');
        this.loading.set(false);
      }
    });
  }
}