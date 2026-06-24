import { Component, Input, inject, signal, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { SttResult } from '../../models/stt.models';
import { ToastService } from '../../../../core/services/toast.service';
import { SttService } from '../../services/stt.service';
import { TtsService } from '../../../../core/services/tts.service';
import { CustomDropdownComponent, DropdownOption } from '../../../../shared/components/custom-dropdown/custom-dropdown.component';
import { 
  SARVAM_VOICES, 
  DEFAULT_SPEAKERS, 
  capitalize, 
  isFemale, 
  getSpeakersForLanguage,
  normalizeLanguageCode
} from '../../models/sarvam-voices.config';

@Component({
  selector: 'app-transcript-card',
  standalone: true,
  imports: [CommonModule, CustomDropdownComponent],
  template: `
    <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-300 dark:border-primary-700 shadow-xl relative z-10 animate-slide-up">
      <!-- Card Header -->
      <div class="p-6 border-b border-primary-200 dark:border-primary-800 flex items-center justify-between flex-wrap gap-4">
        <div class="flex items-center gap-4 flex-wrap">
          <div class="px-3 py-1 rounded-full bg-brand-blue/10 text-brand-blue text-xs font-bold tracking-wider">
            {{ result.provider === 'SARVAM' ? 'Indian Engine' : (result.provider === 'ELEVEN_LABS' ? 'Global Engine' : result.provider) }}
          </div>
          <span class="text-sm text-primary-500 font-medium">Duration: {{ result.duration | number:'1.1-1' }}s</span>
          @if (result.language) {
            <span class="text-xs text-primary-500 dark:text-primary-400 font-semibold px-2.5 py-1 rounded-lg bg-primary-100 dark:bg-primary-800/60 border border-primary-200/50 dark:border-primary-700/30">
              Detected Language: {{ getLanguageName(result.language) }}
            </span>
          }
        </div>
      </div>

      <!-- Side-by-Side Split Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 divide-y md:divide-y-0 md:divide-x divide-primary-200 dark:divide-primary-800">
        <!-- Left Panel: Original Text -->
        <div class="p-6 md:p-8 flex flex-col min-h-[120px] md:min-h-[350px] rounded-bl-2xl">
          <div class="flex items-center justify-between mb-4 border-b border-primary-100 dark:border-primary-800 pb-2 select-none gap-2">
            <span class="text-xs font-bold text-primary-400 dark:text-primary-500 tracking-wider uppercase shrink-0">
              Original Transcript
            </span>
            <div class="flex items-center gap-1 shrink-0 ml-auto">
              <button (click)="speak(result.transcript, result.language, selectedOriginalNarrator(), true)" 
                class="p-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-blue transition-all relative flex items-center justify-center"
                [title]="playingOriginal() ? 'Pause Original' : 'Listen to Original'">
                @if (loadingOriginal()) {
                  <svg class="w-5 h-5 animate-spin text-brand-blue" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                  </svg>
                } @else if (playingOriginal()) {
                  <svg class="w-5 h-5 text-brand-blue animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                } @else {
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"></path>
                  </svg>
                }
              </button>
              <button (click)="copyToClipboard(result.transcript)" 
                class="p-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-blue transition-all"
                title="Copy Original to Clipboard">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"></path>
                </svg>
              </button>
              <button (click)="downloadTxt(result.transcript, 'original')" 
                class="p-2 rounded-lg hover:bg-primary-50 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-purple transition-all"
                title="Download Original TXT">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                </svg>
              </button>
            </div>
          </div>
          
          <!-- Controls Row below the line -->
          @if (isOriginalSarvamSupported) {
            <div class="flex items-center gap-2 mb-4 select-none w-full animate-fade-in">
              <div class="flex-1 w-full sm:max-w-[200px]">
                <app-custom-dropdown
                  [options]="originalNarratorOptions"
                  [value]="selectedOriginalNarrator()"
                  (valueChange)="onOriginalNarratorChange($event)"
                  placeholder="Narrator Voice"
                  align="left"
                >
                </app-custom-dropdown>
              </div>
            </div>
          }
          
          <div class="flex-1 overflow-y-auto max-h-[400px] custom-scrollbar pr-2">
            <p class="text-primary-800 dark:text-primary-100 leading-relaxed whitespace-pre-wrap selection:bg-brand-blue/20">
              {{ result.transcript || 'No transcript generated.' }}
            </p>
          </div>
        </div>

        <!-- Right Panel: Google Translate Style Translation -->
        <div class="p-6 md:p-8 flex flex-col min-h-[120px] md:min-h-[350px] bg-primary-50/20 dark:bg-primary-900/10 rounded-b-2xl md:rounded-b-none md:rounded-br-2xl">
          <div class="flex items-center justify-between mb-4 border-b border-primary-100 dark:border-primary-800 pb-2 select-none gap-2">
            <span class="text-xs font-bold text-primary-400 dark:text-primary-500 tracking-wider uppercase shrink-0">
              Translation
            </span>
            <div class="flex items-center gap-1 shrink-0 ml-auto">
              <button (click)="speak(translatedText(), selectedTargetLanguage(), selectedTranslationNarrator(), false)" 
                [disabled]="!translatedText() || loadingTranslation()"
                class="p-2 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-blue disabled:opacity-40 disabled:hover:text-primary-500 disabled:hover:bg-transparent transition-all relative flex items-center justify-center"
                [title]="playingTranslation() ? 'Pause Translation' : 'Listen to Translation'">
                @if (loadingTranslation()) {
                  <svg class="w-5 h-5 animate-spin text-brand-blue" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                  </svg>
                } @else if (playingTranslation()) {
                  <svg class="w-5 h-5 text-brand-blue animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                } @else {
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"></path>
                  </svg>
                }
              </button>
              <button (click)="copyToClipboard(translatedText())" 
                [disabled]="!translatedText()"
                class="p-2 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-blue disabled:opacity-40 disabled:hover:text-primary-500 disabled:hover:bg-transparent transition-all"
                title="Copy Translation">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"></path>
                </svg>
              </button>
              <button (click)="downloadTxt(translatedText(), 'translated')" 
                [disabled]="!translatedText()"
                class="p-2 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 text-primary-500 hover:text-brand-purple disabled:opacity-40 disabled:hover:text-primary-500 disabled:hover:bg-transparent transition-all"
                title="Download Translation">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                </svg>
              </button>
            </div>
          </div>

          <!-- Controls Row below the line -->
          <div class="flex items-center gap-2 mb-4 select-none w-full">
            <div class="flex-1 w-full sm:max-w-[200px]">
              <app-custom-dropdown
                [options]="translationLanguages"
                [value]="selectedTargetLanguage()"
                (valueChange)="onTargetLanguageChange($event)"
                [disabled]="translating()"
                placeholder="Translate to..."
                align="left"
              >
              </app-custom-dropdown>
            </div>
            @if (selectedTargetLanguage() && isTranslationSarvamSupported) {
              <div class="flex-1 w-full sm:max-w-[200px] select-none animate-slide-up">
                <app-custom-dropdown
                  [options]="translationNarratorOptions"
                  [value]="selectedTranslationNarrator()"
                  (valueChange)="onTranslationNarratorChange($event)"
                  placeholder="Narrator Voice"
                  align="left"
                >
                </app-custom-dropdown>
              </div>
            }
          </div>

          <div class="flex-1 overflow-y-auto max-h-[400px] custom-scrollbar pr-2 flex flex-col justify-start">
            @if (translating()) {
              <div class="flex flex-col items-center justify-center py-12 gap-3 text-primary-400 dark:text-primary-500">
                <svg class="w-8 h-8 animate-spin text-brand-blue" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                </svg>
                <span class="text-sm font-semibold">Translating...</span>
              </div>
            } @else if (translationError()) {
              <p class="text-red-500 dark:text-red-400 text-sm font-medium p-3 bg-red-50 dark:bg-red-950/20 rounded-xl border border-red-200 dark:border-red-800/20">
                {{ translationError() }}
              </p>
            } @else if (translatedText()) {
              <p class="text-primary-800 dark:text-primary-100 leading-relaxed whitespace-pre-wrap selection:bg-brand-blue/20 animate-fade-in">
                {{ translatedText() }}
              </p>
            } @else {
              <div class="flex-1 flex flex-col items-center justify-center text-center text-primary-400 dark:text-primary-500 py-12">
                <svg class="w-12 h-12 mb-3 opacity-60 animate-pulse text-brand-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 11.37 7.31 16.5 3 19"></path>
                </svg>
                <button
                  type="button"
                  (click)="translateText()"
                  class="px-6 py-3 bg-brand-blue hover:bg-brand-blue/90 text-white font-bold rounded-xl shadow-lg transition-all active:scale-[0.98] mb-2 flex items-center gap-2"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 11.37 7.31 16.5 3 19"></path>
                  </svg>
                  Translate Text
                </button>
                <p class="text-xs text-primary-400 dark:text-primary-500 font-medium">Click translate to generate translation</p>
              </div>
            }
          </div>
        </div>
      </div>
    </div>
  `
})
export class TranscriptCardComponent implements OnInit, OnDestroy {
  @Input() result!: SttResult;
  @Input() defaultNarratorVoice = '';
  @Input() defaultNarratorLanguage = '';

  private toast = inject(ToastService);
  private sttService = inject(SttService);
  private ttsService = inject(TtsService);

  translating = signal(false);
  translatedText = signal('');
  translationError = signal('');
  selectedTargetLanguage = signal('');

  // Audio Playback State
  private audioPlayer: HTMLAudioElement | null = null;
  private lastPlayedIsOriginal = false;
  
  playingOriginal = signal(false);
  playingTranslation = signal(false);
  loadingOriginal = signal(false);
  loadingTranslation = signal(false);

  // Original Transcript Narrator State
  selectedOriginalNarrator = signal('');
  originalNarratorOptions: DropdownOption[] = [];
  isOriginalSarvamSupported = false;

  // Translated Transcript Narrator State
  selectedTranslationNarrator = signal('');
  translationNarratorOptions: DropdownOption[] = [];
  isTranslationSarvamSupported = false;

  translationLanguages = [
    { value: 'en-IN', label: 'English' },
    { value: 'hi-IN', label: 'Hindi' },
    { value: 'bn-IN', label: 'Bengali' },
    { value: 'ta-IN', label: 'Tamil' },
    { value: 'te-IN', label: 'Telugu' },
    { value: 'mr-IN', label: 'Marathi' },
    { value: 'kn-IN', label: 'Kannada' },
    { value: 'gu-IN', label: 'Gujarati' },
    { value: 'ml-IN', label: 'Malayalam' },
    { value: 'pa-IN', label: 'Punjabi' },
    { value: 'or-IN', label: 'Odia' }
  ];

  capitalize = capitalize;
  isFemale = isFemale;

  ngOnInit() {
    // Determine narrator voice for the original transcript
    const origLang = normalizeLanguageCode(this.result.language || this.defaultNarratorLanguage);
    if (origLang && origLang !== 'auto') {
      const cleanLang = origLang.trim();
      const isSupported = SARVAM_VOICES.languages.some(l => l.code.toLowerCase() === cleanLang.toLowerCase());
      
      if (isSupported) {
        this.isOriginalSarvamSupported = true;
        this.originalNarratorOptions = SARVAM_VOICES.speakers.map(speaker => ({
          value: speaker,
          label: `${this.capitalize(speaker)} (${this.isFemale(speaker) ? 'Female' : 'Male'})`
        }));
        
        // Use defaultNarratorVoice if it matches the language, otherwise find the default speaker
        const normalizedDefaultLanguage = normalizeLanguageCode(this.defaultNarratorLanguage);
        const isMatchingDefaultVoice = this.defaultNarratorVoice && 
          normalizedDefaultLanguage && 
          normalizedDefaultLanguage.toLowerCase() === cleanLang.toLowerCase();
          
        const defaultSpeaker = isMatchingDefaultVoice ? 
          this.defaultNarratorVoice : 
          (DEFAULT_SPEAKERS[cleanLang] || SARVAM_VOICES.speakers[0]);
        this.selectedOriginalNarrator.set(defaultSpeaker);
      }
    }
    // Determine dynamic default target language for translation based on detected language
    const origLangCode = (this.result.language || this.defaultNarratorLanguage || 'en').toLowerCase().trim();
    const defaultTargetLanguage = origLangCode.startsWith('hi') ? 'en-IN' : 'hi-IN';
    
    // Pre-select target language and update narrator options without triggering translation API call
    this.selectedTargetLanguage.set(defaultTargetLanguage);
    this.updateTranslationNarrator(defaultTargetLanguage);
  }

  getLanguageName(code: string): string {
    if (!code) return 'Unknown';
    const clean = code.toLowerCase().trim();
    if (clean.startsWith('en')) return 'English';
    if (clean.startsWith('hi')) return 'Hindi';
    if (clean.startsWith('bn') || clean.startsWith('ben')) return 'Bengali';
    if (clean.startsWith('ta') || clean.startsWith('tam')) return 'Tamil';
    if (clean.startsWith('te') || clean.startsWith('tel')) return 'Telugu';
    if (clean.startsWith('mr') || clean.startsWith('mar')) return 'Marathi';
    if (clean.startsWith('kn') || clean.startsWith('kan')) return 'Kannada';
    if (clean.startsWith('gu') || clean.startsWith('guj')) return 'Gujarati';
    if (clean.startsWith('ml')) return 'Malayalam';
    if (clean.startsWith('pa')) return 'Punjabi';
    if (clean.startsWith('or')) return 'Odia';
    return code.toUpperCase();
  }

  onOriginalNarratorChange(speaker: string) {
    this.selectedOriginalNarrator.set(speaker);
  }

  onTranslationNarratorChange(speaker: string) {
    this.selectedTranslationNarrator.set(speaker);
    this.translatedText.set(''); // Clear translation to show the translate button again
    this.translationError.set(''); // Clear previous validation error
  }

  updateTranslationNarrator(lang: string) {
    if (!lang) {
      this.isTranslationSarvamSupported = false;
      return;
    }
    const normalized = normalizeLanguageCode(lang);
    const isSupported = SARVAM_VOICES.languages.some(l => l.code.toLowerCase() === normalized.toLowerCase());
    
    if (isSupported) {
      this.isTranslationSarvamSupported = true;
      this.translationNarratorOptions = SARVAM_VOICES.speakers.map(speaker => ({
        value: speaker,
        label: `${this.capitalize(speaker)} (${this.isFemale(speaker) ? 'Female' : 'Male'})`
      }));
      const defaultSpeaker = DEFAULT_SPEAKERS[normalized] || SARVAM_VOICES.speakers[0];
      this.selectedTranslationNarrator.set(defaultSpeaker);
    } else {
      this.isTranslationSarvamSupported = false;
      this.selectedTranslationNarrator.set('');
    }
  }

  onTargetLanguageChange(targetLang: string) {
    if (!targetLang) return;
    this.selectedTargetLanguage.set(targetLang);

    // Automatically switch translation narrator voice options and select default speaker
    this.updateTranslationNarrator(targetLang);

    // Reset translated text and errors so that the user must click the Translate button to perform the translation
    this.translatedText.set('');
    this.translationError.set('');
  }

  translateText() {
    const targetLang = this.selectedTargetLanguage();
    if (!targetLang) return;

    this.translating.set(true);
    this.translationError.set('');
    this.translatedText.set('');

    const sourceLang = normalizeLanguageCode(this.result.language || this.defaultNarratorLanguage || 'auto');
    const targetLangNormalized = normalizeLanguageCode(targetLang);

    // If source and target match, show validation and bypass backend call
    if (sourceLang !== 'auto' && sourceLang.toLowerCase().substring(0, 2) === targetLangNormalized.toLowerCase().substring(0, 2)) {
      this.translationError.set('Source and target languages are the same. No translation needed.');
      this.translatedText.set('');
      this.translating.set(false);
      return;
    }

    this.sttService.translate(this.result.transcript, sourceLang, targetLang).subscribe({
      next: (res) => {
        this.translating.set(false);
        this.translatedText.set(res.translatedText);
      },
      error: (err) => {
        this.translating.set(false);
        let errorMsg = 'Translation failed.';
        if (err.error) {
          try {
            const parsed = typeof err.error === 'string' ? JSON.parse(err.error) : err.error;
            errorMsg = parsed.error?.message || parsed.message || errorMsg;
          } catch (e) {
            if (typeof err.error === 'object' && err.error.message) {
              errorMsg = err.error.message;
            } else if (err.message) {
              errorMsg = err.message;
            }
          }
        }
        if (errorMsg.includes('must be different') || err.status === 400) {
          errorMsg = 'Source and target languages are the same. No translation needed.';
        }
        this.translationError.set(errorMsg);
        this.toast.show(errorMsg, 'error');
      }
    });
  }

  copyToClipboard(text: string) {
    if (!text) return;
    navigator.clipboard.writeText(text);
    this.toast.show('Copied to clipboard', 'success');
  }

  downloadTxt(text: string, type: 'original' | 'translated') {
    if (!text) return;
    const blob = new Blob([text], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `speakit-${type}-${Date.now()}.txt`;
    a.click();
    window.URL.revokeObjectURL(url);
    this.toast.show('Download started', 'success');
  }

  speak(text: string, langCode: string, speaker: string | null, isOriginal: boolean) {
    if (!text) return;

    // Toggle play/pause if clicked on the active playing track
    if (this.audioPlayer && !this.audioPlayer.paused) {
      this.audioPlayer.pause();
      this.playingOriginal.set(false);
      this.playingTranslation.set(false);
      
      if (this.lastPlayedIsOriginal === isOriginal) {
        return;
      }
    }

    // Reset playing states
    this.playingOriginal.set(false);
    this.playingTranslation.set(false);

    const cleanLang = langCode?.trim()?.toLowerCase() || '';
    const isSarvamLang = cleanLang && SARVAM_VOICES.languages.some(l => l.code.toLowerCase() === cleanLang);

    if (isSarvamLang && speaker) {
      if (isOriginal) {
        this.loadingOriginal.set(true);
      } else {
        this.loadingTranslation.set(true);
      }

      this.ttsService.synthesize(text, speaker, speaker, 'INDIAN', false, true, langCode).subscribe({
        next: (blob) => {
          this.loadingOriginal.set(false);
          this.loadingTranslation.set(false);

          if (this.audioPlayer) {
            this.audioPlayer.pause();
          }

          const audioBlob = new Blob([blob], { type: blob.type || 'audio/mpeg' });
          const url = URL.createObjectURL(audioBlob);
          this.audioPlayer = new Audio(url);
          this.lastPlayedIsOriginal = isOriginal;

          this.audioPlayer.addEventListener('play', () => {
            if (isOriginal) {
              this.playingOriginal.set(true);
            } else {
              this.playingTranslation.set(true);
            }
          });

          this.audioPlayer.addEventListener('ended', () => {
            this.playingOriginal.set(false);
            this.playingTranslation.set(false);
            URL.revokeObjectURL(url);
          });

          this.audioPlayer.addEventListener('pause', () => {
            this.playingOriginal.set(false);
            this.playingTranslation.set(false);
          });

          this.audioPlayer.play().catch(() => {
            this.toast.show('Playback failed. Please try again.', 'error');
          });
        },
        error: () => {
          this.loadingOriginal.set(false);
          this.loadingTranslation.set(false);
          this.toast.show('Failed to synthesize speech. Falling back to browser TTS.', 'info');
          this.fallbackSpeak(text, langCode);
          this.simulatePlayingState(isOriginal);
        }
      });
    } else {
      this.fallbackSpeak(text, langCode);
      this.simulatePlayingState(isOriginal);
    }
  }

  private simulatePlayingState(isOriginal: boolean) {
    if (isOriginal) {
      this.playingOriginal.set(true);
      setTimeout(() => this.playingOriginal.set(false), 3000);
    } else {
      this.playingTranslation.set(true);
      setTimeout(() => this.playingTranslation.set(false), 3000);
    }
  }

  fallbackSpeak(text: string, langCode: string) {
    if (typeof window === 'undefined' || !window.speechSynthesis) return;

    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    if (langCode) {
      utterance.lang = langCode;

      if (window.speechSynthesis.getVoices) {
        const voices = window.speechSynthesis.getVoices();
        let voice = voices.find(v => v.lang.toLowerCase() === langCode.toLowerCase());
        if (!voice) {
          const shortCode = langCode.substring(0, 2).toLowerCase();
          voice = voices.find(v => v.lang.toLowerCase().startsWith(shortCode));
        }
        if (voice) {
          utterance.voice = voice;
        }
      }
    }
    window.speechSynthesis.speak(utterance);
  }

  ngOnDestroy(): void {
    if (this.audioPlayer) {
      this.audioPlayer.pause();
      this.audioPlayer = null;
    }
    if (typeof window !== 'undefined' && window.speechSynthesis) {
      window.speechSynthesis.cancel();
    }
  }
}
