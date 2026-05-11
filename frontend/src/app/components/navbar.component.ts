import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, Router } from '@angular/router';
import { AuthService } from '../services/auth';
import { ThemeService } from '../services/theme';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <nav class="sticky top-0 z-50 w-full bg-white/80 dark:bg-[#090b11]/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 transition-colors duration-300">
      <div class="max-w-7xl mx-auto px-6 lg:px-8">
        <div class="flex justify-between h-16 items-center">
          <!-- Logo -->
          <div class="flex items-center gap-2 cursor-pointer group" routerLink="/">
            <div class="w-9 h-9 rounded-xl bg-amber-500 flex items-center justify-center text-xl shadow-lg shadow-amber-500/20 group-hover:scale-105 transition-all duration-300">
              🎙
            </div>
            <span class="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Speak<span class="text-amber-500">IT</span>
            </span>
          </div>

          <!-- Actions -->
          <div class="flex items-center gap-4">
            <!-- Theme Toggle -->
            <button (click)="themeService.toggleTheme()" 
              class="p-2 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-400 transition-all active:scale-90 border border-transparent shadow-sm">
              <span *ngIf="themeService.isDarkMode()" class="text-lg">☀️</span>
              <span *ngIf="!themeService.isDarkMode()" class="text-lg">🌙</span>
            </button>

            <!-- Auth/Profile -->
            <div class="flex items-center gap-3">
              <ng-container *ngIf="authService.currentUser() as user; else guest">
                <div class="flex items-center gap-4 pl-4 border-l border-slate-200 dark:border-slate-800">
                  <div class="hidden sm:flex flex-col items-end">
                    <span class="text-xs font-bold text-slate-900 dark:text-white tracking-tight">{{ user }}</span>
                    <div class="flex items-center gap-1">
                      <span class="w-1 h-1 rounded-full" [ngClass]="authService.hasNaturalAccess() ? 'bg-amber-500 animate-pulse' : 'bg-emerald-500'"></span>
                      <span class="text-[9px] uppercase font-bold tracking-widest text-slate-500">
                        {{ authService.hasNaturalAccess() ? 'Premium' : 'Standard' }}
                      </span>
                    </div>
                  </div>
                  <button (click)="logout()" 
                    class="px-4 py-2 text-xs font-bold text-white bg-slate-900 dark:bg-white dark:text-slate-900 rounded-lg hover:opacity-90 transition-all active:scale-95 shadow-md">
                    Sign Out
                  </button>
                </div>
              </ng-container>
              <ng-template #guest>
                <div class="flex items-center gap-4">
                  <a routerLink="/login" class="text-xs font-bold text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors uppercase tracking-widest">Log In</a>
                  <a routerLink="/signup" class="px-5 py-2.5 bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold rounded-xl transition-all active:scale-95 shadow-lg shadow-amber-500/20 uppercase tracking-widest">
                    Join Studio
                  </a>
                </div>
              </ng-template>
            </div>
          </div>
        </div>
      </div>
    </nav>
  `,
  styles: [`
    :host { font-family: 'Inter', sans-serif; }
  `]
})
export class NavbarComponent {
  authService = inject(AuthService);
  themeService = inject(ThemeService);
  private router = inject(Router);

  logout() {
    this.authService.logout();
    this.router.navigate(['/']);
  }
}
