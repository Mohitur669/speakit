import { Component, inject, signal, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../../../core/auth/auth.service';
import { NavbarComponent } from '../../../../../shared/components/navbar/navbar.component';
import { ToastService } from '../../../../../core/services/toast.service';
import { OtpInputComponent, runResendCooldown } from '../../../../../shared';
import { ConfirmModalComponent } from '../../../../../shared/components/confirm-modal/confirm-modal.component';

@Component({
  selector: 'app-verify-profile',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent, OtpInputComponent, ConfirmModalComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-16">
        <div class="w-full max-w-md animate-fade-in">
          <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden">
            <div class="p-8 pb-0">
              <h1 class="text-2xl font-bold text-primary-900 dark:text-white mb-2">Verify Profile Updates</h1>
              
              <div class="p-4 rounded-xl bg-blue-50 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-800 text-sm mt-4">
                @if (isEmailChanging()) {
                  <p class="font-semibold text-blue-800 dark:text-blue-300">
                    Email change pending: <span class="underline">{{ pendingEmail() }}</span>
                  </p>
                  <p class="text-xs text-primary-500 dark:text-primary-400 mt-1">
                    Your current email (<strong>{{ currentEmail }}</strong>) remains active until the new one is verified.
                  </p>
                } @else {
                  <p class="font-semibold text-blue-800 dark:text-blue-300">
                    Verification code required
                  </p>
                  <p class="text-xs text-primary-500 dark:text-primary-400 mt-1">
                    Please enter the code sent to your email (<strong>{{ currentEmail }}</strong>) to apply your profile changes.
                  </p>
                }
              </div>
            </div>

            <div class="p-8">
              <form (submit)="onSubmit()" class="space-y-6">
                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-3">
                    6-Digit Verification Code
                  </label>
                  <div class="flex justify-center">
                    <app-otp-input
                      [disabled]="loading()"
                      [hasError]="!!error()"
                      (valueChange)="otp = $event"
                      (complete)="otp = $event; onSubmit()"
                    ></app-otp-input>
                  </div>
                </div>

                @if (error()) {
                  <div class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/30">
                    <p class="text-sm text-red-600 dark:text-red-400">{{ error() }}</p>
                  </div>
                }

                <button
                  type="submit"
                  [disabled]="loading() || otp.length < 6"
                  class="w-full py-3 px-6 rounded-xl font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-xl active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  @if (loading()) {
                    <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                    </svg>
                  }
                  Verify & Apply Changes
                </button>
              </form>

              <div class="mt-8 pt-6 border-t border-primary-100 dark:border-primary-800 flex items-center justify-between gap-4">
                <button
                  type="button"
                  (click)="onCancel()"
                  [disabled]="loading()"
                  class="px-6 py-3 rounded-xl bg-primary-100 dark:bg-primary-800 text-primary-700 dark:text-primary-200 text-xs font-bold hover:bg-primary-200 dark:hover:bg-primary-700 transition-all active:scale-95 disabled:opacity-50"
                >
                  Discard Changes
                </button>

                <button
                  type="button"
                  (click)="onResend()"
                  [disabled]="resending() || resendCooldown() > 0 || loading()"
                  class="px-6 py-3 rounded-xl bg-brand-blue text-white text-xs font-bold hover:bg-blue-600 transition-all active:scale-95 disabled:opacity-50"
                >
                  {{ resending() ? 'Resending...' : resendCooldown() > 0 ? 'Resend in ' + resendCooldown() + 's' : 'Resend Code' }}
                </button>
              </div>

              <div class="mt-6 text-center">
                <a routerLink="/settings/profile" class="text-sm text-primary-500 hover:text-primary-700 dark:hover:text-primary-300 transition-colors">
                  Back to Profile
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    @if (showDiscardModal()) {
      <app-confirm-modal
        title="Discard Changes"
        message="Are you sure you want to discard your pending profile changes?"
        confirmText="Discard"
        cancelText="Cancel"
        [isDanger]="true"
        (confirm)="confirmCancel()"
        (cancel)="showDiscardModal.set(false)"
      ></app-confirm-modal>
    }
  `
})
export class VerifyProfileComponent implements OnInit, OnDestroy {
  currentEmail = '';
  pendingEmail = signal<string | null>(null);
  isEmailChanging = signal(false);
  otp = '';
  loading = signal(false);
  resending = signal(false);
  error = signal('');
  resendCooldown = signal(0);
  showDiscardModal = signal(false);
  private timerId?: any;

  private authService = inject(AuthService);
  private toastService = inject(ToastService);
  private router = inject(Router);

  ngOnInit(): void {
    if (!this.authService.isLoggedIn()) {
      this.router.navigate(['/login']);
      return;
    }

    const pending = this.authService.currentUserPendingEmail();
    const current = this.authService.currentUserEmail() || '';
    
    if (!pending) {
      // No pending changes, redirect back to profile page
      this.router.navigate(['/settings/profile']);
      return;
    }

    this.pendingEmail.set(pending);
    this.currentEmail = current;
    this.isEmailChanging.set(pending.toLowerCase() !== current.toLowerCase());
  }

  ngOnDestroy(): void {
    if (this.timerId) clearInterval(this.timerId);
  }

  onSubmit(): void {
    if (this.otp.length < 6) return;
    this.loading.set(true);
    this.error.set('');

    this.authService.verifyEmailChange(this.otp).subscribe({
      next: (res) => {
        this.loading.set(false);
        this.toastService.success('Profile changes verified and updated successfully.');
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
        this.toastService.success('Profile changes discarded.');
        this.router.navigate(['/settings/profile']);
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Failed to discard changes.');
        this.loading.set(false);
      }
    });
  }

  private startCooldown(): void {
    runResendCooldown(
      this.resendCooldown,
      () => this.timerId,
      (id) => this.timerId = id
    );
  }
}
