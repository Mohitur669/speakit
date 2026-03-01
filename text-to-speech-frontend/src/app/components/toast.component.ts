import { Component, Input, OnChanges, SimpleChanges } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
    selector: 'app-toast',
    standalone: true,
    imports: [CommonModule],
    template: `
    <div
      *ngIf="visible"
      [ngClass]="{
        'toast-container': true,
        'toast-success': type === 'success',
        'toast-error': type === 'error'
      }">
      <div class="toast-content">{{ message }}</div>
    </div>
  `,
    styles: [`
    .toast-container {
      position: fixed;
      bottom: 24px;
      right: 24px;
      padding: 16px 24px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      font-family: 'Inter', sans-serif;
      font-weight: 600;
      font-size: 14px;
      animation: slideInToast 0.3s ease-out;
      z-index: 9999;
      max-width: 300px;
    }

    .toast-success {
      background-color: #10b981;
      color: white;
    }

    .toast-error {
      background-color: #ef4444;
      color: white;
    }

    .toast-content {
      word-break: break-word;
    }

    @keyframes slideInToast {
      from {
        opacity: 0;
        transform: translateX(100px);
      }
      to {
        opacity: 1;
        transform: translateX(0);
      }
    }

    @media (max-width: 640px) {
      .toast-container {
        bottom: 16px;
        right: 16px;
        left: 16px;
        max-width: none;
      }
    }
  `]
})
export class ToastComponent implements OnChanges {
    @Input() message = '';
    @Input() type: 'success' | 'error' = 'success';
    @Input() visible = false;

    ngOnChanges(changes: SimpleChanges): void {
        if (changes['visible'] && this.visible) {
            setTimeout(() => {
                this.visible = false;
            }, 3000);
        }
    }
}
