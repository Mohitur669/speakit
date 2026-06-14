import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-locked-feature-card',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <div class="flex flex-col items-center justify-center p-12 text-center bg-white dark:bg-primary-900 rounded-3xl border border-primary-300 dark:border-primary-700 shadow-xl max-w-2xl mx-auto animate-fade-in">
      <div class="w-20 h-20 bg-linear-to-br from-brand-blue/10 to-brand-purple/10 rounded-full flex items-center justify-center mb-6">
        <svg class="w-10 h-10 text-brand-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
        </svg>
      </div>
      
      <h2 class="text-2xl font-bold text-primary-900 dark:text-white mb-4">Speech-to-Text is a Pro feature</h2>
      <p class="text-primary-600 dark:text-primary-400 mb-8 max-w-md">
        Upgrade to a premium plan to unlock high-accuracy transcription powered by Sarvam and ElevenLabs AI.
      </p>

      <button routerLink="/tts" [queryParams]="{ autostart: 'PRO' }"
        class="px-8 py-3.5 bg-brand-blue text-white font-bold rounded-2xl shadow-lg hover:shadow-brand-blue/20 active:scale-[0.98] transition-all">
        Upgrade to Unlock
      </button>
    </div>
  `
})
export class LockedFeatureCardComponent {}
