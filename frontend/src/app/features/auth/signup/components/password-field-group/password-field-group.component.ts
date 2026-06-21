import { Component, Input, Output, EventEmitter, signal } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { resetFormFields, isPasswordValid } from '../../../../../shared';

@Component({
  selector: 'app-password-field-group',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="space-y-5">
      <div>
        <div class="flex items-center justify-between mb-2">
          <label class="block text-sm font-medium text-primary-700 dark:text-primary-300"
            >Password</label
          >
          <button
            type="button"
            (click)="showPolicyModal.emit(true)"
            class="text-[10px] font-bold text-brand-blue hover:underline"
          >
            Password Policy
          </button>
        </div>

        <div class="relative">
          <input
            [(ngModel)]="password"
            (ngModelChange)="passwordChange.emit($event)"
            name="password"
            [type]="showPassword() ? 'text' : 'password'"
            required
            placeholder="••••••••"
            class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
          />
          <button
            type="button"
            (click)="showPassword.update(v => !v)"
            class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 dark:hover:text-primary-300 transition-colors"
          >
            @if (!showPassword()) {
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                ></path>
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                ></path>
              </svg>
            }
            @if (showPassword()) {
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"
                ></path>
              </svg>
            }
          </button>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
          >Confirm Password</label
        >
        <div class="relative">
          <input
            [(ngModel)]="confirmPassword"
            (ngModelChange)="confirmPasswordChange.emit($event)"
            name="confirmPassword"
            [type]="showConfirmPassword() ? 'text' : 'password'"
            required
            placeholder="••••••••"
            class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
          />
          <button
            type="button"
            (click)="showConfirmPassword.update(v => !v)"
            class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-primary-400 hover:text-primary-600 dark:hover:text-primary-300 transition-colors"
          >
            @if (!showConfirmPassword()) {
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                ></path>
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                ></path>
              </svg>
            }
            @if (showConfirmPassword()) {
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.97 9.97 0 011.563-3.04m4.533-4.533A9.93 9.93 0 0112 5c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21m-2.122-2.122L3 3m5.303 5.303a3 3 0 104.243 4.243"
                ></path>
              </svg>
            }
          </button>
        </div>
      </div>

      <!-- Password Feedback (Requirements and Matching) -->
      @if (password) {
        <div class="mt-2 space-y-1">
          @for (req of getRequirements(password); track req) {
            @if (!req.met) {
              <div class="flex items-center gap-1.5 text-red-500 animate-fade-in">
                <svg class="w-3 h-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  ></path>
                </svg>
                <span class="text-[10px] font-medium leading-none">{{ req.label }} required</span>
              </div>
            }
          }
          @if (confirmPassword && password !== confirmPassword) {
            <div class="flex items-center gap-1.5 text-red-500 animate-fade-in">
              <svg class="w-3 h-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                ></path>
              </svg>
              <span class="text-[10px] font-medium leading-none">Passwords must match</span>
            </div>
          }
          @if (confirmPassword && password === confirmPassword) {
            <div
              class="flex items-center gap-1.5 text-green-600 dark:text-green-400 animate-fade-in"
            >
              <svg class="w-3 h-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="3"
                  d="M5 13l4 4L19 7"
                ></path>
              </svg>
              <span class="text-[10px] font-medium leading-none">Passwords match</span>
            </div>
          }
        </div>
      }
    </div>
  `,
})
export class PasswordFieldGroupComponent {
  @Input() password = '';
  @Input() confirmPassword = '';

  @Output() passwordChange = new EventEmitter<string>();
  @Output() confirmPasswordChange = new EventEmitter<string>();
  @Output() showPolicyModal = new EventEmitter<boolean>();

  showPassword = signal(false);
  showConfirmPassword = signal(false);

  isValid(pass: string): boolean {
    return isPasswordValid(pass);
  }

  getRequirements(pass: string) {
    return resetFormFields(pass);
  }
}
