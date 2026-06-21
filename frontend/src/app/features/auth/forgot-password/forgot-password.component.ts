import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { ToastService } from '../../../core/services/toast.service';

@Component({
  selector: 'app-forgot-password',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-16">
        <div class="w-full max-w-md animate-fade-in">
          <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden">
            <div class="p-8 pb-0">
              <h1 class="text-2xl font-bold text-primary-900 dark:text-white mb-2">Forgot Password</h1>
              <p class="text-primary-600 dark:text-primary-400 text-sm">
                Enter your email address and we'll send you an OTP to reset your password.
              </p>
            </div>

            <div class="p-8">
              <form (submit)="onSubmit()" class="space-y-6">
                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Email Address</label>
                  <input
                    [(ngModel)]="email"
                    name="email"
                    type="email"
                    required
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase"
                  />
                </div>

                @if (error()) {
                  <div class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/30">
                    <p class="text-sm text-red-600 dark:text-red-400">{{ error() }}</p>
                  </div>
                }

                <button
                  type="submit"
                  [disabled]="loading() || !email"
                  class="w-full py-3 px-6 rounded-xl font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-xl active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  @if (loading()) {
                    <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                    </svg>
                  }
                  Send OTP Code
                </button>
              </form>

              <div class="mt-6 text-center">
                <a routerLink="/login" class="text-sm text-brand-blue font-semibold hover:text-brand-blue/80 transition-colors">
                  Back to Sign in
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `
})
export class ForgotPasswordComponent {
  email = '';
  loading = signal(false);
  error = signal('');

  private authService = inject(AuthService);
  private toastService = inject(ToastService);
  private router = inject(Router);

  onSubmit(): void {
    this.loading.set(true);
    this.error.set('');
    this.authService.forgotPassword(this.email).subscribe({
      next: () => {
        this.loading.set(false);
        this.toastService.success('If the email is registered, we have sent a reset OTP code.');
        // Redirect to Reset Password page
        this.router.navigate(['/reset-password'], { queryParams: { email: this.email } });
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Failed to request reset. Please try again.');
        this.loading.set(false);
      }
    });
  }
}
