/**
 * Global navigation bar component with logo, nav links,
 * theme toggle, and authenticated user menu with logout.
 */
import { Component, inject, signal, HostListener, ViewChild, ElementRef, OnDestroy, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, Router, NavigationEnd } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { ThemeService } from '../../../core/services/theme.service';
import { filter } from 'rxjs/operators';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <header class="sticky top-0 z-50 w-full bg-white dark:bg-primary-900 border-b border-primary-200 dark:border-primary-800">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 gap-4">

          <!-- Logo -->
          <div class="flex items-center gap-1.5 sm:gap-2 min-w-0">
            <!-- Hamburger Button (Mobile Only) -->
            <button #hamburgerButton (click)="toggleMobileMenu($event)" 
              class="md:hidden flex flex-col justify-center items-center w-9 h-9 rounded-xl border transition-all shrink-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-blue select-none active:scale-[0.85]"
              [ngClass]="showMobileMenu() 
                ? 'bg-gradient-to-br from-brand-blue/10 via-brand-purple/10 to-accent-500/10 dark:from-brand-blue/20 dark:to-accent-500/20 border-brand-purple/30 dark:border-brand-purple/50 shadow-md shadow-brand-blue/5' 
                : 'bg-white dark:bg-primary-900 border-primary-200 dark:border-primary-800 hover:bg-primary-50 dark:hover:bg-primary-800 hover:border-primary-300 dark:hover:border-primary-700'"
              [attr.aria-expanded]="showMobileMenu()"
              aria-controls="mobile-menu-panel"
              [attr.aria-label]="showMobileMenu() ? 'Close menu' : 'Open menu'">
              <div class="w-5 h-4 flex flex-col justify-between relative overflow-hidden">
                <span class="w-full h-0.5 rounded-full transition-smooth origin-center"
                  [ngClass]="showMobileMenu() 
                    ? 'rotate-45 translate-y-[7px] bg-gradient-to-r from-brand-blue to-brand-purple' 
                    : 'bg-primary-600 dark:bg-primary-300'"></span>
                <span class="w-full h-0.5 rounded-full transition-smooth origin-center"
                  [ngClass]="showMobileMenu() 
                    ? 'translate-x-8 opacity-0 bg-gradient-to-r from-brand-blue to-brand-purple' 
                    : 'bg-primary-600 dark:bg-primary-300'"></span>
                <span class="w-full h-0.5 rounded-full transition-smooth origin-center"
                  [ngClass]="showMobileMenu() 
                    ? '-rotate-45 -translate-y-[7px] bg-gradient-to-r from-brand-blue to-brand-purple' 
                    : 'bg-primary-600 dark:bg-primary-300'"></span>
              </div>
            </button>

            <a routerLink="/" class="flex items-center gap-2 sm:gap-3 group shrink-0">
              <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center shadow-md group-hover:shadow-lg group-hover:scale-105 transition-all">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
                </svg>
              </div>
              <span class="text-base sm:text-lg font-semibold text-primary-900 dark:text-white tracking-tight">SpeakIT</span>
            </a>
          </div>

          <!-- Desktop Nav -->
          <nav class="hidden md:flex items-center gap-6 lg:gap-8">
            <ng-container *ngFor="let link of navLinks">
              <a [routerLink]="link.path" [fragment]="link.fragment"
                class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">
                {{ link.label }}
              </a>
            </ng-container>
          </nav>

          <!-- Actions -->
          <div class="flex items-center gap-2 sm:gap-3 shrink-0">
            <!-- Theme Toggle (Hidden on mobile/smaller screens) -->
            <button (click)="themeService.toggleTheme()"
              class="hidden sm:block p-2 rounded-lg text-primary-500 hover:text-primary-900 hover:bg-primary-50 dark:text-primary-400 dark:hover:text-white dark:hover:bg-primary-800 transition-all"
              aria-label="Toggle theme">
              <svg *ngIf="themeService.isDarkMode()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"></path>
              </svg>
              <svg *ngIf="!themeService.isDarkMode()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"></path>
              </svg>
            </button>

            <!-- User Menu -->
            <ng-container *ngIf="authService.currentUser() as user; else guest">
              <!-- Minimal Desktop Upgrade Link -->
              <a *ngIf="authService.currentPlanType() !== 'ENTERPRISE'" 
                [routerLink]="getNextPlan() === 'ENTERPRISE' ? '/contact' : '/tts'" 
                [queryParams]="getNextPlan() === 'ENTERPRISE' ? { topic: 'enterprise' } : { autostart: getNextPlan() }"
                class="hidden sm:flex items-center gap-1 px-2 py-1 text-accent-600 dark:text-accent-400 hover:text-accent-700 dark:hover:text-accent-300 transition-colors text-[10px] font-bold tracking-widest group/upg">
                <svg class="w-3.5 h-3.5 group-hover/upg:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
                <span>{{ getUpgradeText() }}</span>
              </a>

              <div class="flex items-center gap-2 sm:gap-3 relative">
                <!-- User Avatar + Menu Trigger -->
                <div (click)="toggleUserMenu($event)" 
                  class="flex items-center justify-center gap-2 sm:gap-3 h-9 px-3 rounded-full bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 cursor-pointer hover:border-brand-blue/50 transition-all select-none"
                  [ngClass]="{'bg-accent-50 dark:bg-accent-500/10 border-accent-200 dark:border-accent-500/30': authService.currentPlanType() !== 'FREE'}">
                  <div class="relative">
                    <div class="w-6 h-6 rounded-full bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center shrink-0">
                      <span class="text-[10px] font-bold text-white">{{ user.charAt(0).toUpperCase() }}</span>
                    </div>
                    <!-- Minimal Status Indicator -->
                    <span class="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border-2 border-white dark:border-primary-900"
                      [ngClass]="authService.currentPlanType() !== 'FREE' ? 'bg-emerald-500' : 'bg-primary-400'">
                    </span>
                  </div>
                  <span class="text-xs font-semibold text-primary-900 dark:text-white truncate max-w-[120px]">{{ user }}</span>
                  <svg class="w-4 h-4 text-primary-400 group-hover:text-primary-600 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
                </div>

                <!-- Dropdown Menu -->
                <div *ngIf="showUserMenu()" (click)="$event.stopPropagation()"
                  class="absolute top-[calc(100%+8px)] right-0 w-[245px] bg-white/95 dark:bg-primary-950/95 backdrop-blur-md border border-primary-200/80 dark:border-primary-800/80 rounded-2xl shadow-xl z-[100] py-2 animate-fade-in origin-top-right">
                  
                  <!-- Plan Details Badge (Sleek Inline Card) -->
                  <div class="px-3.5 py-2.5 mx-2.5 mt-1.5 bg-gradient-to-r from-brand-blue/5 to-brand-purple/5 dark:from-brand-blue/10 dark:to-brand-purple/10 border border-brand-blue/10 dark:border-brand-purple/20 rounded-xl mb-2 flex items-center justify-between">
                    <div class="flex flex-col min-w-0">
                      <span class="text-[9px] font-bold text-primary-400 tracking-widest uppercase">Plan</span>
                      <div class="flex items-center gap-1.5 mt-0.5">
                        <span class="text-xs font-extrabold text-primary-900 dark:text-white">
                          {{ authService.currentPlanType() === 'FREE' ? 'Basic' : (authService.currentPlanType() === 'PRO' ? 'Pro' : 'Pro Plus') }}
                        </span>
                        <span *ngIf="authService.currentPlanType() !== 'FREE'" class="flex h-1.5 w-1.5 relative">
                          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-450 opacity-75"></span>
                          <span class="relative inline-flex rounded-full h-1.5 w-1.5 bg-emerald-550"></span>
                        </span>
                      </div>
                    </div>
                    <!-- Inline Upgrade Link (Minimal like desktop) -->
                    <a *ngIf="authService.currentPlanType() !== 'ENTERPRISE'" 
                      [routerLink]="getNextPlan() === 'ENTERPRISE' ? '/contact' : '/tts'" 
                      [queryParams]="getNextPlan() === 'ENTERPRISE' ? { topic: 'enterprise' } : { autostart: getNextPlan() }"
                      (click)="showUserMenu.set(false)"
                      class="flex items-center gap-1 px-2 py-1 text-accent-600 dark:text-accent-400 hover:text-accent-700 dark:hover:text-accent-300 transition-colors text-[9px] font-black tracking-widest group/upg active:scale-95 shrink-0 uppercase">
                      <svg class="w-3.5 h-3.5 group-hover/upg:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
                      <span>{{ getUpgradeText() }}</span>
                    </a>
                  </div>

                  <!-- Navigation Settings Links -->
                  <div class="p-1 space-y-0.5">
                    <a routerLink="/settings/profile" (click)="showUserMenu.set(false)"
                      class="flex items-center gap-3 px-3 py-2 rounded-xl text-sm font-semibold text-primary-700 dark:text-primary-200 hover:bg-primary-50 dark:hover:bg-primary-900/60 transition-all hover:translate-x-0.5">
                      <svg class="w-4 h-4 text-primary-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>
                      Profile Settings
                    </a>

                    <a routerLink="/settings/history" (click)="showUserMenu.set(false)"
                      class="flex items-center gap-3 px-3 py-2 rounded-xl text-sm font-semibold text-primary-700 dark:text-primary-200 hover:bg-primary-50 dark:hover:bg-primary-900/60 transition-all hover:translate-x-0.5">
                      <svg class="w-4 h-4 text-primary-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                      Chat History
                    </a>

                    <a routerLink="/settings/payments" (click)="showUserMenu.set(false)"
                      class="flex items-center gap-3 px-3 py-2 rounded-xl text-sm font-semibold text-primary-700 dark:text-primary-200 hover:bg-primary-50 dark:hover:bg-primary-900/60 transition-all hover:translate-x-0.5">
                      <svg class="w-4 h-4 text-primary-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path></svg>
                      Billing & Plans
                    </a>
                  </div>

                  <!-- Sign Out footer -->
                  <div class="p-1 border-t border-primary-100 dark:border-primary-800/60 mt-1">
                    <button (click)="logout()"
                      class="w-full flex items-center gap-3 px-3 py-2 rounded-xl text-sm font-semibold text-red-500 hover:bg-red-50 dark:hover:bg-red-950/20 transition-all text-left hover:translate-x-0.5">
                      <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path></svg>
                      Sign Out
                    </button>
                  </div>
                </div>
              </div>
            </ng-container>

            <ng-template #guest>
              <div class="flex items-center gap-1 sm:gap-2">
                <a routerLink="/login"
                  class="px-2 sm:px-4 py-2 text-xs sm:text-sm font-medium text-primary-600 hover:text-primary-900 hover:bg-primary-50 dark:text-primary-300 dark:hover:text-white dark:hover:bg-primary-800 rounded-lg transition-all">
                  Sign in
                </a>
                <a routerLink="/signup"
                  class="px-4 py-2 text-xs font-bold text-white bg-brand-blue hover:bg-brand-blue/90 rounded-lg shadow-sm transition-all whitespace-nowrap active:scale-[0.95] tracking-wider">
                  Get Started
                </a>
              </div>
            </ng-template>
          </div>
        </div>
      </div>

      <!-- Backdrop Overlay (Transparent Click Shield) -->
      <div *ngIf="showMobileMenu()" 
        class="fixed inset-0 z-40 md:hidden bg-transparent"
        (click)="showMobileMenu.set(false)">
      </div>

      <!-- Mobile Menu Dropdown Card -->
      <div *ngIf="showMobileMenu()" (click)="$event.stopPropagation()" id="mobile-menu-panel"
        class="absolute top-[calc(100%+8px)] left-4 right-4 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-800 rounded-2xl shadow-2xl p-2.5 z-50 md:hidden animate-mobile-menu">
        <nav class="flex flex-col gap-0.5">
          <ng-container *ngFor="let link of navLinks; let i = index">
            <a [routerLink]="link.path" [fragment]="link.fragment" (click)="showMobileMenu.set(false)"
              class="flex items-center gap-3.5 px-4 py-3 rounded-xl text-base font-semibold text-primary-600 dark:text-primary-300 hover:bg-primary-50 dark:hover:bg-primary-800/60 hover:text-primary-900 dark:hover:text-white transition-all">
              
              <ng-container [ngSwitch]="link.label">
                <svg *ngSwitchCase="'Home'" class="w-5 h-5 text-primary-400 dark:text-primary-500 shrink-0" width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
                </svg>
                <svg *ngSwitchCase="'Studio'" class="w-5 h-5 text-primary-400 dark:text-primary-500 shrink-0" width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
                </svg>
                <svg *ngSwitchCase="'Pricing'" class="w-5 h-5 text-primary-400 dark:text-primary-500 shrink-0" width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <svg *ngSwitchCase="'Compare'" class="w-5 h-5 text-primary-400 dark:text-primary-500 shrink-0" width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 002 2h2a2 2 0 002-2z"></path>
                </svg>
                <svg *ngSwitchDefault class="w-5 h-5 text-primary-400 dark:text-primary-500 shrink-0" width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                </svg>
              </ng-container>
              {{ link.label }}
            </a>
          </ng-container>

          <!-- Theme Toggle inside Mobile Menu (Mobile Only) -->
          <div class="sm:hidden border-t border-primary-100 dark:border-primary-800/60 mt-1.5 pt-1.5">
            <button (click)="themeService.toggleTheme(); showMobileMenu.set(false)"
              class="w-full flex items-center gap-3.5 px-4 py-3 rounded-xl text-base font-semibold text-primary-600 dark:text-primary-300 hover:bg-primary-50 dark:hover:bg-primary-800/60 hover:text-primary-900 dark:hover:text-white transition-all text-left">
              <svg *ngIf="themeService.isDarkMode()" class="w-5 h-5 text-primary-400 dark:text-primary-500 shrink-0" width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"></path>
              </svg>
              <svg *ngIf="!themeService.isDarkMode()" class="w-5 h-5 text-primary-400 dark:text-primary-500 shrink-0" width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"></path>
              </svg>
              <span>{{ themeService.isDarkMode() ? 'Switch to Light Mode' : 'Switch to Dark Mode' }}</span>
            </button>
          </div>
        </nav>
      </div>
    </header>
  `,
  styles: [`
    @keyframes slideDown {
      from { opacity: 0; transform: translateY(-10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .animate-mobile-menu {
      animation: slideDown 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    }
    /* Enforce SVG icon sizes in mobile menu */
    #mobile-menu-panel svg {
      width: 1.25rem !important;
      height: 1.25rem !important;
      flex-shrink: 0 !important;
    }
  `]
})
export class NavbarComponent implements OnDestroy {
  authService = inject(AuthService);
  themeService = inject(ThemeService);
  private router = inject(Router);
 
  showUserMenu = signal(false);
  showMobileMenu = signal(false);
 
  @ViewChild('hamburgerButton', { read: ElementRef }) hamburgerButton!: ElementRef<HTMLButtonElement>;
 
  navLinks = [
    { label: 'Home', path: '/' },
    { label: 'Studio', path: '/tts' },
    { label: 'Pricing', path: '/', fragment: 'pricing' },
    { label: 'Compare', path: '/', fragment: 'compare' },
    { label: 'Contact Us', path: '/contact' }
  ];
 
  constructor() {
    // Close menus on route change
    this.router.events.pipe(
      filter(event => event instanceof NavigationEnd),
      takeUntilDestroyed()
    ).subscribe(() => {
      this.showMobileMenu.set(false);
      this.showUserMenu.set(false);
    });
  }

  ngOnDestroy(): void {
    document.body.style.overflow = '';
  }

  @HostListener('document:click')
  closeMenus(): void {
    this.showUserMenu.set(false);
    this.showMobileMenu.set(false);
  }

  @HostListener('document:keydown', ['$event'])
  handleKeyDown(event: KeyboardEvent): void {
    if (!this.showMobileMenu()) return;

    if (event.key === 'Escape') {
      this.showMobileMenu.set(false);
      setTimeout(() => {
        this.hamburgerButton?.nativeElement?.focus();
      }, 0);
      return;
    }

    if (event.key === 'Tab') {
      const panel = document.getElementById('mobile-menu-panel');
      if (!panel) return;

      const focusableSelectors = 'a[href], button, input, textarea, select, [tabindex]:not([tabindex="-1"])';
      const focusables = Array.from(panel.querySelectorAll(focusableSelectors)) as HTMLElement[];
      
      if (focusables.length === 0) return;

      const firstEl = focusables[0];
      const lastEl = focusables[focusables.length - 1];
      const activeEl = document.activeElement as HTMLElement;

      if (!event.shiftKey) {
        if (activeEl === lastEl || !focusables.includes(activeEl)) {
          firstEl.focus();
          event.preventDefault();
        }
      } else {
        if (activeEl === firstEl || !focusables.includes(activeEl)) {
          lastEl.focus();
          event.preventDefault();
        }
      }
    }
  }

  toggleUserMenu(event: Event): void {
    event.stopPropagation();
    this.showUserMenu.update(v => !v);
    this.showMobileMenu.set(false);
  }

  toggleMobileMenu(event: Event): void {
    event.stopPropagation();
    const willOpen = !this.showMobileMenu();
    this.showMobileMenu.set(willOpen);
    this.showUserMenu.set(false);

    if (willOpen) {
      setTimeout(() => {
        const panel = document.getElementById('mobile-menu-panel');
        const firstFocusable = panel?.querySelector('a[href], button, [tabindex]:not([tabindex="-1"])') as HTMLElement;
        firstFocusable?.focus();
      }, 50);
    } else {
      setTimeout(() => {
        this.hamburgerButton?.nativeElement?.focus();
      }, 0);
    }
  }

  logout(): void {
    this.authService.logout();
    this.showUserMenu.set(false);
    this.showMobileMenu.set(false);
  }

  getNextPlan(): string {
    const current = this.authService.currentPlanType();
    if (current === 'FREE') return 'PRO';
    if (current === 'PRO') return 'PRO_PLUS';
    return 'ENTERPRISE';
  }

  getUpgradeText(): string {
    const current = this.authService.currentPlanType();
    if (current === 'FREE') return 'Upgrade to Pro';
    if (current === 'PRO') return 'Upgrade to Pro Plus';
    return 'Get Enterprise';
  }
}
