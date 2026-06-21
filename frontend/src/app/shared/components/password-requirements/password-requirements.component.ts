import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { resetFormFields } from '../../utils/form.utils';

@Component({
  selector: 'app-password-requirements',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (password) {
      <div class="mt-2 space-y-1 animate-fade-in">
        @for (req of getRequirements(password); track req) {
          @if (!req.met) {
            <div class="flex items-center gap-1.5 text-red-500">
              <svg class="w-3 h-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
              <span class="text-[10px] font-medium leading-none">{{ req.label }} required</span>
            </div>
          }
        }
        @if (confirmPassword && password !== confirmPassword) {
          <div class="flex items-center gap-1.5 text-red-500">
            <svg class="w-3 h-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
            <span class="text-[10px] font-medium leading-none">Passwords must match</span>
          </div>
        }
        @if (confirmPassword && password === confirmPassword) {
          <div class="flex items-center gap-1.5 text-green-600 dark:text-green-400">
            <svg class="w-3 h-3 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
            </svg>
            <span class="text-[10px] font-medium leading-none">Passwords match</span>
          </div>
        }
      </div>
    }
  `
})
export class PasswordRequirementsComponent {
  @Input() password: string | null | undefined = '';
  @Input() confirmPassword: string | null | undefined = '';

  getRequirements(pass: string | null | undefined) {
    return resetFormFields(pass);
  }
}
