import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-toast',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div *ngIf="visible"
      class="fixed bottom-6 right-6 z-[9999] animate-slide-up">
      <div [ngClass]="{
        'flex items-center gap-3 px-5 py-4 rounded-xl shadow-elevated border font-medium text-sm': true,
        'bg-white dark:bg-primary-900 border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white': type === 'success',
        'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800/30 text-red-600 dark:text-red-400': type === 'error'
      }">
        <svg *ngIf="type === 'success'" class="w-5 h-5 text-accent-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        <svg *ngIf="type === 'error'" class="w-5 h-5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        {{ message }}
      </div>
    </div>
  `
})
export class ToastComponent {
  @Input() message = '';
  @Input() type: 'success' | 'error' = 'success';
  @Input() visible = false;
}