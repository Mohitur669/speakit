import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Country } from '../../../../../shared/models/country.model';
import {
  OnlyNumbersDirective,
  handleUsernameInput,
  handleEmailInput,
  handlePhoneInput,
} from '../../../../../shared';
import { Subject } from 'rxjs';

import { CountrySelectorComponent } from '../../../../../shared/components/country-selector/country-selector.component';

@Component({
  selector: 'app-profile-form',
  standalone: true,
  imports: [CommonModule, FormsModule, OnlyNumbersDirective, CountrySelectorComponent],
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
        </div>

        <div class="md:col-span-2">
          <label class="block text-sm font-semibold text-primary-700 dark:text-primary-300 mb-2"
            >Phone Number</label
          >
          <div class="flex items-stretch gap-2">
            <app-country-selector
              [selectedCountry]="selectedCountry"
              (selectedCountryChange)="onCountryChange($event)"
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

  @Output() usernameChange = new EventEmitter<string>();
  @Output() emailChange = new EventEmitter<string>();
  @Output() phoneNumberChange = new EventEmitter<string>();
  @Output() selectedCountryChange = new EventEmitter<Country>();

  @Input() usernameSubject!: Subject<string>;
  @Input() emailSubject!: Subject<string>;
  @Input() phoneSubject!: Subject<string>;

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

  onCountryChange(country: Country) {
    this.selectedCountry = country;
    this.selectedCountryChange.emit(country);
  }
}
