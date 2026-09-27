import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { PasswordFieldGroupComponent } from './components/password-field-group/password-field-group.component';
import { PasswordPolicyModalComponent } from '../../../shared/components/password-policy-modal/password-policy-modal.component';
import { isPasswordValid } from '../../../shared';

@Component({
  selector: 'app-signup-password',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    NavbarComponent,
    PasswordFieldGroupComponent,
    PasswordPolicyModalComponent,
  ],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-16">
        <div class="w-full max-w-md animate-fade-in">
          <div
            class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden"
          >
            <div class="p-8 pb-0 flex items-center gap-4">
              <button
                type="button"
                (click)="goBack()"
                class="p-2 -ml-2 rounded-xl text-primary-400 hover:text-primary-600 dark:hover:text-primary-200 hover:bg-primary-50 dark:hover:bg-primary-800 transition-all"
                title="Back to previous step"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
                </svg>
              </button>
              <div>
                <h1 class="text-2xl font-bold text-primary-900 dark:text-white mb-1">
                  Secure your account
                </h1>
                <p class="text-primary-600 dark:text-primary-400 text-sm">
                  Choose a strong password
                </p>
              </div>
            </div>

            <div class="p-8">
              <form (submit)="onSubmit()" class="space-y-5">
                <div>
                  <app-password-field-group
                    [(password)]="password"
                    [(confirmPassword)]="confirmPassword"
                    (showPolicyModal)="showPolicyModal.set($event)"
                  >
                  </app-password-field-group>
                </div>

                @if (error()) {
                  <div
                    class="p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm animate-fade-in"
                  >
                    {{ error() }}
                  </div>
                }

                <button
                  type="submit"
                  [disabled]="
                    loading() ||
                    !isPasswordValid(password) ||
                    password !== confirmPassword
                  "
                  class="w-full mt-6 py-3 px-6 rounded-xl font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-xl active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  @if (loading()) {
                    <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      ></circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                      ></path>
                    </svg>
                  }
                  {{ loading() ? 'Creating account...' : 'Create Account' }}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>

    @if (showPolicyModal()) {
      <app-password-policy-modal [password]="password" (close)="showPolicyModal.set(false)">
      </app-password-policy-modal>
    }
  `
})
export class SignupPasswordComponent implements OnInit {
  password = '';
  confirmPassword = '';
  showPolicyModal = signal(false);
  loading = signal(false);
  error = signal('');

  private router = inject(Router);
  private authService = inject(AuthService);

  private registrationData: any;

  isPasswordValid(pass: string): boolean {
    return isPasswordValid(pass);
  }

  ngOnInit() {
    // Get state passed from step 1
    const navigation = this.router.getCurrentNavigation();
    if (navigation?.extras?.state) {
      this.registrationData = navigation.extras.state;
    } else {
      // Fallback to history state
      this.registrationData = history.state;
    }

    if (!this.registrationData || !this.registrationData.username) {
      // Missing data, redirect back to step 1
      this.router.navigate(['/signup']);
    }
  }

  goBack() {
    this.router.navigate(['/signup'], { state: this.registrationData });
  }

  onSubmit() {
    if (!this.isPasswordValid(this.password) || this.password !== this.confirmPassword) return;

    this.loading.set(true);
    this.error.set('');

    this.authService
      .register({
        username: this.registrationData.username,
        email: this.registrationData.email,
        phoneNumber: this.registrationData.phoneNumber ? this.registrationData.phoneNumber : null,
        password: this.password,
      })
      .subscribe({
        next: () => {
          this.router.navigate(['/verify-email'], { 
            queryParams: { email: this.registrationData.email, username: this.registrationData.username } 
          });
        },
        error: () => {
          this.error.set(
            'Unable to create account. Please try again.',
          );
          this.loading.set(false);
        },
      });
  }
}
