import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-usage-stats',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="hidden md:block bg-white dark:bg-primary-900 rounded-xl border border-primary-200 dark:border-primary-700 p-6">
      <h2 class="text-lg sm:text-sm font-semibold text-primary-900 dark:text-white mb-4">Your Usage</h2>
      <div class="space-y-4">
        <div>
          <div class="flex justify-between text-base sm:text-sm mb-1">
            <span class="text-primary-500">Current Plan</span>
            <span class="font-bold text-brand-blue">{{ planType === 'FREE' ? 'Basic' : planType.replace('_', ' ') }}</span>
          </div>
          <div class="flex justify-between text-base sm:text-sm mb-2">
            <span class="text-primary-500">Characters used</span>
            <span class="font-medium text-primary-700 dark:text-primary-300">{{ textLength | number }} / {{ maxChars | number }}</span>
          </div>
          <div class="h-2 bg-primary-100 dark:bg-primary-800 rounded-full overflow-hidden">
            <div [ngClass]="textLength > (maxChars * 0.9) ? 'bg-red-500' : 'bg-brand-blue'"
              class="h-full rounded-full transition-all duration-500"
              [style.width.%]="progress"></div>
          </div>
        </div>
      </div>
    </div>
  `
})
export class UsageStatsComponent {
  @Input() planType = 'FREE';
  @Input() textLength = 0;
  @Input() maxChars = 3000;

  get progress(): number {
    return this.maxChars > 0 ? (this.textLength / this.maxChars) * 100 : 0;
  }
}
