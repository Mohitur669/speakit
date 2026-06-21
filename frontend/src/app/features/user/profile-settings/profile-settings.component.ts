import { Component, inject, signal, OnInit, OnDestroy } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { Subject } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { Country } from '../../../shared/models/country.model';
import { isPasswordValid, mapValidationErrors, COUNTRIES, buildFormFields } from '../../../shared';
import { ProfileFormComponent } from './components/profile-form/profile-form.component';
import { PasswordFormComponent } from './components/password-form/password-form.component';
import { PasswordPolicyModalComponent } from '../../../shared/components/password-policy-modal/password-policy-modal.component';

@Component({
  selector: 'app-profile-settings',
  standalone: true,
  imports: [
    FormsModule,
    RouterLink,
    NavbarComponent,
    ProfileFormComponent,
    PasswordFormComponent,
    PasswordPolicyModalComponent,
  ],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="max-w-4xl mx-auto px-4 py-12">
        <div class="mb-8 flex items-start justify-between">
          <div>
            <h1 class="text-3xl font-bold text-primary-900 dark:text-white mb-2">
              Profile Settings
            </h1>
            <p class="text-primary-500 dark:text-primary-400">
              Update your account details and security preferences.
            </p>
          </div>
          <button
            routerLink="/tts"
            class="p-2 rounded-xl text-primary-400 hover:text-primary-600 dark:hover:text-primary-200 hover:bg-white dark:hover:bg-primary-900 border border-transparent hover:border-primary-200 dark:hover:border-primary-700 transition-all group shadow-sm hover:shadow-md"
            title="Back to Studio"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              ></path>
            </svg>
          </button>
        </div>

        <div
          class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden"
        >
          <div class="p-8">
            <form (submit)="onSubmit()" class="space-y-8">
              <div>
                <app-profile-form
                  [(username)]="username"
                  [(email)]="email"
                  [(phoneNumber)]="phoneNumber"
                  [(selectedCountry)]="selectedCountry"
                  [usernameTaken]="usernameTaken()"
                  [emailTaken]="emailTaken()"
                  [phoneTaken]="phoneTaken()"
                  [usernameSubject]="usernameSubject"
                  [emailSubject]="emailSubject"
                  [phoneSubject]="phoneSubject"
                >
                </app-profile-form>
              </div>

              <div>
                <app-password-form
                  [(currentPassword)]="currentPassword"
                  [(newPassword)]="newPassword"
                  [(confirmPassword)]="confirmPassword"
                  (showPolicyModal)="showPolicyModal.set($event)"
                >
                </app-password-form>
              </div>

              @if (error()) {
                <div
                  class="p-4 rounded-xl bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm animate-fade-in"
                >
                  {{ error() }}
                </div>
              }

              <div
                class="flex items-center justify-end gap-4 pt-4 border-t border-primary-100 dark:border-primary-800"
              >
                <button
                  type="button"
                  routerLink="/tts"
                  class="px-6 py-3 rounded-xl bg-primary-100 dark:bg-primary-800 text-primary-700 dark:text-primary-200 font-bold hover:bg-primary-200 dark:hover:bg-primary-700 transition-all active:scale-95 shadow-sm"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  [disabled]="
                    loading() ||
                    !currentPassword ||
                    usernameTaken() ||
                    emailTaken() ||
                    phoneTaken() ||
                    (newPassword &&
                      (!isPasswordValid(newPassword) || newPassword !== confirmPassword))
                  "
                  class="px-8 py-3 rounded-xl bg-brand-blue hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold shadow-lg shadow-brand-blue/20 transition-all active:scale-95"
                >
                  {{ loading() ? 'Saving Changes...' : 'Save Changes' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>

    @if (showPolicyModal()) {
      <app-password-policy-modal [password]="newPassword" (close)="showPolicyModal.set(false)">
      </app-password-policy-modal>
    }
  `,
})
export class ProfileSettingsComponent implements OnInit, OnDestroy {
  username = '';
  email = '';
  phoneNumber = '';
  currentPassword = '';
  newPassword = '';
  confirmPassword = '';

  loading = signal(false);
  error = signal('');
  showPolicyModal = signal(false);

  usernameTaken = signal(false);
  emailTaken = signal(false);
  phoneTaken = signal(false);

  private destroy$ = new Subject<void>();
  usernameSubject = new Subject<string>();
  emailSubject = new Subject<string>();
  phoneSubject = new Subject<string>();

  private formSetup = buildFormFields();
  selectedCountry!: Country;
  countries = this.formSetup.countries;

  authService = inject(AuthService);
  private router = inject(Router);

  isPasswordValid(pass: string): boolean {
    return isPasswordValid(pass);
  }

  ngOnInit(): void {
    if (!this.authService.isLoggedIn()) {
      this.router.navigate(['/login']);
      return;
    }

    this.username = this.authService.currentUser() || '';
    this.email = this.authService.currentUserEmail() || '';
    const rawPhone = this.authService.currentUserPhone() || '';

    // Attempt to extract country code from stored phone
    const country = this.countries.find((c: Country) => rawPhone.startsWith(c.code));

    if (country) {
      this.selectedCountry = country;
      this.phoneNumber = rawPhone.substring(country.code.length);
    } else {
      this.selectedCountry = this.countries[0];
      this.phoneNumber = rawPhone;
    }

    mapValidationErrors({
      usernameSubject: this.usernameSubject,
      emailSubject: this.emailSubject,
      phoneSubject: this.phoneSubject,
      usernameTaken: this.usernameTaken,
      emailTaken: this.emailTaken,
      phoneTaken: this.phoneTaken,
      destroy$: this.destroy$,
      authService: this.authService,
      selectedCountryCode: () => this.selectedCountry.code,
      currentUsername: this.username,
      currentEmail: this.email,
      currentPhone: rawPhone,
    });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  onSubmit(): void {
    this.loading.set(true);
    this.error.set('');

    const fullPhoneNumber = this.selectedCountry.code + this.phoneNumber.replace(/\D/g, '');

    const request = {
      username: this.username,
      email: this.email,
      phoneNumber: fullPhoneNumber,
      currentPassword: this.currentPassword,
      newPassword: this.newPassword,
    };

    this.authService.updateProfile(request).subscribe({
      next: () => {
        this.loading.set(false);
        this.currentPassword = '';
        this.newPassword = '';
      },
      error: (err) => {
        this.error.set(
          err.error?.message || 'Failed to update profile. Please check your details.',
        );
        this.loading.set(false);
      },
    });
  }
}
