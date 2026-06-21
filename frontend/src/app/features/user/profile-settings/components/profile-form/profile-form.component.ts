import { Component, Input, Output, EventEmitter, signal, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Country } from '../../../../../shared/models/country.model';
import {
  OnlyNumbersDirective,
  handleUsernameInput,
  handleEmailInput,
  handlePhoneInput,
  COUNTRIES,
  OtpInputComponent,
} from '../../../../../shared';
import { Subject } from 'rxjs';

import { CountrySelectorComponent } from '../../../../../shared/components/country-selector/country-selector.component';

@Component({
  selector: 'app-profile-form',
  standalone: true,
  imports: [CommonModule, FormsModule, OnlyNumbersDirective, CountrySelectorComponent, OtpInputComponent],
  template: `
    <section class="space-y-6">
      <div class="flex items-center gap-2 border-b border-primary-100 dark:border-primary-800 pb-2">
        <svg class="w-5 h-5 text-brand-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
          ></path>
        </svg>
        <h2 class="text-lg font-semibold text-primary-800 dark:text-primary-200">
          Basic Information
        </h2>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300 mb-2"
            >Username</label
          >
          <input
            [(ngModel)]="username"
            (input)="onUsernameInput()"
            name="username"
            type="text"
            required
            class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
            [ngClass]="{ 'border-red-500': usernameTaken }"
          />
          @if (usernameTaken) {
            <p class="text-xs text-red-500 mt-1">Username is already taken</p>
          }
        </div>

        <div>
          <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300 mb-2"
            >Email Address</label
          >
          @if (pendingEmail) {
            <div class="p-4 rounded-xl bg-blue-50 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-800 text-sm space-y-4">
              <div>
                @if (pendingEmail.toLowerCase() !== email.toLowerCase()) {
                  <p class="font-semibold text-blue-800 dark:text-blue-300">Email change pending: <span class="underline">{{ pendingEmail }}</span></p>
                  <p class="text-xs text-primary-500 dark:text-primary-400 mt-1">
                    Your current login email (<strong class="lowercase">{{ email }}</strong>) remains active until the new one is verified.
                  </p>
                } @else {
                  <p class="font-semibold text-blue-800 dark:text-blue-300">Profile update pending verification</p>
                  <p class="text-xs text-primary-500 dark:text-primary-400 mt-1">
                    Please enter the verification code sent to <strong class="lowercase">{{ email }}</strong> to apply your changes.
                  </p>
                }
              </div>

              <div class="space-y-2">
                <label class="block text-xs font-semibold text-primary-600 dark:text-primary-400">Enter 6-Digit Verification Code</label>
                <app-otp-input
                  [disabled]="verifyingOtp"
                  [hasError]="!!otpError"
                  (valueChange)="otp = $event; otpChange.emit($event)"
                  (complete)="onOtpComplete($event)"
                ></app-otp-input>
                @if (otpError) {
                  <p class="text-xs text-red-500 mt-1 animate-fade-in">{{ otpError }}</p>
                }
              </div>

              <div class="flex items-center gap-3 pt-2">
                <button
                  type="button"
                  (click)="onCancel()"
                  class="px-4 py-2 rounded-lg bg-primary-100 dark:bg-primary-800 text-primary-700 dark:text-primary-200 text-xs font-bold hover:bg-primary-200 dark:hover:bg-primary-700 transition-all active:scale-95"
                >
                  Cancel Change
                </button>
                <button
                  type="button"
                  (click)="onResend()"
                  [disabled]="resendCooldown > 0 || resending"
                  class="px-4 py-2 rounded-lg bg-brand-blue text-white text-xs font-bold hover:bg-blue-600 disabled:opacity-50 transition-all active:scale-95"
                >
                  {{ resending ? 'Resending...' : resendCooldown > 0 ? 'Resend in ' + resendCooldown + 's' : 'Resend Code' }}
                </button>
              </div>
            </div>
          } @else {
            <input
              [(ngModel)]="email"
              (input)="onEmailInput()"
              name="email"
              type="email"
              required
              class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all lowercase"
              [ngClass]="{ 'border-red-500': emailTaken }"
            />
            @if (emailTaken) {
              <p class="text-xs text-red-500 mt-1">Email is already taken</p>
            }
          }
        </div>

        <div class="md:col-span-2">
          <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300 mb-2"
            >Phone Number</label
          >
          <div class="flex items-stretch gap-2">
            <app-country-selector
              [(selectedCountry)]="selectedCountry"
              [phoneSubject]="phoneSubject"
              [phoneNumber]="phoneNumber"
            >
            </app-country-selector>

            <input
              [(ngModel)]="phoneNumber"
              (input)="onPhoneInput()"
              appOnlyNumbers
              name="phoneNumber"
              type="tel"
              required
              inputmode="numeric"
              pattern="[0-9]*"
              placeholder="9876543210"
              class="flex-1 min-w-0 px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white text-sm placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
              [ngClass]="{ 'border-red-500': phoneTaken }"
            />
          </div>
          @if (phoneTaken) {
            <p class="text-xs text-red-500 mt-1">Phone number is already taken</p>
          }
        </div>
      </div>
    </section>
  `,
})
export class ProfileFormComponent {
  @Input() username = '';
  @Input() email = '';
  @Input() phoneNumber = '';
  @Input() selectedCountry!: Country;
  @Input() usernameTaken = false;
  @Input() emailTaken = false;
  @Input() phoneTaken = false;

  @Input() pendingEmail: string | null = null;
  @Input() verifyingOtp = false;
  @Input() otpError = '';
  @Input() resendCooldown = 0;
  @Input() resending = false;

  @Output() usernameChange = new EventEmitter<string>();
  @Output() emailChange = new EventEmitter<string>();
  @Output() phoneNumberChange = new EventEmitter<string>();
  @Output() selectedCountryChange = new EventEmitter<Country>();

  @Output() otpChange = new EventEmitter<string>();
  @Output() verifyOtp = new EventEmitter<string>();
  @Output() resendOtp = new EventEmitter<void>();
  @Output() cancelEmailChange = new EventEmitter<void>();

  @Input() usernameSubject!: Subject<string>;
  @Input() emailSubject!: Subject<string>;
  @Input() phoneSubject!: Subject<string>;

  otp = '';

  onUsernameInput() {
    this.username = handleUsernameInput(this.username, this.usernameSubject);
    this.usernameChange.emit(this.username);
  }

  onEmailInput() {
    this.email = handleEmailInput(this.email, this.emailSubject);
    this.emailChange.emit(this.email);
  }

  onPhoneInput() {
    this.phoneNumber = handlePhoneInput(this.phoneNumber, this.phoneSubject);
    this.phoneNumberChange.emit(this.phoneNumber);
  }

  onOtpComplete(code: string) {
    this.verifyOtp.emit(code);
  }

  onCancel() {
    this.cancelEmailChange.emit();
  }

  onResend() {
    this.resendOtp.emit();
  }
}
