import { Component, Input, Output, EventEmitter, OnInit, ElementRef, ViewChildren, QueryList } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-otp-input',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="flex flex-col items-center gap-2">
      <div 
        class="flex gap-2 justify-center" 
        role="group" 
        [attr.aria-label]="ariaLabel"
      >
        @for (cell of cells; track $index) {
          <input
            #cellInput
            type="text"
            inputmode="numeric"
            pattern="[0-9]*"
            maxLength="1"
            [attr.aria-label]="'Digit ' + ($index + 1) + ' of ' + length"
            [disabled]="disabled"
            [(ngModel)]="cells[$index]"
            (keydown)="onKeyDown($event, $index)"
            (input)="onInput($event, $index)"
            (paste)="onPaste($event, $index)"
            (focus)="onFocus($index)"
            [ngClass]="{
              'border-red-500 dark:border-red-500 focus:ring-red-500/50 focus:border-red-500 border-2': hasError,
              'border-green-500 dark:border-green-500 focus:ring-green-500/50 focus:border-green-500 border-2': hasSuccess,
              'border-primary-200 dark:border-primary-700': !hasError && !hasSuccess
            }"
            class="w-12 h-12 rounded-xl bg-primary-50 dark:bg-primary-800 border text-primary-900 dark:text-white text-center font-bold text-lg focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all shadow-sm"
          />
        }
      </div>
    </div>
  `
})
export class OtpInputComponent implements OnInit {
  @Input() length = 6;
  @Input() ariaLabel = 'Enter the verification code sent to your email';
  @Input() disabled = false;
  @Input() hasError = false;
  @Input() hasSuccess = false;

  @Output() complete = new EventEmitter<string>();
  @Output() valueChange = new EventEmitter<string>();

  @ViewChildren('cellInput') cellInputs!: QueryList<ElementRef<HTMLInputElement>>;

  cells: string[] = [];

  ngOnInit() {
    this.cells = Array(this.length).fill('');
  }

  // Clear all cells and focus the first one
  clear() {
    this.cells = Array(this.length).fill('');
    this.valueChange.emit('');
    setTimeout(() => {
      this.focusCell(0);
    });
  }

  focusCell(index: number) {
    const inputs = this.cellInputs.toArray();
    if (inputs[index]) {
      inputs[index].nativeElement.focus();
    }
  }

  onKeyDown(event: KeyboardEvent, index: number) {
    const target = event.target as HTMLInputElement;

    if (event.key === 'Backspace') {
      if (!this.cells[index] && index > 0) {
        // Move to previous cell and clear it
        this.cells[index - 1] = '';
        this.focusCell(index - 1);
        this.emitValue();
        event.preventDefault();
      } else {
        // Clear current cell
        this.cells[index] = '';
        this.emitValue();
      }
    } else if (event.key === 'ArrowLeft') {
      if (index > 0) {
        this.focusCell(index - 1);
        event.preventDefault();
      }
    } else if (event.key === 'ArrowRight') {
      if (index < this.length - 1) {
        this.focusCell(index + 1);
        event.preventDefault();
      }
    } else if (event.key === 'Tab') {
      // Allow normal tab navigation
    } else if (!/^[0-9]$/.test(event.key) && !event.ctrlKey && !event.metaKey) {
      // Block non-numeric characters
      event.preventDefault();
    }
  }

  onInput(event: Event, index: number) {
    const inputVal = this.cells[index];
    
    // Ensure only digits are kept
    if (inputVal && !/^[0-9]$/.test(inputVal)) {
      this.cells[index] = '';
      return;
    }

    if (inputVal && index < this.length - 1) {
      // Advance to next cell
      this.focusCell(index + 1);
    }

    this.emitValue();
  }

  onFocus(index: number) {
    // Select input value on focus for easier correction
    const inputs = this.cellInputs.toArray();
    if (inputs[index]) {
      inputs[index].nativeElement.select();
    }
  }

  onPaste(event: ClipboardEvent, index: number) {
    event.preventDefault();
    const pastedData = event.clipboardData?.getData('text') || '';
    const digitsOnly = pastedData.replace(/\D/g, '').substring(0, this.length);

    if (digitsOnly.length > 0) {
      for (let i = 0; i < digitsOnly.length; i++) {
        this.cells[i] = digitsOnly[i];
      }
      this.emitValue();
      
      const nextFocus = Math.min(digitsOnly.length, this.length - 1);
      this.focusCell(nextFocus);
    }
  }

  emitValue() {
    const val = this.cells.join('');
    this.valueChange.emit(val);
    if (val.length === this.length) {
      this.complete.emit(val);
    }
  }
}
