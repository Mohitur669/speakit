import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { SttResult } from '../../models/stt.models';
import { ToastService } from '../../../../core/services/toast.service';

@Component({
  selector: 'app-transcript-card',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-300 dark:border-primary-700 shadow-xl overflow-hidden animate-slide-up">
      <div class="p-6 border-b border-primary-200 dark:border-primary-800 flex items-center justify-between">

        <div class="flex items-center gap-4">
          <div class="px-3 py-1 rounded-full bg-brand-blue/10 text-brand-blue text-xs font-bold tracking-wider">
            {{ result.provider === 'SARVAM' ? 'Indian' : (result.provider === 'ELEVEN_LABS' ? 'Global' : result.provider) }}
          </div>
          <span class="text-sm text-primary-500 font-medium">Duration: {{ result.duration | number:'1.1-1' }}s</span>
        </div>
        
        <div class="flex items-center gap-2">
          <button (click)="copyToClipboard()" 
            class="p-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-blue transition-all"
            title="Copy to Clipboard">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"></path>
            </svg>
          </button>
          <button (click)="downloadTxt()" 
            class="p-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-purple transition-all"
            title="Download TXT">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
            </svg>
          </button>
        </div>
      </div>

      <div class="p-8">
        <div class="max-h-[500px] overflow-y-auto custom-scrollbar pr-2">
          <p class="text-primary-800 dark:text-primary-100 leading-relaxed whitespace-pre-wrap selection:bg-brand-blue/20">
            {{ result.transcript || 'No transcript generated.' }}
          </p>
        </div>
      </div>
    </div>
  `
})
export class TranscriptCardComponent {
  @Input() result!: SttResult;
  private toast = inject(ToastService);

  copyToClipboard() {
    navigator.clipboard.writeText(this.result.transcript);
    this.toast.show('Transcript copied to clipboard', 'success');
  }

  downloadTxt() {
    const blob = new Blob([this.result.transcript], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `speakit-transcript-${Date.now()}.txt`;
    a.click();
    window.URL.revokeObjectURL(url);
    this.toast.show('Download started', 'success');
  }
}
