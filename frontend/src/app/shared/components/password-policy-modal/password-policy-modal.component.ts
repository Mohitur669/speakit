import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { resetFormFields } from '../../utils/form.utils';

@Component({
  selector: 'app-password-policy-modal',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in" (click)="close.emit()">
      <div class="bg-white dark:bg-primary-900 rounded-2xl p-6 w-full max-w-xs border border-primary-200 dark:border-primary-700 shadow-2xl animate-scale-up" (click)="$event.stopPropagation()">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider">Password Policy</h3>
          <button (click)="close.emit()" class="p-1 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 transition-colors">
            <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
          </button>
        </div>
        <div class="space-y-3">
          <div *ngFor="let req of getRequirements(password)" class="flex items-center gap-3">
            <div class="w-5 h-5 rounded-full flex items-center justify-center transition-colors"
              [ngClass]="req.met ? 'bg-green-500 text-white' : 'bg-primary-100 dark:bg-primary-800 text-primary-400'">
              <svg *ngIf="req.met" class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
              <svg *ngIf="!req.met" class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m0 0v2m0-2h2m-2 0H10m1-11a4 4 0 00-4 4v3H5v7h14v-7h-2V8a4 4 0 00-4-4z"></path></svg>
            </div>
            <span class="text-xs font-medium" [ngClass]="req.met ? 'text-green-600 dark:text-green-400' : 'text-primary-600 dark:text-primary-300'">{{ req.label }}</span>
          </div>
        </div>
        <button (click)="close.emit()" class="w-full mt-6 py-2 bg-brand-blue text-white text-xs font-bold rounded-xl shadow-lg active:scale-95 transition-all">
          Got it
        </button>
      </div>
    </div>
  `
})
export class PasswordPolicyModalComponent {
  @Input() password = '';
  @Output() close = new EventEmitter<void>();

  getRequirements(pass: string) {
    return resetFormFields(pass);
  }
}
