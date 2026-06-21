import { Component, Input, Output, EventEmitter, signal, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Country } from '../../models/country.model';
import { COUNTRIES, toggleDropdown, selectCountry } from '../../utils/form.utils';
import { Subject } from 'rxjs';

@Component({
  selector: 'app-country-selector',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="relative w-20 shrink-0 h-full">
      <button
        type="button"
        (click)="onToggleDropdown($event)"
        class="w-full h-full flex items-center justify-between gap-1 px-2 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white transition-all text-xs sm:text-sm hover:border-brand-blue/50"
      >
        <span class="flex items-center gap-1">
          <span>{{ selectedCountry.flag }}</span>
          <span class="font-medium">{{ selectedCountry.code }}</span>
        </span>
        <svg
          [ngClass]="showDropdown() ? 'rotate-180' : ''"
          class="w-3 h-3 text-primary-400 transition-transform"
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

      <!-- Dropdown -->
      @if (showDropdown()) {
        <div
          class="absolute top-full left-0 mt-2 w-64 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 rounded-xl shadow-2xl z-[100] overflow-hidden animate-fade-in"
        >
          <div class="p-2 border-b border-primary-100 dark:border-primary-800">
            <input
              [(ngModel)]="searchQuery"
              name="search"
              type="text"
              placeholder="Search country..."
              (click)="$event.stopPropagation()"
              class="w-full px-3 py-2 rounded-lg bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-xs text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50"
            />
          </div>
          <div class="max-h-60 overflow-y-auto custom-scrollbar">
            @for (c of filteredCountries(); track c) {
              <button
                type="button"
                (click)="onSelectCountry(c, $event)"
                class="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-left hover:bg-primary-50 dark:hover:bg-primary-800/50 transition-colors group"
              >
                <span class="text-lg">{{ c.flag }}</span>
                <span class="flex-grow text-primary-700 dark:text-primary-200">{{ c.name }}</span>
                <span class="text-xs font-bold text-primary-400 group-hover:text-brand-blue">{{
                  c.code
                }}</span>
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
    `,
  ],
})
export class CountrySelectorComponent {
  @Input() selectedCountry!: Country;
  @Output() selectedCountryChange = new EventEmitter<Country>();

  @Input() phoneSubject?: Subject<string>;
  @Input() phoneNumber: string = '';

  showDropdown = signal(false);
  searchQuery = '';
  countries = COUNTRIES;

  @HostListener('document:click')
  closeDropdown() {
    this.showDropdown.set(false);
  }

  onToggleDropdown(event: Event) {
    toggleDropdown(event, this.showDropdown);
  }

  onSelectCountry(country: Country, event: Event) {
    if (this.phoneSubject) {
      selectCountry(
        country,
        event,
        signal(this.selectedCountry) as any,
        this.showDropdown,
        this.phoneSubject,
        this.phoneNumber,
      );
    } else {
      event.stopPropagation();
      this.showDropdown.set(false);
    }
    this.selectedCountry = country;
    this.selectedCountryChange.emit(country);
    this.searchQuery = '';
  }

  filteredCountries() {
    if (!this.searchQuery) return this.countries;
    const s = this.searchQuery.toLowerCase();
    return this.countries.filter((c) => c.name.toLowerCase().includes(s) || c.code.includes(s));
  }
}
