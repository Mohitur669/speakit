import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { ToastService } from '../../../core/services/toast.service';
import { OtpInputComponent } from '../../../shared';

@Component({
  selector: 'app-verify-email',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent, OtpInputComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-16">
        <div class="w-full max-w-md animate-fade-in">
          <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden">
            <div class="p-8 pb-0">
              <h1 class="text-2xl font-bold text-primary-900 dark:text-white mb-2">Verify your email</h1>
              <p class="text-primary-600 dark:text-primary-400 text-sm">
                Enter the 6-digit verification code sent to @if (isEmailPrePopulated) { <strong class="text-primary-800 dark:text-primary-200">{{ email }}</strong> } @else { your email }.
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
                    [readonly]="isEmailPrePopulated"
                    [class.opacity-60]="isEmailPrePopulated"
                    [class.cursor-not-allowed]="isEmailPrePopulated"
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Verification Code</label>
                  <app-otp-input
                    [disabled]="loading()"
                    [hasError]="!!error()"
                    (valueChange)="otp = $event"
                    (complete)="otp = $event; onSubmit()"
                  ></app-otp-input>
                </div>

                @if (error()) {
                  <div class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/30">
                    <p class="text-sm text-red-600 dark:text-red-400">{{ error() }}</p>
                  </div>
                }

                <button
                  type="submit"
                  [disabled]="loading() || !email || otp.length < 6"
                  class="w-full py-3 px-6 rounded-xl font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-xl active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  @if (loading()) {
                    <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                    </svg>
                  }
                  Verify Account
                </button>
              </form>

              <div class="mt-6 flex flex-col items-center justify-center gap-3">
                <button
                  type="button"
                  (click)="onResend()"
                  [disabled]="resending() || resendCooldown() > 0"
                  class="text-sm font-semibold text-brand-blue hover:text-brand-blue/80 disabled:opacity-50 transition-colors"
                >
                  {{ resending() ? 'Resending...' : resendCooldown() > 0 ? 'Resend code in ' + resendCooldown() + 's' : 'Resend verification code' }}
                </button>
                <a routerLink="/login" class="text-sm text-primary-500 hover:text-primary-700 dark:hover:text-primary-300 transition-colors">
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
export class VerifyEmailComponent implements OnInit {
  email = '';
  otp = '';
  isEmailPrePopulated = false;
  loading = signal(false);
  resending = signal(false);
  error = signal('');
  resendCooldown = signal(0);
  private timerId?: any;

  private authService = inject(AuthService);
  private toastService = inject(ToastService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  ngOnInit(): void {
    const emailParam = this.route.snapshot.queryParams['email'] || '';
    this.email = emailParam;
    if (emailParam) {
      this.isEmailPrePopulated = true;
    }
  }

  onSubmit(): void {
    this.loading.set(true);
    this.error.set('');
    this.authService.verifyEmail(this.email, this.otp).subscribe({
      next: () => {
        this.loading.set(false);
        this.toastService.success('Email verified successfully! Welcome.');
        this.router.navigate(['/tts']);
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Invalid or expired verification code.');
        this.loading.set(false);
      }
    });
  }

  onResend(): void {
    this.resending.set(true);
    this.error.set('');
    this.authService.resendOtp(this.email).subscribe({
      next: () => {
        this.resending.set(false);
        this.toastService.success('Verification code resent.');
        this.startCooldown();
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Failed to resend code. Please try again.');
        this.resending.set(false);
      }
    });
  }

  private startCooldown(): void {
    this.resendCooldown.set(60);
    if (this.timerId) clearInterval(this.timerId);
    this.timerId = setInterval(() => {
      const val = this.resendCooldown() - 1;
      this.resendCooldown.set(val);
      if (val <= 0) clearInterval(this.timerId);
    }, 1000);
  }
}
