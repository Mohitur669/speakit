/**
 * Global navigation bar component with logo, nav links,
 * theme toggle, and authenticated user menu with logout.
 */
import { Component, inject, signal, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { ThemeService } from '../../../core/services/theme.service';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <header class="sticky top-0 z-50 w-full bg-white/80 dark:bg-primary-900/80 backdrop-blur-xl border-b border-primary-200 dark:border-primary-800">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 gap-4">

          <!-- Logo -->
          <a routerLink="/" class="flex items-center gap-2 sm:gap-3 group shrink-0">
            <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center shadow-md group-hover:shadow-lg group-hover:scale-105 transition-all">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
              </svg>
            </div>
            <span class="text-base sm:text-lg font-semibold text-primary-900 dark:text-white tracking-tight">SpeakIT</span>
          </a>

          <!-- Desktop Nav -->
          <nav class="hidden md:flex items-center gap-6 lg:gap-8">
            <a routerLink="/" fragment="home" class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">Home</a>
            <a routerLink="/" fragment="features" class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">Features</a>
            <a routerLink="/" fragment="pricing" class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">Pricing</a>
            <a routerLink="/" fragment="compare" class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">Compare</a>
          </nav>

          <!-- Actions -->
          <div class="flex items-center gap-2 sm:gap-3 shrink-0">
            <!-- Theme Toggle -->
            <button (click)="themeService.toggleTheme()"
              class="p-2 rounded-lg text-primary-500 hover:text-primary-900 hover:bg-primary-50 dark:text-primary-400 dark:hover:text-white dark:hover:bg-primary-800 transition-all"
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
                  class="absolute top-full right-0 mt-2 w-48 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 rounded-xl shadow-2xl z-[100] py-2 animate-fade-in">
                  
                  <div class="px-4 py-2 border-b border-primary-100 dark:border-primary-800 mb-1">
                    <p class="text-xs font-semibold text-primary-400 uppercase tracking-wider">Current Plan</p>
                    <div class="flex flex-col gap-2 mt-1">
                      <div class="flex items-center justify-between">
                        <div class="flex items-center justify-between">
                          <span class="text-sm font-bold text-primary-900 dark:text-white">{{ authService.currentPlanType() === 'FREE' ? 'Basic' : authService.currentPlanType().replace('_', ' ') }}</span>
                          <span *ngIf="authService.currentPlanType() !== 'FREE'" class="flex h-2 w-2 relative">
                            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                            <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                          </span>
                        </div>
                      </div>
                      
                      <!-- Mobile-Only Upgrade Button (Matches Desktop Styling) -->
                      <a *ngIf="authService.currentPlanType() !== 'ENTERPRISE'" 
                        routerLink="/tts" [queryParams]="{autostart: authService.currentPlanType() === 'FREE' ? 'PRO' : (authService.currentPlanType() === 'PRO' ? 'PRO_PLUS' : 'ENTERPRISE')}"
                        (click)="$event.stopPropagation(); showUserMenu.set(false)"
                        class="lg:hidden w-full mt-2 py-2.5 px-4 text-center text-xs font-bold text-white bg-accent-500 hover:bg-accent-600 rounded-lg shadow-md hover:shadow-accent-500/20 active:scale-95 transition-all uppercase tracking-wider">
                        {{ authService.currentPlanType() === 'PRO_PLUS' ? 'Get Enterprise' : 'Get ' + (authService.currentPlanType() === 'FREE' ? 'Pro' : 'Pro Plus') }}
                      </a>
                    </div>
                  </div>

                  <a routerLink="/settings/profile" (click)="showUserMenu.set(false)"
                    class="flex items-center gap-3 px-4 py-2 text-sm text-primary-700 dark:text-primary-200 hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>
                    Profile Settings
                  </a>

                  <a routerLink="/settings/history" (click)="showUserMenu.set(false)"
                    class="flex items-center gap-3 px-4 py-2 text-sm text-primary-700 dark:text-primary-200 hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                    Chat History
                  </a>

                  <a routerLink="/settings/payments" (click)="showUserMenu.set(false)"
                    class="flex items-center gap-3 px-4 py-2 text-sm text-primary-700 dark:text-primary-200 hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path></svg>
                    Payment History
                  </a>

                  <button (click)="logout()"
                    class="w-full flex items-center gap-3 px-4 py-2 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path></svg>
                    Sign Out
                  </button>
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
                  class="px-3 sm:px-4 py-2 text-xs sm:text-sm font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 rounded-lg shadow-sm hover:shadow-md transition-all whitespace-nowrap">
                  Get Started
                </a>
              </div>
            </ng-template>
          </div>
        </div>
      </div>
    </header>
  `
})
export class NavbarComponent {
  authService = inject(AuthService);
  themeService = inject(ThemeService);
  private router = inject(Router);

  showUserMenu = signal(false);

  @HostListener('document:click')
  closeUserMenu(): void {
    this.showUserMenu.set(false);
  }

  toggleUserMenu(event: Event): void {
    event.stopPropagation();
    this.showUserMenu.update(v => !v);
  }

  logout(): void {
    this.authService.logout();
  }
}
