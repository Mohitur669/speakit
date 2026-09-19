import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { ToastService } from '../../../core/services/toast.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { PasswordRequirementsComponent, isPasswordValid } from '../../../shared';
import { PasswordPolicyModalComponent } from '../../../shared/components/password-policy-modal/password-policy-modal.component';

@Component({
  selector: 'app-change-password',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    RouterLink,
    NavbarComponent,
    PasswordRequirementsComponent,
    PasswordPolicyModalComponent
  ],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="max-w-xl mx-auto px-4 py-12">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-primary-900 dark:text-white mb-2">
            Change Password
          </h1>
          <p class="text-primary-500 dark:text-primary-400">
            Choose a new, secure password for your account.
          </p>
        </div>

        <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden p-8">
          <form (submit)="onSubmit()" class="space-y-6">
            
            <div class="space-y-6">
              <div>
                <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Current Password</label>
                <div class="relative">
                  <input
                    [(ngModel)]="currentPassword"
                    name="currentPassword"
                    [type]="showCurrPass ? 'text' : 'password'"
                    required
                    placeholder="Enter current password"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                  />
                  <button
                    type="button"
                    (click)="showCurrPass = !showCurrPass"
                    class="absolute right-4 top-1/2 -translate-y-1/2 text-primary-400 hover:text-primary-600"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      @if (!showCurrPass) {
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                      }
                      @if (showCurrPass) {
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18"></path>
                      }
                    </svg>
                  </button>
                </div>
              </div>

              <div class="flex items-center justify-between mb-2">
                <label class="block text-sm font-medium text-primary-700 dark:text-primary-300">New Password</label>
                <button
                  type="button"
                  (click)="showPolicyModal.set(true)"
                  class="text-[10px] font-bold text-brand-blue hover:underline"
                >
                  Password Policy
                </button>
              </div>
              <div class="relative">
                <input
                  [(ngModel)]="newPassword"
                  name="newPassword"
                  [type]="showNewPass ? 'text' : 'password'"
                  placeholder="Enter your new password"
                  class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                />
                <button
                  type="button"
                  (click)="showNewPass = !showNewPass"
                  class="absolute right-4 top-1/2 -translate-y-1/2 text-primary-400 hover:text-primary-600"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                  </svg>
                </button>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Confirm New Password</label>
              <div class="relative">
                <input
                  [(ngModel)]="confirmPassword"
                  name="confirmPassword"
                  [type]="showConfirmPass ? 'text' : 'password'"
                  placeholder="Confirm your new password"
                  class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                />
                <button
                  type="button"
                  (click)="showConfirmPass = !showConfirmPass"
                  class="absolute right-4 top-1/2 -translate-y-1/2 text-primary-400 hover:text-primary-600"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                  </svg>
                </button>
              </div>
            </div>

            <app-password-requirements
              [password]="newPassword"
              [confirmPassword]="confirmPassword"
            ></app-password-requirements>

            @if (error()) {
              <div class="p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
                {{ error() }}
              </div>
            }

            <div class="flex justify-end gap-4 pt-4 border-t border-primary-100 dark:border-primary-800">
              <button
                type="button"
                routerLink="/settings/profile"
                class="px-6 py-3 rounded-xl bg-primary-100 dark:bg-primary-800 text-primary-700 dark:text-primary-200 font-bold hover:bg-primary-200 dark:hover:bg-primary-700 transition-all active:scale-95 shadow-sm"
              >
                Cancel
              </button>
              <button
                type="submit"
                [disabled]="loading() || !currentPassword || !newPassword || !isPasswordValid(newPassword) || newPassword !== confirmPassword"
                class="px-8 py-3 rounded-xl bg-brand-blue hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold shadow-lg shadow-brand-blue/20 transition-all active:scale-95 flex items-center justify-center gap-2"
              >
                @if (loading()) {
                  <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                  </svg>
                }
                Proceed
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    @if (showPolicyModal()) {
      <app-password-policy-modal [password]="newPassword" (close)="showPolicyModal.set(false)"></app-password-policy-modal>
    }
  `
})
export class ChangePasswordPageComponent {
  currentPassword = '';
  newPassword = '';
  confirmPassword = '';
  showCurrPass = false;
  showNewPass = false;
  showConfirmPass = false;
  showPolicyModal = signal(false);
  loading = signal(false);
  error = signal('');

  private router = inject(Router);
  private authService = inject(AuthService);
  private toastService = inject(ToastService);

  isPasswordValid(pass: string): boolean {
    return isPasswordValid(pass);
  }

  onSubmit() {
    if (!this.currentPassword || !this.newPassword || !this.isPasswordValid(this.newPassword) || this.newPassword !== this.confirmPassword) {
      return;
    }
    
    this.loading.set(true);
    this.error.set('');

    const request = {
      currentPassword: this.currentPassword,
      newPassword: this.newPassword,
    };

    this.authService.changePassword(request).subscribe({
      next: () => {
        this.loading.set(false);
        this.router.navigate(['/settings/profile']);
      },
      error: (err) => {
        this.error.set(
          err.error?.message || 'Incorrect current password or failed to change password.'
        );
        this.loading.set(false);
      },
    });
  }
}
