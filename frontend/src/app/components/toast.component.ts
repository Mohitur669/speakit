import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-toast',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div *ngIf="visible" 
      class="fixed bottom-6 right-6 z-[9999] animate-slide-in-right">
      <div [ngClass]="{
        'flex items-center gap-3 px-6 py-4 rounded-2xl shadow-2xl backdrop-blur-xl border font-bold text-sm': true,
        'bg-emerald-500/90 border-emerald-400/20 text-white': type === 'success',
        'bg-red-500/90 border-red-400/20 text-white': type === 'error'
      }">
        <span *ngIf="type === 'success'">✅</span>
        <span *ngIf="type === 'error'">⚠️</span>
        {{ message }}
      </div>
    </div>
  `,
  styles: [`
    @keyframes slideInRight {
      from { opacity: 0; transform: translateX(50px) scale(0.9); }
      to { opacity: 1; transform: translateX(0) scale(1); }
    }
    .animate-slide-in-right {
      animation: slideInRight 0.4s cubic-bezier(0.16, 1, 0.3, 1) both;
    }
  `]
})
export class ToastComponent {
  @Input() message = '';
  @Input() type: 'success' | 'error' = 'success';
  @Input() visible = false;
}
