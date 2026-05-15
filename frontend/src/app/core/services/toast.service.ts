import { Injectable, signal } from '@angular/core';

export type ToastType = 'success' | 'error' | 'info';

export interface ToastState {
  message: string;
  type: ToastType;
  visible: boolean;
}

@Injectable({ providedIn: 'root' })
export class ToastService {
  private state = signal<ToastState>({
    message: '',
    type: 'success',
    visible: false
  });

  toastState = this.state.asReadonly();

  show(message: string, type: ToastType = 'success', duration = 3000): void {
    this.state.set({ message, type, visible: true });
    setTimeout(() => {
      // Only hide if it's the same message (prevents overlapping toasts from hiding early)
      if (this.state().message === message) {
        this.hide();
      }
    }, duration);
  }

  success(message: string): void {
    this.show(message, 'success');
  }

  error(message: string): void {
    this.show(message, 'error');
  }

  info(message: string): void {
    this.show(message, 'info');
  }

  hide(): void {
    this.state.update(s => ({ ...s, visible: false }));
  }
}
