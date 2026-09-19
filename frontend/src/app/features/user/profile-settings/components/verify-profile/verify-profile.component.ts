import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../../../core/auth/auth.service';
import { ToastService } from '../../../../../core/services/toast.service';
import { NavbarComponent } from '../../../../../shared/components/navbar/navbar.component';

@Component({
  selector: 'app-verify-profile',
  standalone: true,
  imports: [CommonModule, FormsModule, NavbarComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <div class="flex-1 flex items-center justify-center p-4">
        <div class="w-full max-w-md bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden p-8">
          
          <div class="text-center mb-8">
            <div class="w-16 h-16 bg-brand-blue/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-brand-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-primary-900 dark:text-white">Verify Changes</h2>
            <p class="text-sm text-primary-500 dark:text-primary-400 mt-2">
              We've sent a verification code to your new email address. Please enter it below.
            </p>
          </div>

          <form (submit)="onSubmit()" class="space-y-6">
            <div>
              <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">
                Verification Code <span class="text-red-500">*</span>
              </label>
              <input
                [(ngModel)]="otp"
                name="otp"
                type="text"
                required
                maxlength="6"
                placeholder="Enter 6-digit code"
                class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all text-center tracking-[0.5em] text-lg font-mono"
              />
            </div>

            @if (error()) {
              <div class="p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
                {{ error() }}
              </div>
            }

            <button
              type="submit"
              [disabled]="loading() || otp.length !== 6"
              class="w-full py-3 rounded-xl bg-brand-blue hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold shadow-lg shadow-brand-blue/20 transition-all flex justify-center items-center gap-2"
            >
              @if (loading()) {
                <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                </svg>
              }
              Verify Code
            </button>
          </form>

          <div class="mt-8 pt-6 border-t border-primary-100 dark:border-primary-800 text-center space-y-4">
            <p class="text-sm text-primary-600 dark:text-primary-400">
              Didn't receive the code?
              <button
                type="button"
                (click)="onResend()"
                [disabled]="resendCooldown() > 0 || resending()"
                class="text-brand-blue hover:text-blue-600 font-medium disabled:opacity-50 disabled:cursor-not-allowed ml-1"
              >
                {{ resendCooldown() > 0 ? 'Resend in ' + resendCooldown() + 's' : 'Resend Code' }}
              </button>
            </p>
            
            <button
              type="button"
              (click)="onCancel()"
              class="text-sm text-red-500 hover:text-red-600 font-medium"
            >
              Cancel Profile Updates
            </button>
          </div>
        </div>
      </div>

      <!-- Discard Confirmation Modal -->
      @if (showDiscardModal()) {
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-primary-900/50 backdrop-blur-sm animate-fade-in">
          <div class="bg-white dark:bg-primary-900 rounded-2xl shadow-xl max-w-sm w-full overflow-hidden border border-primary-200 dark:border-primary-700 animate-slide-up">
            <div class="p-6">
              <h3 class="text-xl font-bold text-primary-900 dark:text-white mb-2">Cancel Updates?</h3>
              <p class="text-primary-600 dark:text-primary-400 text-sm mb-6">
                Are you sure you want to discard your profile changes? This action cannot be undone.
              </p>
              <div class="flex gap-3">
                <button
                  (click)="showDiscardModal.set(false)"
                  class="flex-1 px-4 py-2 rounded-xl bg-primary-100 dark:bg-primary-800 text-primary-700 dark:text-primary-300 font-medium hover:bg-primary-200 dark:hover:bg-primary-700 transition-colors"
                >
                  Keep Editing
                </button>
                <button
                  (click)="confirmCancel()"
                  class="flex-1 px-4 py-2 rounded-xl bg-red-500 text-white font-medium hover:bg-red-600 transition-colors"
                >
                  Discard
                </button>
              </div>
            </div>
          </div>
        </div>
      }
    </div>
  `
})
export class VerifyProfileComponent {
  otp = '';
  loading = signal(false);
  resending = signal(false);
  error = signal('');
  resendCooldown = signal(0);
  showDiscardModal = signal(false);
  private timerId?: any;

  private authService = inject(AuthService);
  private router = inject(Router);
  private toastService = inject(ToastService);

  onSubmit(): void {
    if (this.otp.length !== 6) return;
    
    this.loading.set(true);
    this.error.set('');

    this.authService.verifyEmailChange(this.otp).subscribe({
      next: (res) => {
        this.loading.set(false);
        this.toastService.success('Email verified and profile updated successfully.');
        this.router.navigate(['/settings/profile']);
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

    this.authService.resendProfileOtp().subscribe({
      next: () => {
        this.resending.set(false);
        this.toastService.success('Verification code resent successfully.');
        this.startCooldown();
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Failed to resend code. Please try again.');
        this.resending.set(false);
      }
    });
  }

  onCancel(): void {
    this.showDiscardModal.set(true);
  }

  confirmCancel(): void {
    this.showDiscardModal.set(false);
    this.loading.set(true);
    this.error.set('');

    this.authService.cancelProfileChanges().subscribe({
      next: () => {
        this.loading.set(false);
        this.toastService.success('Profile updates cancelled.');
        this.router.navigate(['/settings/profile']);
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Failed to cancel updates.');
        this.loading.set(false);
      }
    });
  }

  private startCooldown(): void {
    this.resendCooldown.set(60);
    clearInterval(this.timerId);
    this.timerId = setInterval(() => {
      const current = this.resendCooldown();
      if (current > 0) {
        this.resendCooldown.set(current - 1);
      } else {
        clearInterval(this.timerId);
      }
    }, 1000);
  }
}
