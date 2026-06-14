import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { FeatureFlagService } from '../../../core/services/feature-flag.service';

@Component({
  selector: 'app-footer',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <footer class="pt-20 pb-10 bg-white dark:bg-primary-900 border-t border-primary-200 dark:border-primary-800">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-12 mb-16">
          <div class="col-span-2 md:col-span-1">
            <div class="flex items-center gap-2 mb-6">
              <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path></svg>
              </div>
              <span class="text-lg font-bold text-primary-900 dark:text-white">SpeakIT</span>
            </div>
            <p class="text-sm text-primary-600 dark:text-primary-400 mb-6 leading-relaxed">
              Transforming digital content with lifelike AI-powered speech synthesis. Professional quality, available to everyone.
            </p>
            <div class="flex items-center gap-4">
              <a href="https://x.com/Mohitur02" target="_blank" class="text-primary-400 hover:text-brand-blue transition-colors" aria-label="Twitter">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M24 4.557c-.883.392-1.832.656-2.828.775 1.017-.609 1.798-1.574 2.165-2.724-.951.564-2.005.974-3.127 1.195-.897-.957-2.178-1.555-3.594-1.555-3.179 0-5.515 2.966-4.797 6.045-4.091-.205-7.719-2.165-10.148-5.144-1.29 2.213-.669 5.108 1.523 6.574-.806-.026-1.566-.247-2.229-.616-.054 2.281 1.581 4.415 3.949 4.89-.693.188-1.452.232-2.224.084.626 1.956 2.444 3.379 4.6 3.419-2.07 1.623-4.678 2.348-7.29 2.04 2.179 1.397 4.768 2.212 7.548 2.212 9.142 0 14.307-7.721 13.995-14.646.962-.695 1.797-1.562 2.457-2.549z"/></svg>
              </a>
              <a href="https://github.com/Mohitur669" target="_blank" class="text-primary-400 hover:text-brand-blue transition-colors" aria-label="GitHub">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.041-1.416-4.041-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
              </a>
            </div>
          </div>
          <div>
            <h4 class="text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider mb-6">Product</h4>
            <ul class="space-y-4">
              <li><a routerLink="/" fragment="features" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">Features</a></li>
              <li><a routerLink="/" fragment="pricing" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">Pricing</a></li>
              <li><a routerLink="/login" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">Demo</a></li>
            </ul>
          </div>
          <div>
            <h4 class="text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider mb-6">Company</h4>
            <ul class="space-y-4">
              <li><a routerLink="/about" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">About Us</a></li>
              <li><a routerLink="/blog" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">Blog</a></li>
              <li><a routerLink="/contact" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">Contact Us</a></li>
            </ul>
          </div>
          <div>
            <h4 class="text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider mb-6">Legal</h4>
            <ul class="space-y-4">
              <li><a routerLink="/privacy" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">Privacy Policy</a></li>
              <li><a routerLink="/terms" class="text-sm text-primary-600 dark:text-primary-400 hover:text-brand-blue transition-colors">Terms of Service</a></li>
            </ul>
          </div>
        </div>
        <div class="pt-8 border-t border-primary-200 dark:border-primary-800 flex flex-col md:flex-row items-center justify-between gap-6">
          <p class="text-xs text-primary-600">&copy; {{ currentYear }} SpeakIT. All rights reserved. Built for professional voice generation.</p>
          <div class="flex items-center gap-6">
            <span class="text-xs text-primary-600 flex items-center gap-2">
              <span class="w-1.5 h-1.5 rounded-full"
                [ngClass]="{
                  'bg-emerald-500': systemStatus() === 'Operational',
                  'bg-amber-500': systemStatus() === 'Maintenance',
                  'bg-red-500': systemStatus() === 'Outage'
                }"></span>
              System Status: {{ systemStatus() }}
            </span>
          </div>
        </div>
      </div>
    </footer>
  `
})
export class FooterComponent implements OnInit {
  private featureFlags = inject(FeatureFlagService);

  currentYear = new Date().getFullYear();
  systemStatus = signal('Operational');

  async ngOnInit() {
    const status = await this.featureFlags.getLive('SYSTEM_STATUS', 'Operational');
    this.systemStatus.set(status);
  }
}
