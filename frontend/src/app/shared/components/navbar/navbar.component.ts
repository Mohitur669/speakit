/**
 * Global navigation bar component with logo, nav links,
 * theme toggle, and authenticated user menu with logout.
 */
import { Component, inject } from '@angular/core';
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
        <div class="flex items-center justify-between h-16">

          <!-- Logo -->
          <a routerLink="/" class="flex items-center gap-3 group">
            <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center shadow-md group-hover:shadow-lg group-hover:scale-105 transition-all">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
              </svg>
            </div>
            <span class="text-lg font-semibold text-primary-900 dark:text-white tracking-tight">SpeakIT</span>
          </a>

          <!-- Desktop Nav -->
          <nav class="hidden md:flex items-center gap-8">
            <a routerLink="/" class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">Home</a>
            <a href="#features" class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">Features</a>
            <a href="#pricing" class="text-sm font-medium text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white transition-colors">Pricing</a>
          </nav>

          <!-- Actions -->
          <div class="flex items-center gap-3">
            <!-- Theme Toggle -->
            <button (click)="themeService.toggleTheme()"
              class="p-2 rounded-lg text-primary-500 hover:text-primary-900 hover:bg-primary-100 dark:text-primary-400 dark:hover:text-white dark:hover:bg-primary-800 transition-all"
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
              <div class="flex items-center gap-2">
                <!-- User + Plan Badge (Merged) -->
                <div class="flex items-center justify-center gap-2 w-auto h-9 px-3 rounded-full bg-primary-100 dark:bg-primary-800 border border-primary-200 dark:border-primary-700"
                  [ngClass]="{'bg-accent-50 dark:bg-accent-500/10 border-accent-200 dark:border-accent-500/30': authService.hasNaturalAccess()}">
                  <div class="w-5 h-5 rounded-full bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center flex-shrink-0">
                    <span class="text-[9px] font-semibold text-white">U</span>
                  </div>
                  <span class="text-xs font-medium text-primary-700 dark:text-primary-200 truncate max-w-[100px]">{{ user }}</span>
                  <ng-container *ngIf="authService.hasNaturalAccess()">
                    <span class="w-2 h-2 rounded-full bg-accent-500 animate-pulse"></span>
                    <span class="text-xs font-semibold text-accent-600 dark:text-accent-400">Pro</span>
                  </ng-container>
                </div>

                <!-- Sign Out -->
                <button (click)="logout()"
                  class="w-9 h-9 rounded-full text-primary-500 hover:text-primary-700 hover:bg-primary-100 dark:text-primary-400 dark:hover:text-white dark:hover:bg-primary-800 border border-primary-200 dark:border-primary-700 transition-all flex items-center justify-center"
                  aria-label="Sign out">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                  </svg>
                </button>
              </div>
            </ng-container>

            <ng-template #guest>
              <div class="flex items-center gap-2">
                <a routerLink="/login"
                  class="px-4 py-2 text-sm font-medium text-primary-600 hover:text-primary-900 hover:bg-primary-100 dark:text-primary-300 dark:hover:text-white dark:hover:bg-primary-800 rounded-lg transition-all">
                  Sign in
                </a>
                <a routerLink="/signup"
                  class="px-4 py-2 text-sm font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 rounded-lg shadow-sm hover:shadow-md transition-all">
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

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/']);
  }
}