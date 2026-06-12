import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-confirm-modal',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fade-in" (click)="cancel.emit()">
      <div class="bg-white dark:bg-primary-900 rounded-2xl p-6 w-full max-w-sm border border-primary-200 dark:border-primary-700 shadow-2xl animate-scale-up" (click)="$event.stopPropagation()">
        
        <!-- Icon & Title -->
        <div class="flex items-center gap-4 mb-4">
          <div [ngClass]="isDanger ? 'bg-red-100 dark:bg-red-900/30 text-red-600' : 'bg-brand-blue/10 text-brand-blue'" 
            class="w-12 h-12 rounded-xl flex items-center justify-center shrink-0">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path *ngIf="isDanger" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              <path *ngIf="!isDanger" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div>
            <h3 class="text-lg font-bold text-primary-900 dark:text-white">{{ title }}</h3>
            <p class="text-sm text-primary-500 dark:text-primary-400 mt-1 leading-relaxed">{{ message }}</p>
          </div>
        </div>

        <!-- Actions -->
        <div class="flex flex-col sm:flex-row items-center gap-3 mt-8">
          <button (click)="cancel.emit()" 
            class="w-full sm:flex-1 py-3 px-4 bg-primary-100 dark:bg-primary-800 hover:bg-primary-200 dark:hover:bg-primary-700 text-primary-700 dark:text-primary-200 text-sm font-bold rounded-xl transition-all active:scale-95">
            {{ cancelText }}
          </button>
          <button (click)="confirm.emit()" 
            [ngClass]="isDanger ? 'bg-red-500 hover:bg-red-600 shadow-red-500/20' : 'bg-brand-blue hover:bg-blue-600 shadow-brand-blue/20'"
            class="w-full sm:flex-1 py-3 px-4 text-white text-sm font-bold rounded-xl shadow-lg transition-all active:scale-95">
            {{ confirmText }}
          </button>
        </div>
      </div>
    </div>
  `
})
export class ConfirmModalComponent {
  @Input() title = 'Confirm Action';
  @Input() message = 'Are you sure you want to proceed?';
  @Input() confirmText = 'Confirm';
  @Input() cancelText = 'Cancel';
  @Input() isDanger = false;

  @Output() confirm = new EventEmitter<void>();
  @Output() cancel = new EventEmitter<void>();
}
