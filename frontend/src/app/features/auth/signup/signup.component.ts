/**
 * User registration page component handling new
 * account creation and automatic login on success.
 */
import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormControl, FormGroup, Validators } from '@angular/forms';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { NgxIntlTelInputModule, CountryISO, SearchCountryField, PhoneNumberFormat } from 'ngx-intl-tel-input';

@Component({
  selector: 'app-signup',
  standalone: true,
  imports: [CommonModule, FormsModule, ReactiveFormsModule, RouterLink, NavbarComponent, NgxIntlTelInputModule],
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
              <form [formGroup]="signupForm" (ngSubmit)="onSubmit()" class="space-y-6">
                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Username</label>
                  <input formControlName="username" type="text" required
                    placeholder="johndoe"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase">
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Email</label>
                  <input formControlName="email" type="email" required
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase">
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Phone Number</label>
                  <div class="intl-tel-input-container">
                    <ngx-intl-tel-input
                      [cssClass]="'w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all'"
                      [preferredCountries]="preferredCountries"
                      [enableAutoCountrySelect]="true"
                      [enablePlaceholder]="true"
                      [searchCountryFlag]="true"
                      [searchCountryField]="[SearchCountryField.Iso2, SearchCountryField.Name]"
                      [selectFirstCountry]="false"
                      [selectedCountryISO]="CountryISO.India"
                      [maxLength]="15"
                      [phoneValidation]="true"
                      [separateDialCode]="true"
                      [numberFormat]="PhoneNumberFormat.International"
                      formControlName="phone">
                    </ngx-intl-tel-input>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Password</label>
                  <div class="relative">
                    <input formControlName="password" [type]="showPassword() ? 'text' : 'password'" required
                      placeholder="••••••••"
                      class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
                    <button type="button" (click)="togglePassword()" 
                      class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 dark:hover:text-primary-300 transition-colors">
                      <svg *ngIf="!showPassword()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>
                      <svg *ngIf="showPassword()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"></path></svg>
                    </button>
                  </div>
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

                <button type="submit" [disabled]="loading() || signupForm.invalid"
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
  `,
  styles: [`
    :host ::ng-deep .iti {
      display: block;
    }
    :host ::ng-deep .iti__country-list {
      max-width: 300px;
    }
  `]
})
export class SignupComponent implements OnInit {
  // Config for tel input
  SearchCountryField = SearchCountryField;
  CountryISO = CountryISO;
  PhoneNumberFormat = PhoneNumberFormat;
  preferredCountries: CountryISO[] = [CountryISO.India, CountryISO.UnitedStates, CountryISO.UnitedKingdom];

  signupForm = new FormGroup({
    username: new FormControl('', [Validators.required]),
    email: new FormControl('', [Validators.required, Validators.email]),
    phone: new FormControl(null, [Validators.required]),
    password: new FormControl('', [Validators.required, Validators.minLength(8)])
  });

  showPassword = signal(false);
  loading = signal(false);
  error = signal('');

  private authService = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  pendingPlan = '';

  ngOnInit(): void {
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/tts']);
    }
    this.pendingPlan = this.route.snapshot.queryParams['plan'] || '';
  }

  togglePassword(): void {
    this.showPassword.update(v => !v);
  }

  onSubmit(): void {
    if (this.signupForm.invalid) return;

    this.loading.set(true);
    this.error.set('');

    const val = this.signupForm.value;
    
    // ngx-intl-tel-input returns a specific object, but if numberFormat is E164, 
    // it usually populates the control with the string if using specific versions.
    // However, let's play it safe.
    const phoneValue: any = val.phone;
    const fullPhoneNumber = phoneValue?.e164Number || phoneValue?.internationalNumber || '';

    this.authService.register({ 
      username: val.username || '', 
      email: val.email || '', 
      phoneNumber: fullPhoneNumber,
      password: val.password || ''
    }).subscribe({
      next: () => {
        if (this.pendingPlan) {
          this.router.navigate(['/tts'], { queryParams: { autostart: this.pendingPlan } });
        } else {
          this.router.navigate(['/tts']);
        }
      },
      error: () => {
        this.error.set('Unable to create account. Username, email, or phone may already be in use.');
        this.loading.set(false);
      }
    });
  }
}
