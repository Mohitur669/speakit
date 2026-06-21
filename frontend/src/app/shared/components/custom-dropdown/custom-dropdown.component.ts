import {
  Component,
  Input,
  Output,
  EventEmitter,
  signal,
  HostListener,
  ElementRef,
  inject,
} from '@angular/core';

export interface DropdownOption {
  value: string;
  label: string;
}

@Component({
  selector: 'app-custom-dropdown',
  standalone: true,
  imports: [],
  template: `
    <div class="relative w-full" #dropdownRef>
      <button
        type="button"
        (click)="toggle()"
        [disabled]="disabled"
        class="w-full flex items-center justify-between px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all disabled:opacity-60 disabled:cursor-not-allowed disabled:grayscale-[0.5]"
        [class.border-brand-blue]="isOpen()"
      >
        <span class="text-sm font-medium">{{ selectedOption?.label || placeholder }}</span>
        <svg
          class="w-4 h-4 text-primary-400 transition-transform duration-200"
          [class.rotate-180]="isOpen()"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M19 9l-7 7-7-7"
          ></path>
        </svg>
      </button>

      @if (isOpen()) {
        <div
          class="absolute z-50 w-full mt-2 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 rounded-xl shadow-2xl overflow-hidden animate-fade-in"
        >
          <div class="max-h-60 overflow-y-auto custom-scrollbar">
            @for (option of options; track option) {
              <button
                type="button"
                (click)="select(option)"
                class="w-full flex items-center gap-3 px-4 py-3 text-sm text-left transition-colors"
                [class.bg-primary-50]="option.value === value"
                [class.dark:bg-primary-800]="option.value === value"
                [class.text-brand-blue]="option.value === value"
                [class.font-bold]="option.value === value"
                [class.text-primary-700]="option.value !== value"
                [class.dark:text-primary-200]="option.value !== value"
                [class.hover:bg-primary-50]="option.value !== value"
                [class.dark:hover:bg-primary-800]="option.value !== value"
              >
                {{ option.label }}
              </button>
            }
          </div>
        </div>
      }
    </div>
  `,
  styles: [
    `
      :host {
        display: block;
      }
      .animate-fade-in {
        animation: fadeIn 0.15s ease-out;
      }
      @keyframes fadeIn {
        from {
          opacity: 0;
          transform: translateY(-4px);
        }
        to {
          opacity: 1;
          transform: translateY(0);
        }
      }
    `,
  ],
})
export class CustomDropdownComponent {
  private elementRef = inject(ElementRef);

  @Input() options: DropdownOption[] = [];
  @Input() value: string = '';
  @Input() placeholder: string = 'Select an option';
  @Input() disabled: boolean = false;

  @Output() valueChange = new EventEmitter<string>();

  isOpen = signal(false);

  get selectedOption() {
    return this.options.find((o) => o.value === this.value);
  }

  toggle() {
    if (this.disabled) return;
    this.isOpen.update((v) => !v);
  }

  select(option: DropdownOption) {
    this.value = option.value;
    this.valueChange.emit(option.value);
    this.isOpen.set(false);
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent) {
    if (!this.elementRef.nativeElement.contains(event.target)) {
      this.isOpen.set(false);
    }
  }
}
