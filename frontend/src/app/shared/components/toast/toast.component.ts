/**
 * Reusable toast notification component for displaying
 * success and error messages with auto-dismiss.
 */
import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ToastService } from '../../../core/services/toast.service';

@Component({
  selector: 'app-toast',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (toastService.toastState().visible) {
      <div class="fixed bottom-6 right-6 z-[9999] animate-slide-up">
        <div
          [ngClass]="{
            'flex items-center gap-3 px-5 py-4 rounded-xl shadow-elevated border font-medium text-sm': true,
            'bg-white dark:bg-primary-900 border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white':
              toastService.toastState().type === 'success',
            'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800/30 text-red-600 dark:text-red-400':
              toastService.toastState().type === 'error',
            'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800/30 text-blue-600 dark:text-blue-400':
              toastService.toastState().type === 'info',
          }"
        >
          @if (toastService.toastState().type === 'success') {
            <svg
              class="w-5 h-5 text-accent-500 shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M5 13l4 4L19 7"
              ></path>
            </svg>
          }
          @if (toastService.toastState().type === 'error') {
            <svg
              class="w-5 h-5 text-red-500 shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              ></path>
            </svg>
          }
          @if (toastService.toastState().type === 'info') {
            <svg
              class="w-5 h-5 text-blue-500 shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              ></path>
            </svg>
          }
          {{ toastService.toastState().message }}
        </div>
      </div>
    }
  `,
})
export class ToastComponent {
  toastService = inject(ToastService);
}
