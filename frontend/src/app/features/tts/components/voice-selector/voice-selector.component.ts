import { Component, Input, Output, EventEmitter, signal, HostListener } from '@angular/core';
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
      <div class="flex gap-1 p-1 bg-primary-100 dark:bg-primary-800 rounded-lg mb-3 sm:mb-4">

        <ng-container *ngFor="let filter of filterOptions()">
          <button *ngIf="filter !== 'All'"
            (click)="setFilter(filter)"
            [ngClass]="currentFilter() === filter ? 'bg-white dark:bg-primary-700 text-primary-900 dark:text-white shadow-sm' : 'text-primary-500 dark:text-primary-400 hover:text-primary-700 dark:hover:text-white'"
            class="flex-1 py-2 sm:py-1.5 text-[11px] sm:text-[10px] font-bold rounded-md transition-all relative uppercase tracking-tight">

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

      <!-- Voice Dropdown -->
      <div class="relative">
        <button (click)="toggleDropdown($event)"
          class="w-full flex items-center justify-between px-4 py-3 bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 rounded-xl hover:border-brand-blue/50 transition-colors">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-lg bg-brand-blue/10 flex items-center justify-center text-brand-blue">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
              </svg>
            </div>
            <div class="text-left">
              <div class="text-base sm:text-sm font-medium text-primary-900 dark:text-white">{{ selectedVoice?.name || 'Select a voice' }}</div>
              <div class="text-sm sm:text-xs text-primary-400">{{ selectedVoice?.gender }} · {{ getVoiceTypeLabel(selectedVoice) }}</div>
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
                <div class="text-xs text-primary-400 uppercase">{{ voice.gender }}</div>
              </div>
            </div>
            <span [ngClass]="getVoiceTypeClass(voice)" class="text-[10px] font-medium uppercase">
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
  filterOptions = signal<string[]>(['Standard', 'Natural', 'Indian', 'All']);
  isDropdownOpen = false;

  get selectedVoice(): Voice | undefined {
    return this.voices.find(v => v.id === this.voiceId);
  }

  @HostListener('document:click')
  onDocumentClick(): void {
    this.isDropdownOpen = false;
  }

  toggleDropdown(event: Event): void {
    event.stopPropagation();
    this.isDropdownOpen = !this.isDropdownOpen;
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

    // Auto-select first voice in the new category
    const voices = this.getFilteredVoices();
    if (voices.length > 0) {
      this.selectVoice(voices[0].id);
    }
  }

  getFilteredVoices(): Voice[] {
    const filter = this.currentFilter();
    if (filter === 'Standard') return this.voices.filter(v => !v.isElevenLabs && !v.isSarvam);
    if (filter === 'Natural') return this.voices.filter(v => v.isElevenLabs);
    if (filter === 'Indian') return this.voices.filter(v => v.isSarvam);
    return this.voices;
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
