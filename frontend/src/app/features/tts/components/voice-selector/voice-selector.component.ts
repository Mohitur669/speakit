import { Component, Input, Output, EventEmitter, signal, HostListener, computed, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Voice } from '../../../../core/services/tts.service';
import { getVoiceTypeLabel, getVoiceTypeClass } from '../../../../shared';

@Component({
  selector: 'app-voice-selector',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flex-1 bg-white dark:bg-primary-900 rounded-xl border border-primary-200 dark:border-primary-700 p-4 sm:p-6">
      <h2 class="text-lg sm:text-sm font-semibold text-primary-900 dark:text-white mb-3 sm:mb-4">Select Voice</h2>

      <!-- Filter Tabs -->
      <div class="flex gap-1 p-1 bg-primary-50 dark:bg-primary-800 rounded-lg mb-3 sm:mb-4 border border-primary-100 dark:border-transparent">

        <ng-container *ngFor="let filter of filterOptions()">
          <button *ngIf="filter !== 'All'"
            (click)="setFilter(filter)"
            [ngClass]="currentFilter() === filter ? 'bg-brand-blue text-white shadow-md' : 'text-primary-500 dark:text-primary-400 hover:text-primary-700 dark:hover:text-white'"
            class="flex-1 py-2 sm:py-1.5 text-[11px] sm:text-[10px] font-bold rounded-md transition-all duration-300 ease-in-out relative uppercase tracking-tight">

            {{ filter }}
            <span class="opacity-60 ml-0.5">({{ getFilterCount(filter) }})</span>

            <!-- Access Badge -->
            <div *ngIf="filter === 'Natural' || filter === 'Indian'"
              class="absolute -top-1 -right-1 flex items-center justify-center">

              <span *ngIf="canUseFilter(filter)" class="relative flex h-2 w-2">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent-400 opacity-75"></span>
                <span class="relative inline-flex rounded-full h-2 w-2 bg-accent-500"></span>
              </span>

              <svg *ngIf="!canUseFilter(filter)"
                class="w-3 h-3 text-amber-500" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
              </svg>
            </div>
          </button>
        </ng-container>
      </div>

      <!-- Indian Sub-Filters -->
      <div *ngIf="currentFilter() === 'Indian'" class="grid grid-cols-2 gap-3 mb-4 animate-fade-in">
        
        <!-- Language Multi-Select Dropdown -->
        <div class="relative">
          <button (click)="toggleLanguageDropdown($event)"
            class="w-full flex items-center justify-between px-3 py-2 bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 rounded-lg hover:border-brand-blue/30 transition-all text-left">
            <div>
              <p class="text-[9px] font-bold text-primary-400 uppercase tracking-wider leading-none mb-1">Language</p>
              <p class="text-[11px] font-bold text-primary-900 dark:text-white truncate max-w-[80px]">
                {{ getLanguageSummary() }}
              </p>
            </div>
            <svg class="w-3 h-3 text-primary-400 transition-transform" [ngClass]="isLanguageDropdownOpen ? 'rotate-180' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
          </button>

          <!-- Dropdown -->
          <div *ngIf="isLanguageDropdownOpen" (click)="$event.stopPropagation()"
            class="absolute top-full left-0 mt-1 w-48 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 rounded-xl shadow-elevated z-[60] max-h-60 overflow-y-auto p-2 flex flex-col gap-1">
            <button *ngFor="let lang of languageOptions()"
              (click)="toggleLanguage(lang.code)"
              class="flex items-center gap-2 w-full px-3 py-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors text-left group">
              <div class="w-4 h-4 rounded border flex items-center justify-center transition-colors shrink-0"
                [ngClass]="selectedLanguages().has(lang.code) ? 'bg-brand-blue border-brand-blue' : 'border-primary-300 dark:border-primary-600'">
                <svg *ngIf="selectedLanguages().has(lang.code)" class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
              </div>
              <span class="text-xs font-medium text-primary-700 dark:text-primary-200 group-hover:text-primary-900 dark:group-hover:text-white truncate">
                {{ lang.name }}
              </span>
            </button>
          </div>
        </div>

        <!-- Gender Multi-Select Dropdown -->
        <div class="relative">
          <button (click)="toggleGenderDropdown($event)"
            class="w-full flex items-center justify-between px-3 py-2 bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 rounded-lg hover:border-brand-blue/30 transition-all text-left">
            <div>
              <p class="text-[9px] font-bold text-primary-400 uppercase tracking-wider leading-none mb-1">Gender</p>
              <p class="text-[11px] font-bold text-primary-900 dark:text-white truncate max-w-[80px]">
                {{ getGenderSummary() }}
              </p>
            </div>
            <svg class="w-3 h-3 text-primary-400 transition-transform" [ngClass]="isGenderDropdownOpen ? 'rotate-180' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
          </button>

          <!-- Dropdown -->
          <div *ngIf="isGenderDropdownOpen" (click)="$event.stopPropagation()"
            class="absolute top-full right-0 mt-1 w-32 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 rounded-xl shadow-elevated z-[60] p-2 flex flex-col gap-1">
            <button *ngFor="let gender of genderOptions"
              (click)="toggleGender(gender)"
              class="flex items-center gap-2 w-full px-3 py-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors text-left group">
              <div class="w-4 h-4 rounded border flex items-center justify-center transition-colors shrink-0"
                [ngClass]="selectedGenders().has(gender) ? 'bg-brand-blue border-brand-blue' : 'border-primary-300 dark:border-primary-600'">
                <svg *ngIf="selectedGenders().has(gender)" class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
              </div>
              <span class="text-xs font-medium text-primary-700 dark:text-primary-200 group-hover:text-primary-900 dark:group-hover:text-white capitalize">
                {{ gender }}
              </span>
            </button>
          </div>
        </div>
      </div>

      <!-- Voice Dropdown -->
      <div class="relative">
        <button (click)="toggleDropdown($event)"
          class="w-full flex items-center justify-between px-4 py-3 bg-white dark:bg-primary-800 border border-primary-300 dark:border-primary-700 rounded-xl hover:border-brand-blue/50 transition-colors shadow-sm">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-lg bg-brand-blue/10 flex items-center justify-center text-brand-blue shrink-0">
              <span class="text-xl">{{ selectedVoice?.gender === 'Female' ? '👩' : (selectedVoice?.gender === 'Male' ? '👨' : '👤') }}</span>
            </div>
            <div class="text-left">
              <div class="text-base sm:text-sm font-medium text-primary-900 dark:text-white">{{ selectedVoice?.name || 'Select a voice' }}</div>
              <div class="text-sm sm:text-xs text-primary-600 dark:text-primary-400">{{ selectedVoice?.gender }} · {{ getVoiceTypeLabel(selectedVoice) }}</div>
            </div>
          </div>
          <svg [ngClass]="isDropdownOpen ? 'rotate-180' : ''" class="w-4 h-4 text-primary-400 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
          </svg>
        </button>

        <!-- Dropdown -->
        <div *ngIf="isDropdownOpen"
          class="absolute top-full left-0 right-0 mt-2 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 rounded-xl shadow-elevated overflow-hidden z-50 max-h-72 overflow-y-auto">
          <button *ngFor="let voice of getFilteredVoices()"
            (click)="selectVoice(voice.id)"
            [ngClass]="voiceId === voice.id ? 'bg-brand-blue/10 border-l-2 border-l-brand-blue' : 'hover:bg-primary-50 dark:hover:bg-primary-800'"
            class="w-full flex items-center justify-between px-4 py-3 text-left transition-colors">
            <div class="flex items-center gap-3">
              <span class="text-lg">{{ voice.gender === 'Female' ? '👩' : '👨' }}</span>
              <div>
                <div class="text-sm font-medium text-primary-900 dark:text-white">{{ voice.name }}</div>
                <div class="text-xs text-primary-500 dark:text-primary-400 uppercase font-semibold">{{ voice.gender }}</div>
              </div>
            </div>
            <span [ngClass]="getVoiceTypeClass(voice)" class="text-[10px] font-bold uppercase">
              {{ getVoiceTypeLabel(voice) }}
            </span>
          </button>
        </div>
      </div>
    </div>
  `
})
export class VoiceSelectorComponent {
  @Input() voices: Voice[] = [];
  @Input() voiceId: string = '';
  @Input() userCanUseNatural = false;
  @Input() userCanUseSarvam = false;
  
  @Output() voiceChange = new EventEmitter<string>();
  @Output() filterChanged = new EventEmitter<string>();
  @Output() showNotification = new EventEmitter<{message: string, type: 'success' | 'error'}>();

  currentFilter = signal<string>('Standard');
  filterOptions = signal<string[]>(['Standard', 'Indian', 'Natural', 'All']);
  isDropdownOpen = false;

  // Sub-filter signals
  selectedGenders = signal<Set<string>>(new Set(['Male', 'Female']));
  selectedLanguages = signal<Set<string>>(new Set(['hi-IN'])); // Default to Hindi
  genderOptions = ['Male', 'Female'];
  
  isLanguageDropdownOpen = false;
  isGenderDropdownOpen = false;

  languageOptions = computed(() => {
    const indianVoices = this.voices.filter(v => v.isSarvam);
    const langs = new Map<string, string>();
    
    indianVoices.forEach(v => {
      if (v.languageCode) {
        const match = v.name.match(/\(([^)]+)\)/);
        const name = match ? match[1] : v.languageCode;
        langs.set(v.languageCode, name);
      }
    });
    
    return Array.from(langs.entries()).map(([code, name]) => ({ code, name }));
  });

  constructor() {
    effect(() => {
      if (this.currentFilter() === 'Indian') {
        const filtered = this.getFilteredVoices();
        // If current selection is NOT in the filtered list, pick the first available
        if (filtered.length > 0 && !filtered.find(v => v.id === this.voiceId)) {
          this.selectVoice(filtered[0].id);
        }
      }
    });
  }

  get selectedVoice(): Voice | undefined {
    return this.voices.find(v => v.id === this.voiceId);
  }

  @HostListener('document:click')
  onDocumentClick(): void {
    this.isDropdownOpen = false;
    this.isLanguageDropdownOpen = false;
    this.isGenderDropdownOpen = false;
  }

  toggleDropdown(event: Event): void {
    event.stopPropagation();
    this.isDropdownOpen = !this.isDropdownOpen;
    this.isLanguageDropdownOpen = false;
    this.isGenderDropdownOpen = false;
  }

  toggleLanguageDropdown(event: Event): void {
    event.stopPropagation();
    this.isLanguageDropdownOpen = !this.isLanguageDropdownOpen;
    this.isDropdownOpen = false;
    this.isGenderDropdownOpen = false;
  }

  toggleGenderDropdown(event: Event): void {
    event.stopPropagation();
    this.isGenderDropdownOpen = !this.isGenderDropdownOpen;
    this.isDropdownOpen = false;
    this.isLanguageDropdownOpen = false;
  }

  toggleLanguage(code: string): void {
    this.selectedLanguages.update(set => {
      const newSet = new Set(set);
      if (newSet.has(code)) {
        if (newSet.size > 1) newSet.delete(code);
      } else {
        newSet.add(code);
      }
      return newSet;
    });
  }

  toggleGender(gender: string): void {
    this.selectedGenders.update(set => {
      const newSet = new Set(set);
      if (newSet.has(gender)) {
        if (newSet.size > 1) newSet.delete(gender);
      } else {
        newSet.add(gender);
      }
      return newSet;
    });
  }

  getLanguageSummary(): string {
    const selected = this.selectedLanguages();
    const options = this.languageOptions();
    if (selected.size === options.length) return 'All Languages';
    if (selected.size === 1) {
      const lang = options.find(o => o.code === Array.from(selected)[0]);
      return lang ? lang.name : 'Selected';
    }
    return `${selected.size} Languages`;
  }

  getGenderSummary(): string {
    const selected = this.selectedGenders();
    if (selected.size === 2) return 'All Genders';
    return Array.from(selected)[0];
  }

  selectVoice(id: string): void {
    this.voiceChange.emit(id);
    this.isDropdownOpen = false;
  }

  setFilter(filter: string): void {
    if (filter === 'Natural' && !this.userCanUseNatural) {
      this.showNotification.emit({ message: 'Natural voices require a Pro Plus subscription', type: 'error' });
      return;
    }
    if (filter === 'Indian' && !this.userCanUseSarvam) {
      this.showNotification.emit({ message: 'Indian AI voices require a PRO subscription', type: 'error' });
      return;
    }
    this.currentFilter.set(filter);
    this.filterChanged.emit(filter);

    const voices = this.getFilteredVoices();
    if (voices.length > 0) {
      this.selectVoice(voices[0].id);
    }
  }

  getFilteredVoices(): Voice[] {
    const filter = this.currentFilter();
    let filtered = this.voices;

    if (filter === 'Standard') {
      filtered = this.voices.filter(v => !v.isElevenLabs && !v.isSarvam);
    } else if (filter === 'Natural') {
      filtered = this.voices.filter(v => v.isElevenLabs);
    } else if (filter === 'Indian') {
      filtered = this.voices.filter(v => v.isSarvam);
      
      const languages = this.selectedLanguages();
      filtered = filtered.filter(v => v.languageCode && languages.has(v.languageCode));
      
      const genders = this.selectedGenders();
      filtered = filtered.filter(v => genders.has(v.gender));
    }
    
    return filtered;
  }

  getFilterCount(filter: string): number {
    if (filter === 'Standard') return this.voices.filter(v => !v.isElevenLabs && !v.isSarvam).length;
    if (filter === 'Natural') return this.voices.filter(v => v.isElevenLabs).length;
    if (filter === 'Indian') return this.voices.filter(v => v.isSarvam).length;
    return this.voices.length;
  }

  canUseFilter(filter: string): boolean {
    if (filter === 'Natural') return this.userCanUseNatural;
    if (filter === 'Indian') return this.userCanUseSarvam;
    return true;
  }

  getVoiceTypeLabel(voice?: Voice): string {
    return getVoiceTypeLabel(voice, this.currentFilter());
  }

  getVoiceTypeClass(voice: Voice): string {
    return getVoiceTypeClass(voice, this.currentFilter());
  }
}
