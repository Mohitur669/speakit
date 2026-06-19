import { Component, Input, Output, EventEmitter, signal, HostListener, computed, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Voice } from '../../../../core/services/tts.service';
import { getVoiceTypeLabel, getVoiceTypeClass } from '../../../../shared';

@Component({
  selector: 'app-voice-selector',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flex-1 bg-white dark:bg-primary-900 rounded-xl border border-primary-300 dark:border-primary-700 p-4 sm:p-6 flex flex-col gap-4">
      
      <div class="flex flex-wrap items-center justify-start gap-3 mb-2 sm:mb-4">
        <h2 class="text-sm font-bold text-primary-900 dark:text-white tracking-widest whitespace-nowrap">Settings</h2>
        <!-- Dynamic Voice Count Indicator -->
        <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-blue/5 dark:bg-brand-blue/10 border border-brand-blue/10">
          <span class="w-1.5 h-1.5 rounded-full bg-brand-blue animate-pulse shrink-0"></span>
          <span class="text-[10px] font-bold text-brand-blue tracking-tight whitespace-nowrap">
            {{ getFilteredVoices().length }} Voices Available
          </span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3 sm:gap-4">
        <!-- 1. Engine Selection Dropdown -->
        <div class="relative">
          <label class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest px-1">Engine</label>
          <button (click)="toggleEngineDropdown($event)"
            class="w-full flex items-center justify-between px-4 py-3 bg-primary-50 dark:bg-primary-800 border border-primary-300 dark:border-primary-700 rounded-xl hover:border-brand-blue/30 transition-all text-left group">
            <span class="text-sm font-bold text-primary-900 dark:text-white truncate">
              {{ currentFilter() }}
            </span>
            <svg class="w-4 h-4 text-primary-400 transition-transform shrink-0 ml-1" [class.rotate-180]="isEngineDropdownOpen" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
          </button>
 
          <!-- Engine Dropdown Panel -->
          <div *ngIf="isEngineDropdownOpen" (click)="$event.stopPropagation()"
            class="absolute top-full left-0 mt-2 w-full bg-white dark:bg-primary-900 border border-primary-300 dark:border-primary-700 rounded-xl shadow-2xl z-[70] p-1.5 flex flex-col gap-0.5 animate-fade-in">
            <button *ngFor="let filter of filterOptions"
              (click)="setFilter(filter)"
              class="flex items-center justify-between px-3 py-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors text-left group">
              <span class="text-xs font-bold transition-colors" [ngClass]="currentFilter() === filter ? 'text-brand-blue' : 'text-primary-700 dark:text-primary-200'">
                {{ filter }}
              </span>
              <svg *ngIf="!canUseFilter(filter)" class="w-3.5 h-3.5 text-amber-500" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>

        <!-- 2. Gender Multi-Select (Hidden for Global voices) -->
        <div class="relative" *ngIf="currentFilter() !== 'Global'">
          <label class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest px-1">Gender</label>
          <button (click)="toggleGenderDropdown($event)"
            class="w-full flex items-center justify-between px-4 py-3 bg-primary-50 dark:bg-primary-800 border border-primary-300 dark:border-primary-700 rounded-xl hover:border-brand-blue/30 transition-all text-left">
            <span class="text-sm font-bold text-primary-900 dark:text-white truncate">
              {{ getGenderSummary() }}
            </span>
            <svg class="w-4 h-4 text-primary-400 transition-transform shrink-0 ml-1" [class.rotate-180]="isGenderDropdownOpen" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
          </button>
 
          <div *ngIf="isGenderDropdownOpen" (click)="$event.stopPropagation()"
            class="absolute top-full left-0 mt-2 w-full bg-white dark:bg-primary-900 border border-primary-300 dark:border-primary-700 rounded-xl shadow-2xl z-[70] p-2 flex flex-col gap-1 animate-fade-in">
            <button *ngFor="let gender of genderOptions" (click)="toggleGender(gender)"
              class="flex items-center gap-2 w-full px-3 py-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors text-left group">
              <div class="w-4 h-4 rounded border flex items-center justify-center transition-colors shrink-0"
                [ngClass]="selectedGenders().has(gender) ? 'bg-brand-blue border-brand-blue' : 'border-primary-300 dark:border-primary-600'">
                <svg *ngIf="selectedGenders().has(gender)" class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
              </div>
              <span class="text-xs font-bold text-primary-700 dark:text-primary-200 capitalize group-hover:text-primary-900 dark:group-hover:text-white">{{ gender }}</span>
            </button>
          </div>
        </div>
      </div>

      <!-- 3. Language Filter (Only for Indian Engine) -->
      <div *ngIf="currentFilter() === 'Indian'" class="relative animate-fade-in">
        <label class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest px-1">Regional Language</label>
        <button (click)="toggleLanguageDropdown($event)"
          class="w-full flex items-center justify-between px-4 py-3 bg-primary-50 dark:bg-primary-800 border border-primary-300 dark:border-primary-700 rounded-xl hover:border-brand-blue/30 transition-all text-left">
          <span class="text-sm font-bold text-primary-900 dark:text-white truncate">
            {{ getLanguageSummary() }}
          </span>
          <svg class="w-4 h-4 text-primary-400 transition-transform shrink-0 ml-1" [class.rotate-180]="isLanguageDropdownOpen" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
        </button>
 
        <div *ngIf="isLanguageDropdownOpen" (click)="$event.stopPropagation()"
          class="absolute top-full left-0 mt-2 w-full bg-white dark:bg-primary-900 border border-primary-300 dark:border-primary-700 rounded-xl shadow-2xl z-[70] max-h-60 overflow-y-auto p-2 flex flex-col gap-1 animate-fade-in custom-scrollbar">
          <button *ngFor="let lang of languageOptions()" (click)="toggleLanguage(lang.code)"
            class="flex items-center gap-2 w-full px-3 py-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 transition-colors text-left group">
            <div class="w-4 h-4 rounded border flex items-center justify-center transition-colors shrink-0"
              [ngClass]="selectedLanguages().has(lang.code) ? 'bg-brand-blue border-brand-blue' : 'border-primary-300 dark:border-primary-600'">
              <svg *ngIf="selectedLanguages().has(lang.code)" class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
            </div>
            <span class="text-xs font-bold text-primary-700 dark:text-primary-200 group-hover:text-primary-900 dark:group-hover:text-white truncate">{{ lang.name }}</span>
          </button>
        </div>
      </div>

      <!-- 4. Voice Selection Dropdown -->
      <div class="relative">
        <label class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest px-1">Active Voice</label>
        <button (click)="toggleVoiceDropdown($event)"
          class="w-full flex items-center justify-between px-4 py-3 bg-primary-50 dark:bg-primary-800 border border-primary-300 dark:border-primary-700 rounded-xl hover:border-brand-blue/30 transition-all text-left group">
          <div class="flex items-center gap-3">
            <div class="w-11 h-11 rounded-xl bg-white dark:bg-primary-900 border border-primary-300 dark:border-primary-700 flex items-center justify-center text-2xl shadow-sm group-hover:scale-105 transition-transform">
              {{ selectedVoice?.gender === 'Female' ? '👩' : (selectedVoice?.gender === 'Male' ? '👨' : '👤') }}
            </div>
            <h3 class="text-sm font-bold text-primary-900 dark:text-white truncate max-w-[150px]">
              {{ selectedVoice?.name || 'Select a voice' }}
            </h3>
          </div>
          <svg class="w-4 h-4 text-primary-400 transition-transform duration-200" [class.rotate-180]="isVoiceDropdownOpen" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
          </svg>
        </button>
 
        <div *ngIf="isVoiceDropdownOpen" (click)="$event.stopPropagation()"
          class="absolute top-full left-0 right-0 mt-2 bg-white dark:bg-primary-900 border border-primary-300 dark:border-primary-700 rounded-xl shadow-2xl z-[60] overflow-hidden animate-fade-in">
          <div class="max-h-72 overflow-y-auto custom-scrollbar">
            <button *ngFor="let voice of getFilteredVoices()"
              (click)="selectVoice(voice.id)"
              [ngClass]="voiceId === voice.id ? 'bg-brand-blue/5 border-l-2 border-brand-blue' : 'hover:bg-primary-50 dark:hover:bg-primary-800'"
              class="w-full flex items-center justify-between px-4 py-3 text-left transition-colors group/item">
              <div class="flex items-center gap-3">
                <span class="text-lg group-hover/item:scale-110 transition-transform">{{ voice.gender === 'Female' ? '👩' : '👨' }}</span>
                <div>
                  <div class="text-sm font-bold text-primary-900 dark:text-white" [class.text-brand-blue]="voiceId === voice.id">{{ voice.name }}</div>
                  <div class="text-[10px] text-primary-400 font-bold tracking-wide">{{ voice.gender }} · {{ voice.languageCode }}</div>
                </div>
              </div>
              <span [ngClass]="getVoiceTypeClass(voice)" class="text-[9px] font-extrabold tracking-widest px-2 py-0.5 rounded bg-primary-100 dark:bg-primary-800">
                {{ getVoiceTypeLabel(voice) }}
              </span>
            </button>
            
            <!-- Empty state in dropdown -->
            <div *ngIf="getFilteredVoices().length === 0" class="p-8 text-center">
              <p class="text-xs text-primary-500 font-medium italic">No voices match your current filters.</p>
            </div>
          </div>
        </div>
      </div>

    </div>
  `,
  styles: [`
    :host { display: block; }
    .animate-fade-in { animation: fadeIn 0.15s ease-out; }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(-4px); }
      to { opacity: 1; transform: translateY(0); }
    }
  `]
})
export class VoiceSelectorComponent {
  @Input() voices: Voice[] = [];
  @Input() voiceId: string = '';
  @Input() userCanUseGlobal = false;
  @Input() userCanUseSarvam = false;
  
  @Output() voiceChange = new EventEmitter<string>();
  @Output() filterChanged = new EventEmitter<string>();
  @Output() showNotification = new EventEmitter<{message: string, type: 'success' | 'error'}>();

  currentFilter = signal<string>('Standard');
  filterOptions = ['Standard', 'Indian', 'Global', 'All'];
  
  isVoiceDropdownOpen = false;
  isEngineDropdownOpen = false;
  isGenderDropdownOpen = false;
  isLanguageDropdownOpen = false;

  selectedGenders = signal<Set<string>>(new Set(['Male', 'Female']));
  selectedLanguages = signal<Set<string>>(new Set(['hi-IN'])); 
  genderOptions = ['Male', 'Female'];
  
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
      const filtered = this.getFilteredVoices();
      if (filtered.length > 0 && !filtered.find(v => v.id === this.voiceId)) {
        this.selectVoice(filtered[0].id);
      }
    });
  }

  get selectedVoice(): Voice | undefined {
    return this.voices.find(v => v.id === this.voiceId);
  }

  @HostListener('document:click')
  onDocumentClick(): void {
    this.closeAllDropdowns();
  }

  private closeAllDropdowns(): void {
    this.isVoiceDropdownOpen = false;
    this.isEngineDropdownOpen = false;
    this.isGenderDropdownOpen = false;
    this.isLanguageDropdownOpen = false;
  }

  toggleVoiceDropdown(event: Event): void {
    event.stopPropagation();
    const state = this.isVoiceDropdownOpen;
    this.closeAllDropdowns();
    this.isVoiceDropdownOpen = !state;
  }

  toggleEngineDropdown(event: Event): void {
    event.stopPropagation();
    const state = this.isEngineDropdownOpen;
    this.closeAllDropdowns();
    this.isEngineDropdownOpen = !state;
  }

  toggleGenderDropdown(event: Event): void {
    event.stopPropagation();
    const state = this.isGenderDropdownOpen;
    this.closeAllDropdowns();
    this.isGenderDropdownOpen = !state;
  }

  toggleLanguageDropdown(event: Event): void {
    event.stopPropagation();
    const state = this.isLanguageDropdownOpen;
    this.closeAllDropdowns();
    this.isLanguageDropdownOpen = !state;
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

  getGenderSummary(): string {
    const selected = this.selectedGenders();
    if (selected.size === 2) return 'All Genders';
    return Array.from(selected)[0];
  }

  getLanguageSummary(): string {
    const selected = this.selectedLanguages();
    const options = this.languageOptions();
    if (selected.size === options.length) return 'All Dialects';
    if (selected.size === 1) {
      const lang = options.find(o => o.code === Array.from(selected)[0]);
      return lang ? lang.name : 'Selected';
    }
    return `${selected.size} Languages`;
  }

  selectVoice(id: string): void {
    this.voiceChange.emit(id);
    this.isVoiceDropdownOpen = false;
  }

  setFilter(filter: string): void {
    if (filter === 'Global' && !this.userCanUseGlobal) {
      this.showNotification.emit({ message: 'Global voices require a Pro Plus subscription', type: 'error' });
      return;
    }
    if (filter === 'Indian' && !this.userCanUseSarvam) {
      this.showNotification.emit({ message: 'Indian AI voices require a PRO subscription', type: 'error' });
      return;
    }
    this.currentFilter.set(filter);
    this.filterChanged.emit(filter);
    this.isEngineDropdownOpen = false;
  }

  getFilteredVoices(): Voice[] {
    const filter = this.currentFilter();
    let filtered = this.voices;

    if (filter === 'Standard') {
      filtered = this.voices.filter(v => !v.isElevenLabs && !v.isSarvam);
    } else if (filter === 'Global') {
      filtered = this.voices.filter(v => v.isElevenLabs);
    } else if (filter === 'Indian') {
      filtered = this.voices.filter(v => v.isSarvam);
      const languages = this.selectedLanguages();
      filtered = filtered.filter(v => v.languageCode && languages.has(v.languageCode));
    }
    
    // Apply Gender filter to everything EXCEPT Global (since ElevenLabs uses 'neutral' for all)
    if (filter !== 'Global') {
      const genders = this.selectedGenders();
      filtered = filtered.filter(v => genders.has(v.gender));
    }
    
    return filtered;
  }

  canUseFilter(filter: string): boolean {
    if (filter === 'Global') return this.userCanUseGlobal;
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
