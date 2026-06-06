import { Component, Input, Output, EventEmitter, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { resetFormFields, isPasswordValid } from '../../../../shared';

@Component({
  selector: 'app-password-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <section class="space-y-6">
      <div class="flex items-center justify-between border-b border-primary-100 dark:border-primary-800 pb-2">
        <div class="flex items-center gap-2">
          <svg class="w-5 h-5 text-brand-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
          </svg>
          <h2 class="text-lg font-semibold text-primary-800 dark:text-primary-200">Security</h2>
        </div>
        <button type="button" (click)="togglePasswordFields()" 
          class="text-sm font-medium text-brand-blue hover:text-blue-600 transition-colors">
          {{ showPasswordFields() ? 'Cancel Change' : 'Change Password' }}
        </button>
      </div>

      <div *ngIf="showPasswordFields()" class="space-y-6 animate-slide-up">
        <div>
          <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Current Password</label>
          <div class="relative">
            <input [(ngModel)]="currentPassword" (ngModelChange)="currentPasswordChange.emit($event)" name="currentPassword" [type]="showCurrPass ? 'text' : 'password'"
              class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
            <button type="button" (click)="showCurrPass = !showCurrPass" class="absolute right-4 top-1/2 -translate-y-1/2 text-primary-400 hover:text-primary-600">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path *ngIf="!showCurrPass" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                <path *ngIf="showCurrPass" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18"></path>
              </svg>
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-sm font-medium text-primary-700 dark:text-primary-300">New Password</label>
              <button type="button" (click)="showPolicyModal.emit(true)" class="text-[10px] font-bold text-brand-blue hover:underline">
                Password Policy
              </button>
            </div>
            <div class="relative">
              <input [(ngModel)]="newPassword" (ngModelChange)="newPasswordChange.emit($event)" name="newPassword" [type]="showNewPass ? 'text' : 'password'"
                class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
              <button type="button" (click)="showNewPass = !showNewPass" class="absolute right-4 top-1/2 -translate-y-1/2 text-primary-400 hover:text-primary-600">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path *ngIf="!showNewPass" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                  <path *ngIf="showNewPass" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18"></path>
                </svg>
              </button>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Confirm New Password</label>
            <div class="relative">
              <input [(ngModel)]="confirmPassword" (ngModelChange)="confirmPasswordChange.emit($event)" name="confirmPassword" [type]="showConfirmPass ? 'text' : 'password'"
                class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
              <button type="button" (click)="showConfirmPass = !showConfirmPass" class="absolute right-4 top-1/2 -translate-y-1/2 text-primary-400 hover:text-primary-600">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path *ngIf="!showConfirmPass" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                  <path *ngIf="showConfirmPass" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18"></path>
                </svg>
              </button>
            </div>
          </div>
        </div>

        <div *ngIf="newPassword" class="p-4 rounded-xl bg-primary-50 dark:bg-primary-800/50 border border-primary-100 dark:border-primary-700">
          <p class="text-xs font-semibold text-primary-500 dark:text-primary-400 mb-3 uppercase tracking-wider">Password Requirements</p>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <div *ngFor="let req of getPasswordRequirements(newPassword)" 
              class="flex items-center gap-2 text-xs transition-all"
              [ngClass]="req.met ? 'text-green-600 dark:text-green-400' : 'text-primary-400 dark:text-primary-500'">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path *ngIf="req.met" stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
                <circle *ngIf="!req.met" cx="12" cy="12" r="8" stroke-width="2"></circle>
              </svg>
              {{ req.label }}
            </div>
          </div>
        </div>
      </div>
    </section>
  `
})
export class PasswordFormComponent {
  @Input() currentPassword = '';
  @Input() newPassword = '';
  @Input() confirmPassword = '';
  
  @Output() currentPasswordChange = new EventEmitter<string>();
  @Output() newPasswordChange = new EventEmitter<string>();
  @Output() confirmPasswordChange = new EventEmitter<string>();
  @Output() showPolicyModal = new EventEmitter<boolean>();

  showPasswordFields = signal(false);
  showNewPass = false;
  showCurrPass = false;
  showConfirmPass = false;

  togglePasswordFields() {
    this.showPasswordFields.update(v => !v);
    if (!this.showPasswordFields()) {
      this.newPassword = '';
      this.confirmPassword = '';
      this.newPasswordChange.emit('');
      this.confirmPasswordChange.emit('');
    }
  }

  getPasswordRequirements(pass: string) {
    return resetFormFields(pass);
  }
}
