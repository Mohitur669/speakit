import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { ToastService } from '../../../core/services/toast.service';

@Component({
  selector: 'app-security-verify',
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
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-primary-900 dark:text-white">Security Verification</h2>
            <p class="text-sm text-primary-500 dark:text-primary-400 mt-2">
              Please enter your current password and the OTP sent to your current email to confirm these changes.
            </p>
          </div>

          <form (submit)="onSubmit()" class="space-y-6">
            <div>
              <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">
                Current Password <span class="text-red-500">*</span>
              </label>
              <div class="relative">
                <input
                  [(ngModel)]="currentPassword"
                  name="currentPassword"
                  [type]="showPass ? 'text' : 'password'"
                  required
                  placeholder="Enter current password"
                  class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                />
                <button
                  type="button"
                  (click)="showPass = !showPass"
                  class="absolute right-4 top-1/2 -translate-y-1/2 text-primary-400 hover:text-primary-600"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    @if (!showPass) {
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                    }
                    @if (showPass) {
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18"></path>
                    }
                  </svg>
                </button>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">
                Verification Code (OTP) <span class="text-red-500">*</span>
              </label>
              <input
                [(ngModel)]="otp"
                name="otp"
                type="text"
                required
                placeholder="Enter 6-digit OTP"
                class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
              />
            </div>

            @if (error()) {
              <div class="p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
                {{ error() }}
              </div>
            }

            <div class="flex gap-4">
              <button
                type="button"
                (click)="goBack()"
                class="flex-1 py-3 rounded-xl bg-primary-100 dark:bg-primary-800 text-primary-700 dark:text-primary-200 font-bold hover:bg-primary-200 dark:hover:bg-primary-700 transition-all"
              >
                Cancel
              </button>
              <button
                type="submit"
                [disabled]="loading() || !currentPassword || !otp"
                class="flex-1 py-3 rounded-xl bg-brand-blue hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold shadow-lg shadow-brand-blue/20 transition-all flex justify-center items-center gap-2"
              >
                @if (loading()) {
                  <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                  </svg>
                }
                Confirm
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  `
})
export class SecurityVerifyComponent implements OnInit {
  currentPassword = '';
  otp = '';
  showPass = false;
  loading = signal(false);
  error = signal('');

  private pendingData: any = null;

  private router = inject(Router);
  private authService = inject(AuthService);
  private toastService = inject(ToastService);

  ngOnInit() {
    const navigation = this.router.getCurrentNavigation();
    if (navigation?.extras?.state) {
      this.pendingData = navigation.extras.state;
    } else {
      this.pendingData = history.state;
    }

    if (!this.pendingData || !this.pendingData.profileData) {
      this.router.navigate(['/settings/profile']);
      return;
    }
  }

  goBack() {
    this.router.navigate(['/settings/profile']);
  }

  onSubmit() {
    if (!this.currentPassword || !this.otp) return;

    this.loading.set(true);
    this.error.set('');

    const request = {
      username: this.pendingData.profileData.username,
      email: this.pendingData.profileData.email,
      phoneNumber: this.pendingData.profileData.phoneNumber,
      currentPassword: this.currentPassword,
      otp: this.otp,
    };

    this.authService.updateProfile(request).subscribe({
      next: (res) => {
        this.loading.set(false);
        this.toastService.success('Profile updated successfully.');
        this.router.navigate(['/settings/profile']);
      },
      error: (err) => {
        this.error.set(
          err.error?.message || 'Incorrect password, OTP, or failed to update profile.'
        );
        this.loading.set(false);
      },
    });
  }
}
