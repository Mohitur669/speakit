import { Component, inject, signal, OnInit, HostListener, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { Subject } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { Country } from '../../../shared/models/country.model';
import { 
  OnlyNumbersDirective, 
  isPasswordValid, 
  resetFormFields, 
  mapValidationErrors, 
  COUNTRIES 
} from '../../../shared';

@Component({
  selector: 'app-profile-settings',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent, OnlyNumbersDirective],

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

        <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden">
          <div class="p-8">
            <form (submit)="onSubmit()" class="space-y-8">
              
              <!-- Personal Information Section -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="space-y-2">
                  <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300">Username</label>
                  <input [(ngModel)]="username" (input)="onUsernameInput()" name="username" type="text" required
                    placeholder="johndoe"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50 transition-all lowercase"
                    [ngClass]="{'border-red-500': usernameTaken()}">
                  <p *ngIf="usernameTaken()" class="text-xs text-red-500 mt-1">Username is already taken</p>
                </div>

                <div class="space-y-2">
                  <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300">Email Address</label>
                  <input [(ngModel)]="email" (input)="onEmailInput()" name="email" type="email" required
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50 transition-all lowercase"
                    [ngClass]="{'border-red-500': emailTaken()}">
                  <p *ngIf="emailTaken()" class="text-xs text-red-500 mt-1">Email is already taken</p>
                </div>

                <!-- Custom International Phone Input -->
                <div class="relative">
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Phone Number</label>
                  <div class="flex items-stretch gap-2">
                    <!-- Custom Searchable Select -->
                    <div class="relative w-20 flex-shrink-0">
                      <button type="button" (click)="toggleDropdown($event)"
                        class="w-full h-full flex items-center justify-between gap-1 px-2 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white transition-all text-xs sm:text-sm hover:border-brand-blue/50">
                        <span class="flex items-center gap-1">
                          <span>{{ selectedCountry().flag }}</span>
                          <span class="font-medium">{{ selectedCountry().code }}</span>
                        </span>
                        <svg class="w-3 h-3 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
                      </button>

                      <!-- Dropdown -->
                      <div *ngIf="showDropdown()" 
                        class="absolute top-full left-0 mt-2 w-64 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 rounded-xl shadow-2xl z-[100] overflow-hidden animate-fade-in">
                        <div class="p-2 border-b border-primary-100 dark:border-primary-800">
                          <input [(ngModel)]="searchQuery" name="search" type="text"
                            placeholder="Search country..."
                            (click)="$event.stopPropagation()"
                            class="w-full px-3 py-2 rounded-lg bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-xs text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50">
                        </div>
                        <div class="max-h-60 overflow-y-auto custom-scrollbar">
                          <button *ngFor="let c of filteredCountries()" type="button"
                            (click)="selectCountry(c, $event)"
                            class="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-left hover:bg-primary-50 dark:hover:bg-primary-800/50 transition-colors group">
                            <span class="text-lg">{{ c.flag }}</span>
                            <span class="flex-grow text-primary-700 dark:text-primary-200">{{ c.name }}</span>
                            <span class="text-xs font-bold text-primary-400 group-hover:text-brand-blue">{{ c.code }}</span>
                          </button>
                        </div>
                      </div>
                    </div>

                    <!-- Number Input -->
                    <input [(ngModel)]="phoneNumber" (input)="onPhoneInput()" appOnlyNumbers name="phoneNumber" type="tel"
                      inputmode="numeric" pattern="[0-9]*"
                      placeholder="9876543210"
                      class="flex-1 min-w-0 px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white text-sm placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                      [ngClass]="{'border-red-500': phoneTaken()}">
                  </div>
                  <p *ngIf="phoneTaken()" class="text-xs text-red-500 mt-1">Phone number is already taken</p>
                </div>
              </div>

              <hr class="border-primary-100 dark:border-primary-800">

              <!-- Security Section -->
              <div class="space-y-6">
                <div class="flex items-center justify-between">
                  <h2 class="text-xl font-bold text-primary-900 dark:text-white">Security</h2>
                  <button type="button" (click)="togglePasswordFields()" 
                    class="text-sm font-semibold text-brand-blue hover:text-brand-blue/80 transition-colors">
                    {{ showPasswordFields() ? 'Cancel Password Change' : 'Update Password' }}
                  </button>
                </div>
                
                <div class="space-y-2">
                  <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300">Current Password (required to save changes)</label>
                  <div class="relative">
                    <input [(ngModel)]="currentPassword" name="currentPassword" [type]="showCurrPass() ? 'text' : 'password'" required
                      placeholder="••••••••"
                      class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50 transition-all">
                    <button type="button" (click)="showCurrPass.set(!showCurrPass())"
                      class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 transition-colors">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path *ngIf="!showCurrPass()" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0zM2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                        <path *ngIf="showCurrPass()" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"></path>
                      </svg>
                    </button>
                  </div>
                </div>

                <div *ngIf="showPasswordFields()" class="grid grid-cols-1 md:grid-cols-2 gap-6 animate-fade-in">
                  <div class="space-y-2">
                    <div class="flex items-center justify-between">
                      <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300">New Password</label>
                      <button type="button" (click)="showPolicyModal.set(true)" class="text-[10px] font-bold text-brand-blue hover:underline">
                        Password Policy
                      </button>
                    </div>
                    <div class="relative">
                      <input [(ngModel)]="newPassword" name="newPassword" [type]="showNewPass() ? 'text' : 'password'"
                        placeholder="Enter new password"
                        class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50 transition-all">
                      <button type="button" (click)="showNewPass.set(!showNewPass())"
                        class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 transition-colors">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path *ngIf="!showNewPass()" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0zM2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                          <path *ngIf="showNewPass()" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"></path>
                        </svg>
                      </button>
                    </div>
                    
                    <!-- Unmet Password Requirements -->
                    <div *ngIf="newPassword && !isPasswordValid(newPassword)" class="mt-2 space-y-1">
                      <ng-container *ngFor="let req of getPasswordRequirements(newPassword)">
                        <div *ngIf="!req.met" class="flex items-center gap-1.5 text-red-500 animate-fade-in">
                          <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                          <span class="text-[10px] font-medium leading-none">{{ req.label }} required</span>
                        </div>
                      </ng-container>
                    </div>
                  </div>

                  <!-- Password Policy Modal -->
                  <div *ngIf="showPolicyModal()" class="fixed inset-0 z-[110] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in" (click)="showPolicyModal.set(false)">
                    <div class="bg-white dark:bg-primary-900 rounded-2xl p-6 w-full max-w-xs border border-primary-200 dark:border-primary-700 shadow-2xl animate-scale-up" (click)="$event.stopPropagation()">
                      <div class="flex items-center justify-between mb-4">
                        <h3 class="text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider">Password Policy</h3>
                        <button (click)="showPolicyModal.set(false)" class="p-1 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 transition-colors">
                          <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                        </button>
                      </div>
                      <div class="space-y-3">
                        <div *ngFor="let req of getPasswordRequirements(newPassword)" class="flex items-center gap-3">
                          <div class="w-5 h-5 rounded-full flex items-center justify-center transition-colors"
                            [ngClass]="req.met ? 'bg-green-500 text-white' : 'bg-primary-100 dark:bg-primary-800 text-primary-400'">
                            <svg *ngIf="req.met" class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                            <svg *ngIf="!req.met" class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m0 0v2m0-2h2m-2 0H10m1-11a4 4 0 00-4 4v3H5v7h14v-7h-2V8a4 4 0 00-4-4z"></path></svg>
                          </div>
                          <span class="text-xs font-medium" [ngClass]="req.met ? 'text-green-600 dark:text-green-400' : 'text-primary-600 dark:text-primary-300'">{{ req.label }}</span>
                        </div>
                      </div>
                      <button (click)="showPolicyModal.set(false)" class="w-full mt-6 py-2 bg-brand-blue text-white text-xs font-bold rounded-xl shadow-lg active:scale-95 transition-all">
                        Got it
                      </button>
                    </div>
                  </div>
                  
                  <div class="space-y-2">
                    <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300">Confirm New Password</label>
                    <div class="relative">
                      <input [(ngModel)]="confirmPassword" name="confirmPassword" [type]="showConfirmPass() ? 'text' : 'password'"
                        placeholder="Repeat new password"
                        class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50 transition-all"
                        [ngClass]="{'border-red-500': newPassword && confirmPassword && newPassword !== confirmPassword}">
                      <button type="button" (click)="showConfirmPass.set(!showConfirmPass())"
                        class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 transition-colors">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path *ngIf="!showConfirmPass()" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0zM2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                          <path *ngIf="showConfirmPass()" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"></path>
                        </svg>
                      </button>
                    </div>
                    <div *ngIf="confirmPassword" class="mt-1">
                      <p *ngIf="newPassword !== confirmPassword" class="text-xs text-red-500 flex items-center gap-1">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                        Passwords do not match
                      </p>
                      <p *ngIf="newPassword === confirmPassword" class="text-xs text-green-500 flex items-center gap-1">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                        Passwords match
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div *ngIf="error()" class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/30 text-sm text-red-600 dark:text-red-400 flex items-center gap-2">
                <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                {{ error() }}
              </div>

              <div class="flex justify-end gap-4 pt-4">
                <button type="button" routerLink="/tts" class="px-6 py-3 rounded-xl font-semibold text-primary-600 dark:text-primary-400 hover:bg-primary-100 dark:hover:bg-primary-800 transition-all">
                  Cancel
                </button>
                <button type="submit" [disabled]="loading() || !username || !email || !phoneNumber || !currentPassword || usernameTaken() || emailTaken() || phoneTaken() || (showPasswordFields() && (!newPassword || !isPasswordValid(newPassword) || newPassword !== confirmPassword))"
                  class="px-8 py-3 rounded-xl font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-xl active:scale-[0.98] flex items-center justify-center gap-2">
                  <svg *ngIf="loading()" class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg>
                  Save Changes
                </button>
              </div>
            </form>
          </div>
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
  showPasswordFields = signal(false);
  showNewPass = signal(false);
  showCurrPass = signal(false);
  showConfirmPass = signal(false);
  showPolicyModal = signal(false);

  usernameTaken = signal(false);
  emailTaken = signal(false);
  phoneTaken = signal(false);

  private destroy$ = new Subject<void>();
  private usernameSubject = new Subject<string>();
  private emailSubject = new Subject<string>();
  private phoneSubject = new Subject<string>();

  showDropdown = signal(false);
  searchQuery = '';
  selectedCountry = signal<Country>({ name: 'India', code: '+91', flag: '🇮🇳' });

  countries = COUNTRIES;

  private authService = inject(AuthService);
  private router = inject(Router);

  getPasswordRequirements(pass: string) {
    return resetFormFields(pass);
  }

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
    const country = this.countries.find(c => rawPhone.startsWith(c.code));
    if (country) {
      this.selectedCountry.set(country);
      this.phoneNumber = rawPhone.substring(country.code.length);
    } else {
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
      selectedCountryCode: () => this.selectedCountry().code,
      currentUsername: this.username,
      currentEmail: this.email,
      currentPhone: rawPhone
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

  togglePasswordFields() {
    this.showPasswordFields.update(v => !v);
    if (!this.showPasswordFields()) {
      this.newPassword = '';
      this.confirmPassword = '';
    }
  }

  @HostListener('document:click')
  closeDropdown() {
    this.showDropdown.set(false);
  }

  toggleDropdown(event: Event) {
    toggleDropdown(event, this.showDropdown);
  }

  selectCountry(country: Country, event: Event) {
    selectCountry(country, event, this.selectedCountry, this.showDropdown, this.phoneSubject, this.phoneNumber);
    this.searchQuery = '';
  }


  filteredCountries() {
    if (!this.searchQuery) return this.countries;
    const s = this.searchQuery.toLowerCase();
    return this.countries.filter(c => c.name.toLowerCase().includes(s) || c.code.includes(s));
  }

  onSubmit(): void {
    this.loading.set(true);
    this.error.set('');

    const fullPhoneNumber = this.selectedCountry().code + this.phoneNumber.replace(/\D/g, '');

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
        // If password was changed, the user might be logged out automatically by the WS notification
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Failed to update profile. Please check your details.');
        this.loading.set(false);
      }
    });
  }
}
