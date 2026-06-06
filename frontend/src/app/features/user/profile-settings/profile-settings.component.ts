import { Component, inject, signal, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { Subject } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { Country } from '../../../shared/models/country.model';
import { 
  isPasswordValid, 
  mapValidationErrors, 
  COUNTRIES,
  buildFormFields
} from '../../../shared';
import { ProfileFormComponent } from './components/profile-form/profile-form.component';
import { PasswordFormComponent } from './components/password-form/password-form.component';
import { PlanInfoComponent } from './components/plan-info/plan-info.component';

@Component({
  selector: 'app-profile-settings',
  standalone: true,
  imports: [
    CommonModule, 
    FormsModule, 
    RouterLink, 
    NavbarComponent,
    ProfileFormComponent,
    PasswordFormComponent,
    PlanInfoComponent
  ],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="max-w-4xl mx-auto px-4 py-12">
        <div class="mb-8 flex items-start justify-between">
          <div>
            <h1 class="text-3xl font-bold text-primary-900 dark:text-white mb-2">Profile Settings</h1>
            <p class="text-primary-500 dark:text-primary-400">Update your account details and security preferences.</p>
          </div>
          <button routerLink="/tts" 
            class="p-2 rounded-xl text-primary-400 hover:text-primary-600 dark:hover:text-primary-200 hover:bg-white dark:hover:bg-primary-900 border border-transparent hover:border-primary-200 dark:hover:border-primary-700 transition-all group shadow-sm hover:shadow-md"
            title="Back to Studio">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <app-plan-info [planType]="authService.currentPlanType()"></app-plan-info>

        <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden">
          <div class="p-8">
            <form (submit)="onSubmit()" class="space-y-8">
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
                [phoneSubject]="phoneSubject">
              </app-profile-form>

              <app-password-form
                [(currentPassword)]="currentPassword"
                [(newPassword)]="newPassword"
                [(confirmPassword)]="confirmPassword"
                (showPolicyModal)="showPolicyModal.set($event)">
              </app-password-form>

              <div *ngIf="error()" class="p-4 rounded-xl bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm animate-fade-in">
                {{ error() }}
              </div>

              <div class="flex items-center justify-end gap-4 pt-4 border-t border-primary-100 dark:border-primary-800">
                <button type="button" routerLink="/tts" class="px-6 py-3 rounded-xl text-primary-600 dark:text-primary-400 font-medium hover:bg-primary-50 dark:hover:bg-primary-800 transition-all">
                  Cancel
                </button>
                <button type="submit" [disabled]="loading() || usernameTaken() || emailTaken() || phoneTaken() || (newPassword && !isPasswordValid(newPassword))"
                  class="px-8 py-3 rounded-xl bg-brand-blue hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold shadow-lg shadow-blue-500/25 transition-all">
                  {{ loading() ? 'Saving Changes...' : 'Save All Changes' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>

    <!-- Password Policy Modal -->
    <div *ngIf="showPolicyModal()" class="fixed inset-0 z-[200] flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-primary-950/60 backdrop-blur-sm" (click)="showPolicyModal.set(false)"></div>
      <div class="relative bg-white dark:bg-primary-900 rounded-2xl shadow-2xl w-full max-w-md overflow-hidden animate-scale-in">
        <div class="p-6 border-b border-primary-100 dark:border-primary-800 flex items-center justify-between">
          <h3 class="text-xl font-bold text-primary-900 dark:text-white">Password Policy</h3>
          <button (click)="showPolicyModal.set(false)" class="text-primary-400 hover:text-primary-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
          </button>
        </div>
        <div class="p-6 space-y-4">
          <p class="text-sm text-primary-600 dark:text-primary-400">To ensure the security of your account, your password must meet the following criteria:</p>
          <ul class="space-y-3">
            <li class="flex items-start gap-3 text-sm text-primary-700 dark:text-primary-300">
              <span class="w-5 h-5 rounded-full bg-blue-100 dark:bg-blue-900/40 text-brand-blue flex items-center justify-center text-xs font-bold shrink-0">1</span>
              At least 8 characters in length.
            </li>
            <li class="flex items-start gap-3 text-sm text-primary-700 dark:text-primary-300">
              <span class="w-5 h-5 rounded-full bg-blue-100 dark:bg-blue-900/40 text-brand-blue flex items-center justify-center text-xs font-bold shrink-0">2</span>
              Include at least one lowercase letter (a-z).
            </li>
            <li class="flex items-start gap-3 text-sm text-primary-700 dark:text-primary-300">
              <span class="w-5 h-5 rounded-full bg-blue-100 dark:bg-blue-900/40 text-brand-blue flex items-center justify-center text-xs font-bold shrink-0">3</span>
              Include at least one uppercase letter (A-Z).
            </li>
            <li class="flex items-start gap-3 text-sm text-primary-700 dark:text-primary-300">
              <span class="w-5 h-5 rounded-full bg-blue-100 dark:bg-blue-900/40 text-brand-blue flex items-center justify-center text-xs font-bold shrink-0">4</span>
              Include at least one number (0-9).
            </li>
            <li class="flex items-start gap-3 text-sm text-primary-700 dark:text-primary-300">
              <span class="w-5 h-5 rounded-full bg-blue-100 dark:bg-blue-900/40 text-brand-blue flex items-center justify-center text-xs font-bold shrink-0">5</span>
              Include at least one special character (e.g., ! @ # $ %).
            </li>
          </ul>
        </div>
        <div class="p-6 bg-primary-50 dark:bg-primary-800/50">
          <button (click)="showPolicyModal.set(false)" class="w-full py-3 rounded-xl bg-brand-blue text-white font-bold hover:bg-blue-600 transition-all">
            Got it, thanks!
          </button>
        </div>
      </div>
    </div>
  `
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
      currentPhone: rawPhone
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
      newPassword: this.newPassword
    };

    this.authService.updateProfile(request).subscribe({
      next: () => {
        this.loading.set(false);
        this.currentPassword = '';
        this.newPassword = '';
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Failed to update profile. Please check your details.');
        this.loading.set(false);
      }
    });
  }
}
