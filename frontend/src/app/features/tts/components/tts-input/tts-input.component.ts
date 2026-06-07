import { Component, Input, Output, EventEmitter, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-tts-input',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="flex-1 bg-white dark:bg-primary-900 rounded-xl border border-primary-200 dark:border-primary-700 overflow-hidden flex flex-col">
      <div class="px-4 sm:px-6 py-3 sm:py-4 border-b border-primary-100 dark:border-primary-800 flex items-center justify-between">

        <div class="flex items-center gap-4">
          <h2 class="text-lg sm:text-sm font-semibold text-primary-900 dark:text-white">Script</h2>
          <span *ngIf="usage?.dailyLimit > 0" class="text-xs font-semibold px-2 py-1 rounded-md bg-accent-500/10 text-accent-600 dark:text-accent-400">
            {{ usage?.dailyCount }}/{{ usage?.dailyLimit }} credits used
          </span>
          <!-- Mobile-Only Quick Stats -->
          <div class="md:hidden flex items-center gap-3 bg-primary-100 dark:bg-primary-800 px-3 py-1 rounded-full">
            <span class="text-[10px] font-bold text-primary-500 uppercase tracking-wider">Usage</span>
            <span class="text-[11px] font-medium text-primary-700 dark:text-primary-300">{{ text.length }} / {{ maxChars | number }}</span>
            <div class="w-12 h-1.5 bg-primary-200 dark:bg-primary-700 rounded-full overflow-hidden">
              <div [ngClass]="text.length > (maxChars * 0.9) ? 'bg-red-500' : 'bg-brand-blue'"
                class="h-full rounded-full transition-all"
                [style.width.%]="(text.length / maxChars) * 100"></div>
            </div>
          </div>
        </div>
        <button *ngIf="text" (click)="clearText()"
          class="text-sm sm:text-xs text-primary-400 hover:text-primary-600 dark:hover:text-primary-300 transition-colors">
          Clear
        </button>
      </div>
      <div class="p-4 sm:p-6 flex-1 flex flex-col">
        <textarea [(ngModel)]="text"
          (ngModelChange)="onTextChange($event)"
          placeholder="Enter your text here..."
          rows="12"
          [maxlength]="maxChars"
          class="flex-1 w-full bg-primary-50 dark:bg-primary-800 text-primary-900 dark:text-white placeholder-primary-400 rounded-xl border border-primary-200 dark:border-primary-700 p-3 sm:p-4 text-base sm:text-sm leading-relaxed resize-none focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all min-h-[300px]"></textarea>

        <div class="mt-4 flex items-center justify-end">
          <button (click)="convert.emit()" [disabled]="loading || !text.trim() || !voiceId"
            class="flex items-center justify-center gap-2 w-40 h-12 rounded-xl font-semibold text-sm text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-xl active:scale-[0.98]">
            <svg *ngIf="loading" class="w-5 h-5 animate-spin shrink-0" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
            </svg>
            <svg *ngIf="!loading" class="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
            </svg>
            <span class="whitespace-nowrap">{{ loading ? 'Generating...' : 'Generate' }}</span>
          </button>
        </div>
      </div>
    </div>
  `
})
export class TtsInputComponent {
  @Input() text: string = '';
  @Input() maxChars: number = 3000;
  @Input() usage: any = null;
  @Input() loading = false;
  @Input() voiceId = '';

  @Output() textChange = new EventEmitter<string>();
  @Output() convert = new EventEmitter<void>();

  onTextChange(val: string): void {
    this.textChange.emit(val);
  }

  clearText(): void {
    this.text = '';
    this.textChange.emit('');
  }
}
