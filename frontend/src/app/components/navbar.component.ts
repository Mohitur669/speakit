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
    <nav class="sticky top-0 z-50 w-full bg-white/80 dark:bg-[#0a0e1a]/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 transition-colors duration-300">
      <div class="w-full px-6 sm:px-10 lg:px-16">
        <div class="flex justify-between h-20 items-center">
          <!-- Logo -->
          <div class="flex items-center gap-3 cursor-pointer group" routerLink="/">
            <div class="w-12 h-12 rounded-2xl bg-amber-500 flex items-center justify-center text-2xl shadow-xl shadow-amber-500/20 group-hover:scale-110 group-hover:rotate-3 transition-all duration-500">
              🎙
            </div>
            <span class="text-3xl font-black text-slate-900 dark:text-white tracking-tightest">
              Speak<span class="text-amber-500">IT</span>
            </span>
          </div>

          <!-- Actions -->
          <div class="flex items-center gap-6">
            <!-- Theme Toggle -->
            <button (click)="themeService.toggleTheme()" 
              class="p-3 rounded-2xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-400 transition-all active:scale-90 border border-transparent hover:border-slate-200 dark:hover:border-slate-600 shadow-sm">
              <span *ngIf="themeService.isDarkMode()" class="text-2xl">☀️</span>
              <span *ngIf="!themeService.isDarkMode()" class="text-2xl">🌙</span>
            </button>

            <!-- Auth/Profile -->
            <div class="flex items-center gap-4">
              <ng-container *ngIf="authService.currentUser() as user; else guest">
                <div class="flex items-center gap-5 pl-4 border-l border-slate-200 dark:border-slate-800">
                  <div class="hidden sm:flex flex-col items-end">
                    <span class="text-sm font-black text-slate-900 dark:text-white tracking-tight">{{ user }}</span>
                    <div class="flex items-center gap-1.5">
                      <span class="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse"></span>
                      <span class="text-[10px] text-amber-600 dark:text-amber-500 uppercase font-black tracking-widest">Premium Studio</span>
                    </div>
                  </div>
                  <button (click)="logout()" 
                    class="px-6 py-3 text-sm font-black text-white bg-slate-900 dark:bg-white dark:text-slate-900 rounded-2xl hover:opacity-90 transition-all active:scale-95 shadow-xl shadow-slate-900/10 dark:shadow-white/5">
                    Sign Out
                  </button>
                </div>
              </ng-container>
              <ng-template #guest>
                <div class="flex items-center gap-5">
                  <a routerLink="/login" class="text-sm font-black text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors uppercase tracking-widest">Log In</a>
                  <a routerLink="/signup" class="px-8 py-3.5 bg-amber-500 hover:bg-amber-600 text-white text-sm font-black rounded-2xl transition-all active:scale-95 shadow-2xl shadow-amber-500/30 uppercase tracking-widest">
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
    .tracking-tightest { letter-spacing: -0.05em; }
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
