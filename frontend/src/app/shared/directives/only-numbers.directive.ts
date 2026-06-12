import { Directive, HostListener } from '@angular/core';

@Directive({
  selector: '[appOnlyNumbers]',
  standalone: true
})
export class OnlyNumbersDirective {
  @HostListener('keydown', ['$event'])
  onKeyDown(event: KeyboardEvent): void {
    const key = event.key;
    const keyCode = event.keyCode;

    // Allow: Backspace, Tab, End, Home, Left, Right, Delete, Enter, Escape
    const allowedKeys = [
      'Backspace', 'Tab', 'End', 'Home', 'ArrowLeft', 'ArrowRight', 'Delete', 'Enter', 'Escape'
    ];

    if (
      allowedKeys.indexOf(key) !== -1 ||
      // Allow: Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X
      (event.ctrlKey === true || event.metaKey === true) && 
      ['a', 'c', 'v', 'x'].indexOf(key.toLowerCase()) !== -1 ||
      // Allow: standard numbers
      (keyCode >= 48 && keyCode <= 57) ||
      // Allow: numpad numbers
      (keyCode >= 96 && keyCode <= 105)
    ) {
      // Let it happen, don't do anything
      return;
    }

    // Ensure that it is a number and stop the keypress
    if (key === ' ' || isNaN(Number(key))) {
      event.preventDefault();
    }
  }
}
