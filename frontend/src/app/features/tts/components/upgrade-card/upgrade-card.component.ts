import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-upgrade-card',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="hidden lg:block bg-white dark:bg-primary-900 p-6 rounded-xl border-2 border-accent-500/20 shadow-lg animate-fade-in group hover:border-accent-500/50 transition-all">
      <div class="flex items-center gap-3 mb-4">
        <div class="w-12 h-12 rounded-xl bg-accent-500/10 flex items-center justify-center group-hover:scale-110 transition-transform">
          <svg class="w-5 h-5 text-accent-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
          </svg>
        </div>
        <h3 class="text-base sm:text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider">
          {{ title }}
        </h3>
      </div>
      <p class="text-sm sm:text-xs text-primary-500 dark:text-primary-400 mb-6 leading-relaxed">
        {{ description }}
      </p>
      <button (click)="upgrade.emit(nextPlan)"
        class="block w-full px-6 py-3.5 sm:py-3 text-center text-sm font-semibold text-white bg-accent-500 hover:bg-accent-600 rounded-xl transition-all shadow-md hover:shadow-lg hover:shadow-accent-500/20 active:scale-95">
        {{ buttonText }}
      </button>
    </div>
  `
})
export class UpgradeCardComponent {
  @Input() currentPlan = 'FREE';
  @Output() upgrade = new EventEmitter<string>();

  get title(): string {
    if (this.currentPlan === 'FREE') return 'Go Pro';
    if (this.currentPlan === 'PRO') return 'Get Pro Plus';
    return 'Get Enterprise';
  }

  get description(): string {
    if (this.currentPlan === 'FREE') return 'Unlock natural neural voices and higher generation priority.';
    if (this.currentPlan === 'PRO') return 'Unlock ElevenLabs AI voices and higher character limits.';
    return 'Tailored character limits and dedicated SLA for large scale.';
  }

  get nextPlan(): string {
    if (this.currentPlan === 'FREE') return 'PRO';
    if (this.currentPlan === 'PRO') return 'PRO_PLUS';
    return 'ENTERPRISE';
  }

  get buttonText(): string {
    if (this.currentPlan === 'PRO_PLUS') return 'Get Enterprise';
    return 'Upgrade to ' + (this.currentPlan === 'FREE' ? 'Pro' : 'Pro Plus');
  }
}
