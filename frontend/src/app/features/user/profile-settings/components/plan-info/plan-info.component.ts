import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-plan-info',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="mb-8 p-6 bg-brand-blue/5 rounded-2xl border border-brand-blue/10 flex items-center justify-between">
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-brand-blue/10 flex items-center justify-center text-brand-blue">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
          </svg>
        </div>
        <div>
          <p class="text-xs font-bold text-brand-blue uppercase tracking-wider mb-1">Your Plan</p>
          <h3 class="text-xl font-bold text-primary-900 dark:text-white">{{ planType.replace('_', ' ') }}</h3>
        </div>
      </div>
      <div *ngIf="planType === 'FREE'" class="hidden sm:block">
        <p class="text-sm text-primary-500 dark:text-primary-400">Upgrade to unlock Natural AI voices</p>
      </div>
    </div>
  `
})
export class PlanInfoComponent {
  @Input() planType = 'FREE';
}
