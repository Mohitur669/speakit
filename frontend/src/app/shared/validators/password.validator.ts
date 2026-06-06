import { AbstractControl, ValidationErrors, ValidatorFn } from '@angular/forms';

export function isPasswordValid(pass: string): boolean {
  return pass.length >= 8 &&
         /[a-z]/.test(pass) &&
         /[A-Z]/.test(pass) &&
         /[0-9]/.test(pass) &&
         /[!@#$%^&*(),.?":{}|<>]/.test(pass);
}

export function passwordStrengthValidator(): ValidatorFn {
  return (control: AbstractControl): ValidationErrors | null =>
    isPasswordValid(control.value) ? null : { weakPassword: true };
}
