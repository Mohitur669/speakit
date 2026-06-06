import { Subject, debounceTime, takeUntil } from 'rxjs';
import { WritableSignal } from '@angular/core';
import { Country } from '../models/country.model';

export const COUNTRIES = [
  { name: 'India', code: '+91', flag: '🇮🇳' },
  { name: 'United States', code: '+1', flag: '🇺🇸' },
  { name: 'United Kingdom', code: '+44', flag: '🇬🇧' },
  { name: 'Australia', code: '+61', flag: '🇦🇺' },
  { name: 'Canada', code: '+1', flag: '🇨🇦' },
  { name: 'China', code: '+86', flag: '🇨🇳' },
  { name: 'France', code: '+33', flag: '🇫🇷' },
  { name: 'Germany', code: '+49', flag: '🇩🇪' },
  { name: 'Japan', code: '+81', flag: '🇯🇵' },
  { name: 'Singapore', code: '+65', flag: '🇸🇬' },
  { name: 'United Arab Emirates', code: '+971', flag: '🇦🇪' },
  { name: 'Saudi Arabia', code: '+966', flag: '🇸🇦' },
  { name: 'Netherlands', code: '+31', flag: '🇳🇱' },
  { name: 'Ireland', code: '+353', flag: '🇮🇪' },
  { name: 'New Zealand', code: '+64', flag: '🇳🇿' },
  { name: 'South Africa', code: '+27', flag: '🇿🇦' },
  { name: 'Malaysia', code: '+60', flag: '🇲🇾' },
  { name: 'Indonesia', code: '+62', flag: '🇮🇩' },
  { name: 'Thailand', code: '+66', flag: '🇹🇭' },
];

/**
 * Returns the list of password requirements and their met status.
 */
export function resetFormFields(pass: string) {
  return [
    { label: '8+ Characters', met: pass.length >= 8 },
    { label: 'Lowercase (a-z)', met: /[a-z]/.test(pass) },
    { label: 'Uppercase (A-Z)', met: /[A-Z]/.test(pass) },
    { label: 'Numbers (0-9)', met: /[0-9]/.test(pass) },
    { label: 'Special Char (!@#)', met: /[!@#$%^&*(),.?":{}|<>]/.test(pass) }
  ];
}

/**
 * Encapsulates the availability check subscription logic.
 */
export function mapValidationErrors(
  config: {
    usernameSubject: Subject<string>,
    emailSubject: Subject<string>,
    phoneSubject: Subject<string>,
    usernameTaken: WritableSignal<boolean>,
    emailTaken: WritableSignal<boolean>,
    phoneTaken: WritableSignal<boolean>,
    destroy$: Subject<void>,
    authService: any,
    selectedCountryCode: () => string,
    currentUsername?: string | null,
    currentEmail?: string | null,
    currentPhone?: string | null
  }
) {
  config.usernameSubject.pipe(debounceTime(500), takeUntil(config.destroy$)).subscribe(val => {
    if (!val || (config.currentUsername && val.toLowerCase() === config.currentUsername.toLowerCase())) {
      config.usernameTaken.set(false);
      return;
    }
    config.authService.checkUsername(val).subscribe((taken: boolean) => config.usernameTaken.set(taken));
  });

  config.emailSubject.pipe(debounceTime(500), takeUntil(config.destroy$)).subscribe(val => {
    if (!val || (config.currentEmail && val.toLowerCase() === config.currentEmail.toLowerCase())) {
      emailTaken.set(false);
      return;
    }
    config.authService.checkEmail(val).subscribe((taken: boolean) => config.emailTaken.set(taken));
  });

  config.phoneSubject.pipe(debounceTime(500), takeUntil(config.destroy$)).subscribe(val => {
    const fullPhone = config.selectedCountryCode() + val.replace(/\D/g, '');
    if (!val || (config.currentPhone && fullPhone === config.currentPhone)) {
      phoneTaken.set(false);
      return;
    }
    config.authService.checkPhone(fullPhone).subscribe((taken: boolean) => config.phoneTaken.set(taken));
  });
}

/**
 * Shared form field initialization metadata.
 */
export function buildFormFields() {
  return {
    countries: COUNTRIES,
    defaultCountry: COUNTRIES[0]
  };
}

export function handleUsernameInput(username: string, subject: Subject<string>) {
  const val = username.toLowerCase();
  subject.next(val);
  return val;
}

export function handleEmailInput(email: string, subject: Subject<string>) {
  const val = email.toLowerCase();
  subject.next(val);
  return val;
}

export function handlePhoneInput(phone: string, subject: Subject<string>) {
  const val = phone.replace(/\D/g, '');
  subject.next(val);
  return val;
}

export function toggleDropdown(event: Event, showDropdown: WritableSignal<boolean>) {
  event.stopPropagation();
  showDropdown.update(v => !v);
}

export function selectCountry(
  country: Country, 
  event: Event, 
  selectedCountry: WritableSignal<Country>, 
  showDropdown: WritableSignal<boolean>,
  phoneSubject: Subject<string>,
  phoneNumber: string
) {
  event.stopPropagation();
  selectedCountry.set(country);
  showDropdown.set(false);
  phoneSubject.next(phoneNumber);
}
