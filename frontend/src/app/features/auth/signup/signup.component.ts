/**
 * User registration page component handling new
 * account creation and automatic login on success.
 * Includes a custom searchable country code selector.
 */
import { Component, inject, signal, OnInit, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
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
                  <input [(ngModel)]="username" (input)="username = username.toLowerCase()" name="username" type="text" required
                    placeholder="johndoe"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase">
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Email</label>
                  <input [(ngModel)]="email" (input)="email = email.toLowerCase()" name="email" type="email" required
                    placeholder="you@example.com"
                    class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase">
                </div>

                <!-- Custom International Phone Input -->
                <div class="relative">
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Phone Number</label>
                  <div class="flex items-center gap-2">
                    <!-- Custom Searchable Select -->
                    <div class="relative w-28 flex-shrink-0">
                      <button type="button" (click)="toggleDropdown($event)"
                        class="w-full flex items-center justify-between gap-1.5 px-3 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white transition-all text-sm hover:border-brand-blue/50">
                        <span class="flex items-center gap-1.5">
                          <span>{{ selectedCountry().flag }}</span>
                          <span class="font-medium">{{ selectedCountry().code }}</span>
                        </span>
                        <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
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
                    <input [(ngModel)]="phoneNumber" name="phoneNumber" type="tel" required
                      placeholder="9876543210"
                      class="flex-1 px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Password</label>
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
                  <p class="text-[10px] text-primary-400 mt-2 italic">Must be at least 8 characters</p>
                </div>

                <div *ngIf="error()" class="p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/30">
                  <p class="text-sm text-red-600 dark:text-red-400 flex items-center gap-2">
                    <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    {{ error() }}
                  </p>
                </div>

                <button type="submit" [disabled]="loading()"
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
export class SignupComponent implements OnInit {
  username = '';
  email = '';
  phoneNumber = '';
  password = '';
  showPassword = signal(false);
  loading = signal(false);
  error = signal('');

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
    { name: 'Germany', code: '+49', flag: '🇩🇪' },
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

  pendingPlan = '';

  ngOnInit(): void {
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/tts']);
    }
    this.pendingPlan = this.route.snapshot.queryParams['plan'] || '';
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
  }

  togglePassword(): void {
    this.showPassword.update(v => !v);
  }

  onSubmit(): void {
    this.loading.set(true);
    this.error.set('');

    // Format: +CCXXXXXXXXXX
    const countryCode = this.selectedCountry().code; // e.g. +91
    let cleanLocalNumber = this.phoneNumber.replace(/\D/g, '');
    
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
