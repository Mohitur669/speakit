/**
 * User registration page component handling new
 * account creation and automatic login on success.
 * Includes a custom searchable country code selector.
 */
import { Component, inject, signal, OnInit, HostListener, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
import { Subject, debounceTime, takeUntil } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';

interface Country {
  name: string;
  code: string;
  flag: string;
}

@Component({
  selector: 'app-signup',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="flex items-center justify-center px-4 py-16">
        <div class="w-full max-w-md animate-fade-in">
          <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden">
            <div class="p-8 pb-0">
              <h1 class="text-2xl font-bold text-primary-900 dark:text-white mb-2">Create your account</h1>
              <p class="text-primary-500 dark:text-primary-400 text-sm">Start creating professional voiceovers today</p>
            </div>

            <div class="p-8">
              <form (submit)="onSubmit()" class="space-y-5">
                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Username</label>
                  <input [(ngModel)]="username" (input)="onUsernameInput()" name="username" type="text" required
                    placeholder="johndoe"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase"
                    [ngClass]="{'border-red-500': usernameTaken()}">
                  <p *ngIf="usernameTaken()" class="text-xs text-red-500 mt-1">Username is already taken</p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Email</label>
                  <input [(ngModel)]="email" (input)="onEmailInput()" name="email" type="email" required
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase"
                    [ngClass]="{'border-red-500': emailTaken()}">
                  <p *ngIf="emailTaken()" class="text-xs text-red-500 mt-1">Email is already taken</p>
                </div>

                <div class="relative">
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Phone Number</label>
                  <div class="flex items-stretch gap-2">
                    <!-- Custom Searchable Select -->
                    <div class="relative w-20 flex-shrink-0">
                      <button type="button" (click)="toggleDropdown($event)"
                        class="w-full h-full flex items-center justify-between gap-1 px-2 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white transition-all text-xs sm:text-sm hover:border-brand-blue/50">
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
                    <input [(ngModel)]="phoneNumber" (input)="onPhoneInput()" (keypress)="onlyNumbers($event)" name="phoneNumber" type="tel" required
                      inputmode="numeric" pattern="[0-9]*"
                      placeholder="9876543210"
                      class="flex-1 min-w-0 px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white text-sm placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                      [ngClass]="{'border-red-500': phoneTaken()}">
                  </div>
                  <p *ngIf="phoneTaken()" class="text-xs text-red-500 mt-1">Phone number is already taken</p>
                </div>

                <div>
                  <div class="flex items-center justify-between mb-2">
                    <label class="block text-sm font-medium text-primary-700 dark:text-primary-300">Password</label>
                    <button type="button" (click)="showPolicyModal.set(true)" class="text-[10px] font-bold text-brand-blue hover:underline">
                      Password Policy
                    </button>
                  </div>
                  <div class="relative">
                    <input [(ngModel)]="password" name="password" [type]="showPassword() ? 'text' : 'password'" required
                      placeholder="••••••••"
                      class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
                    <button type="button" (click)="togglePassword()"
                      class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 dark:hover:text-primary-300 transition-colors">
                      <svg *ngIf="!showPassword()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>
                      <svg *ngIf="showPassword()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"></path></svg>
                    </button>
                  </div>
                  
                  <!-- Unmet Password Requirements -->
                  <div *ngIf="password && !isPasswordValid(password)" class="mt-2 space-y-1">
                    <ng-container *ngFor="let req of getPasswordRequirements(password)">
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
                      <div *ngFor="let req of getPasswordRequirements(password)" class="flex items-center gap-3">
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

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Confirm Password</label>
                  <div class="relative">
                    <input [(ngModel)]="confirmPassword" name="confirmPassword" [type]="showConfirmPassword() ? 'text' : 'password'" required
                      placeholder="••••••••"
                      class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                      [ngClass]="{'border-red-500': password && confirmPassword && password !== confirmPassword}">
                    <button type="button" (click)="showConfirmPassword.set(!showConfirmPassword())"
                      class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 dark:hover:text-primary-300 transition-colors">
                      <svg *ngIf="!showConfirmPassword()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>
                      <svg *ngIf="showConfirmPassword()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"></path></svg>
                    </button>
                  </div>
                  <div *ngIf="confirmPassword" class="mt-1">
                    <p *ngIf="password !== confirmPassword" class="text-xs text-red-500 flex items-center gap-1">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                      Passwords do not match
                    </p>
                    <p *ngIf="password === confirmPassword" class="text-xs text-green-500 flex items-center gap-1">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                      Passwords match
                    </p>
                  </div>
                </div>

                <div *ngIf="error()" class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/30">
                  <p class="text-sm text-red-600 dark:text-red-400 flex items-center gap-2">
                    <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    {{ error() }}
                  </p>
                </div>

                <button type="submit" [disabled]="loading() || !username || !email || !phoneNumber || usernameTaken() || emailTaken() || phoneTaken() || !isPasswordValid(password) || password !== confirmPassword"
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
                  <span class="px-4 text-xs text-primary-400 bg-white dark:bg-primary-900 uppercase tracking-widest">or</span>
                </div>
              </div>

              <p class="text-center text-primary-500 dark:text-primary-400 text-sm">
                Already have an account?
                <a routerLink="/login" class="font-bold text-brand-blue hover:text-brand-blue/80 transition-colors">Sign in</a>
              </p>
            </div>
          </div>

          <p class="text-center text-xs text-primary-400 mt-8 leading-relaxed opacity-70">
            By creating an account, you agree to our <a class="underline">Terms</a> and <a class="underline">Privacy Policy</a>.
          </p>
        </div>
      </div>
    </div>
  `
})
export class SignupComponent implements OnInit, OnDestroy {
  username = '';
  email = '';
  phoneNumber = '';
  password = '';
  confirmPassword = '';
  showPassword = signal(false);
  showConfirmPassword = signal(false);
  showPolicyModal = signal(false);
  loading = signal(false);
  error = signal('');

  usernameTaken = signal(false);
  emailTaken = signal(false);
  phoneTaken = signal(false);

  private destroy$ = new Subject<void>();
  private usernameSubject = new Subject<string>();
  private emailSubject = new Subject<string>();
  private phoneSubject = new Subject<string>();

  // Custom Country Selector State
  showDropdown = signal(false);
  searchQuery = '';
  selectedCountry = signal<Country>({ name: 'India', code: '+91', flag: '🇮🇳' });

  countries: Country[] = [
    { name: 'India', code: '+91', flag: '🇮🇳' },
    { name: 'United States', code: '+1', flag: '🇺🇸' },
    { name: 'United Kingdom', code: '+44', flag: '🇬🇧' },
    { name: 'Australia', code: '+61', flag: '🇦🇺' },
    { name: 'Canada', code: '+1', flag: '🇨🇦' },
    { name: 'China', code: '+86', flag: '🇨🇳' },
    { name: 'France', code: '+33', flag: '🇫🇷' },
    { name: 'Germany', code: '+49', flag: '🇩🇪' },
    { name: 'Japan', code: '+81', flag: '🇯🇵' },
    { name: 'Singapore', code: '+65', flag: '🇸🇬' },
    { name: 'United Arab Emirates', code: '+971', flag: '🇦🇪' },
    { name: 'Saudi Arabia', code: '+966', flag: '🇸🇦' },
    { name: 'Netherlands', code: '+31', flag: '🇳🇱' },
    { name: 'Ireland', code: '+353', flag: '🇮🇪' },
    { name: 'New Zealand', code: '+64', flag: '🇳🇿' },
    { name: 'South Africa', code: '+27', flag: '🇿🇦' },
    { name: 'Malaysia', code: '+60', flag: '🇲🇾' },
    { name: 'Indonesia', code: '+62', flag: '🇮🇩' },
    { name: 'Thailand', code: '+66', flag: '🇹🇭' },
  ];

  filteredCountries() {
    if (!this.searchQuery) return this.countries;
    const s = this.searchQuery.toLowerCase();
    return this.countries.filter(c => c.name.toLowerCase().includes(s) || c.code.includes(s));
  }

  private authService = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  getPasswordRequirements(pass: string) {
    return [
      { label: '8+ Characters', met: pass.length >= 8 },
      { label: 'Lowercase (a-z)', met: /[a-z]/.test(pass) },
      { label: 'Uppercase (A-Z)', met: /[A-Z]/.test(pass) },
      { label: 'Numbers (0-9)', met: /[0-9]/.test(pass) },
      { label: 'Special Char (!@#)', met: /[!@#$%^&*(),.?":{}|<>]/.test(pass) }
    ];
  }

  isPasswordValid(pass: string): boolean {
    return pass.length >= 8 &&
           /[a-z]/.test(pass) &&
           /[A-Z]/.test(pass) &&
           /[0-9]/.test(pass) &&
           /[!@#$%^&*(),.?":{}|<>]/.test(pass);
  }

  pendingPlan = '';

  ngOnInit(): void {
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/tts']);
    }
    this.pendingPlan = this.route.snapshot.queryParams['plan'] || '';
    this.setupAvailabilityChecks();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  private setupAvailabilityChecks() {
    this.usernameSubject.pipe(debounceTime(500), takeUntil(this.destroy$)).subscribe(val => {
      if (!val) {
        this.usernameTaken.set(false);
        return;
      }
      this.authService.checkUsername(val).subscribe(taken => this.usernameTaken.set(taken));
    });

    this.emailSubject.pipe(debounceTime(500), takeUntil(this.destroy$)).subscribe(val => {
      if (!val) {
        this.emailTaken.set(false);
        return;
      }
      this.authService.checkEmail(val).subscribe(taken => this.emailTaken.set(taken));
    });

    this.phoneSubject.pipe(debounceTime(500), takeUntil(this.destroy$)).subscribe(val => {
      const fullPhone = this.selectedCountry().code + val.replace(/\D/g, '');
      if (!val) {
        this.phoneTaken.set(false);
        return;
      }
      this.authService.checkPhone(fullPhone).subscribe(taken => this.phoneTaken.set(taken));
    });
  }

  onUsernameInput() {
    this.username = this.username.toLowerCase();
    this.usernameSubject.next(this.username);
  }

  onEmailInput() {
    this.email = this.email.toLowerCase();
    this.emailSubject.next(this.email);
  }

  onPhoneInput() {
    this.phoneNumber = this.phoneNumber.replace(/\D/g, '');
    this.phoneSubject.next(this.phoneNumber);
  }

  onlyNumbers(event: KeyboardEvent) {
    const charCode = event.which ? event.which : event.keyCode;
    if (charCode > 31 && (charCode < 48 || charCode > 57)) {
      event.preventDefault();
    }
  }

  @HostListener('document:click')
  closeDropdown() {
    this.showDropdown.set(false);
  }

  toggleDropdown(event: Event) {
    event.stopPropagation();
    this.showDropdown.update(v => !v);
  }

  selectCountry(country: Country, event: Event) {
    event.stopPropagation();
    this.selectedCountry.set(country);
    this.showDropdown.set(false);
    this.searchQuery = '';
    this.phoneSubject.next(this.phoneNumber); // Re-check phone with new country code
  }

  togglePassword(): void {
    this.showPassword.update(v => !v);
  }

  onSubmit(): void {
    if (this.usernameTaken() || this.emailTaken() || this.phoneTaken()) return;
    if (!this.username || !this.email || !this.phoneNumber || !this.password || this.password !== this.confirmPassword) return;

    this.loading.set(true);
    this.error.set('');

    // Format: +CCXXXXXXXXXX
    const countryCode = this.selectedCountry().code; // e.g. +91
    let cleanLocalNumber = this.phoneNumber; // already cleaned in onPhoneInput

    // Prevent double-prefixing: if local number starts with the dial code, strip it
    const dialDigits = countryCode.replace('+', '');
    if (cleanLocalNumber.startsWith(dialDigits)) {
      cleanLocalNumber = cleanLocalNumber.substring(dialDigits.length);
    }

    const fullPhoneNumber = countryCode + cleanLocalNumber;

    this.authService.register({
      username: this.username,
      email: this.email,
      phoneNumber: fullPhoneNumber,
      password: this.password
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
