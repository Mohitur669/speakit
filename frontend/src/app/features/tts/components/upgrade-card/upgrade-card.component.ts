import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-upgrade-card',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="hidden md:block bg-white dark:bg-primary-900 p-4 rounded-xl border border-accent-500/20 transition-all group hover:border-accent-500/50">
      <div class="flex items-center gap-2.5 mb-3">
        <div class="w-7 h-7 rounded-lg bg-accent-500/10 flex items-center justify-center text-accent-500 shrink-0">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
          </svg>
        </div>
        <h3 class="text-[10px] font-bold text-primary-900 dark:text-white tracking-widest">{{ title }}</h3>
      </div>
      
      <p class="text-[9px] leading-relaxed text-primary-500 dark:text-primary-400 mb-4">{{ description }}</p>
      
      <button (click)="upgrade.emit(nextPlan)"
        class="w-full py-2 px-4 rounded-lg bg-accent-500 hover:bg-accent-600 text-white text-[9px] font-extrabold transition-all active:scale-[0.98]">
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
    if (this.currentPlan === 'PRO') return 'Go Pro Plus';
    return 'Get Enterprise';
  }

  get description(): string {
    if (this.currentPlan === 'FREE') return 'Unlock Indian AI voices and higher character limits.';
    if (this.currentPlan === 'PRO') return 'Unlock ElevenLabs Natural AI and 20k character limit.';
    return 'Tailored character limits and dedicated SLA for large scale.';
  }

  get nextPlan(): string {
    if (this.currentPlan === 'FREE') return 'PRO';
    if (this.currentPlan === 'PRO') return 'PRO_PLUS';
    return 'ENTERPRISE';
  }

  get buttonText(): string {
    if (this.currentPlan === 'FREE') return 'Upgrade to Pro';
    if (this.currentPlan === 'PRO') return 'Upgrade to Pro Plus';
    return 'Get Enterprise';
  }
}
