import { Component, inject, signal, OnInit, OnDestroy, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
import { Subject } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { Country } from '../../../shared/models/country.model';
import {
  OnlyNumbersDirective,
  isPasswordValid,
  resetFormFields,
  buildFormFields,
  mapValidationErrors,
  COUNTRIES,
  handleUsernameInput,
  handleEmailInput,
  handlePhoneInput,
} from '../../../shared';
import { CountrySelectorComponent } from '../../../shared/components/country-selector/country-selector.component';
import { PasswordFieldGroupComponent } from './components/password-field-group/password-field-group.component';
import { PasswordPolicyModalComponent } from '../../../shared/components/password-policy-modal/password-policy-modal.component';

@Component({
  selector: 'app-signup',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    RouterLink,
    NavbarComponent,
    OnlyNumbersDirective,
    CountrySelectorComponent,
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
            <div class="p-8 pb-0">
              <h1 class="text-2xl font-bold text-primary-900 dark:text-white mb-2">
                Create your account
              </h1>
              <p class="text-primary-600 dark:text-primary-400 text-sm">
                Start creating professional voiceovers today
              </p>
            </div>

            <div class="p-8">
              <form (submit)="onSubmit()" class="space-y-5">
                <div>
                  <label
                    class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                    >Username</label
                  >
                  <input
                    [(ngModel)]="username"
                    (input)="onUsernameInput()"
                    name="username"
                    type="text"
                    required
                    placeholder="johndoe"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase"
                    [ngClass]="{ 'border-red-500': usernameTaken() }"
                  />
                  @if (usernameTaken()) {
                    <p class="text-xs text-red-500 mt-1">Username is already taken</p>
                  }
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                    >Email</label
                  >
                  <input
                    [(ngModel)]="email"
                    (input)="onEmailInput()"
                    name="email"
                    type="email"
                    required
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase"
                    [ngClass]="{ 'border-red-500': emailTaken() }"
                  />
                  @if (emailTaken()) {
                    <p class="text-xs text-red-500 mt-1">Email is already taken</p>
                  }
                </div>

                <div class="relative">
                  <label
                    class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                    >Phone Number</label
                  >
                  <div class="flex items-stretch gap-2">
                    <app-country-selector
                      [(selectedCountry)]="selectedCountry"
                      [phoneSubject]="phoneSubject"
                      [phoneNumber]="phoneNumber"
                    >
                    </app-country-selector>

                    <input
                      [(ngModel)]="phoneNumber"
                      (input)="onPhoneInput()"
                      appOnlyNumbers
                      name="phoneNumber"
                      type="tel"
                      required
                      inputmode="numeric"
                      pattern="[0-9]*"
                      placeholder="9876543210"
                      class="flex-1 min-w-0 px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white text-sm placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                      [ngClass]="{ 'border-red-500': phoneTaken() }"
                    />
                  </div>
                  @if (phoneTaken()) {
                    <p class="text-xs text-red-500 mt-1">Phone number is already taken</p>
                  }
                </div>

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

                <div class="flex items-start gap-3 mt-6">
                  <input
                    type="checkbox"
                    [(ngModel)]="acceptedTerms"
                    name="acceptedTerms"
                    id="acceptedTerms"
                    required
                    class="mt-1 w-4 h-4 rounded border-primary-300 text-brand-blue focus:ring-brand-blue/50"
                  />
                  <label
                    for="acceptedTerms"
                    class="text-xs text-primary-600 dark:text-primary-400 leading-relaxed"
                  >
                    I agree to the
                    <a routerLink="/terms" class="text-brand-blue font-semibold hover:underline"
                      >Terms of Service</a
                    >
                    and
                    <a routerLink="/privacy" class="text-brand-blue font-semibold hover:underline"
                      >Privacy Policy</a
                    >
                    and consent to the processing of my data as per the DPDP Act 2023.
                  </label>
                </div>

                <button
                  type="submit"
                  [disabled]="
                    loading() ||
                    !username ||
                    !email ||
                    !phoneNumber ||
                    usernameTaken() ||
                    emailTaken() ||
                    phoneTaken() ||
                    !isPasswordValid(password) ||
                    password !== confirmPassword ||
                    !acceptedTerms
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

                <p class="text-center text-sm text-primary-600 dark:text-primary-400 mt-6">
                  Already have an account?
                  <a
                    [routerLink]="['/login']"
                    [queryParams]="pendingRedirect ? { redirect: pendingRedirect } : {}"
                    class="text-brand-blue font-bold hover:underline"
                    >Sign in</a
                  >
                </p>
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
  `,
})
export class SignupComponent implements OnInit, OnDestroy {
  username = '';
  email = '';
  phoneNumber = '';
  password = '';
  confirmPassword = '';
  acceptedTerms = false;
  showPolicyModal = signal(false);
  loading = signal(false);
  error = signal('');

  usernameTaken = signal(false);
  emailTaken = signal(false);
  phoneTaken = signal(false);

  private destroy$ = new Subject<void>();
  usernameSubject = new Subject<string>();
  emailSubject = new Subject<string>();
  phoneSubject = new Subject<string>();

  private formSetup = buildFormFields();
  selectedCountry: Country = this.formSetup.defaultCountry;
  countries = this.formSetup.countries;

  private authService = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  isPasswordValid(pass: string): boolean {
    return isPasswordValid(pass);
  }

  pendingPlan = '';
  pendingRedirect = '';

  ngOnInit(): void {
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/tts']);
    }
    this.pendingPlan = this.route.snapshot.queryParams['plan'] || '';
    this.pendingRedirect = this.route.snapshot.queryParams['redirect'] || '';

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
    });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  onUsernameInput() {
    this.username = handleUsernameInput(this.username, this.usernameSubject);
  }

  onEmailInput() {
    this.email = handleEmailInput(this.email, this.emailSubject);
  }

  onPhoneInput() {
    this.phoneNumber = handlePhoneInput(this.phoneNumber, this.phoneSubject);
  }

  onSubmit(): void {
    if (this.usernameTaken() || this.emailTaken() || this.phoneTaken()) return;
    if (
      !this.username ||
      !this.email ||
      !this.phoneNumber ||
      !this.password ||
      this.password !== this.confirmPassword
    )
      return;

    this.loading.set(true);
    this.error.set('');

    const countryCode = this.selectedCountry.code;
    let cleanLocalNumber = this.phoneNumber;
    const dialDigits = countryCode.replace('+', '');
    if (cleanLocalNumber.startsWith(dialDigits)) {
      cleanLocalNumber = cleanLocalNumber.substring(dialDigits.length);
    }
    const fullPhoneNumber = countryCode + cleanLocalNumber;

    this.authService
      .register({
        username: this.username,
        email: this.email,
        phoneNumber: fullPhoneNumber,
        password: this.password,
      })
      .subscribe({
        next: () => {
          this.router.navigate(['/verify-email'], { queryParams: { email: this.email, username: this.username } });
        },
        error: () => {
          this.error.set(
            'Unable to create account. Username, email, or phone may already be in use.',
          );
          this.loading.set(false);
        },
      });
  }
}
