import { Component, Input, Output, EventEmitter, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-tts-input',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div
      class="flex-1 bg-white dark:bg-primary-900 rounded-xl border border-primary-300 dark:border-primary-700 overflow-hidden flex flex-col"
    >
      <div
        class="px-4 sm:px-6 py-3 sm:py-4 border-b border-primary-200 dark:border-primary-800 flex items-center justify-between"
      >
        <div class="flex flex-wrap items-center gap-2 sm:gap-4">
          <h2 class="text-lg sm:text-sm font-semibold text-primary-900 dark:text-white">Script</h2>
          @if (usage?.dailyLimit > 0) {
            <span
              class="text-xs font-semibold px-2 py-1 rounded-md bg-accent-500/10 text-accent-600 dark:text-accent-400 whitespace-nowrap"
            >
              {{ usage?.dailyCount }}/{{ usage?.dailyLimit }} credits used
            </span>
          }
          <!-- Mobile-Only Quick Stats -->
          <div
            class="md:hidden flex items-center gap-2 bg-primary-50 dark:bg-primary-800 px-2.5 py-1 rounded-full border border-primary-200 dark:border-transparent"
          >
            <span class="text-[10px] font-bold text-primary-500 tracking-wider whitespace-nowrap">Usage</span>
            <span class="text-[11px] font-medium text-primary-700 dark:text-primary-300 whitespace-nowrap"
              >{{ text.length }} / {{ maxChars | number }}</span
            >
            <div class="w-12 h-1.5 bg-primary-200 dark:bg-primary-700 rounded-full overflow-hidden">
              <div
                [ngClass]="text.length > maxChars * 0.9 ? 'bg-red-500' : 'bg-brand-blue'"
                class="h-full rounded-full transition-all"
                [style.width.%]="(text.length / maxChars) * 100"
              ></div>
            </div>
          </div>
        </div>
        @if (text) {
          <button
            (click)="clearText()"
            class="text-sm sm:text-xs text-primary-500 hover:text-primary-700 dark:hover:text-primary-300 transition-colors"
          >
            Clear
          </button>
        }
      </div>
      <div class="p-4 sm:p-6 flex-1 flex flex-col">
        <textarea
          [(ngModel)]="text"
          (ngModelChange)="onTextChange($event)"
          placeholder="Enter your text here..."
          rows="12"
          [maxlength]="maxChars"
          class="flex-1 w-full bg-primary-50 dark:bg-primary-800 text-primary-900 dark:text-white placeholder-primary-400 rounded-xl border border-primary-300 dark:border-primary-700 p-3 sm:p-4 text-base sm:text-sm leading-relaxed resize-none focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all min-h-[300px]"
        ></textarea>
      </div>
    </div>
  `,
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
