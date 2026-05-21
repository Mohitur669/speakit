/**
 * Main TTS workspace component managing voice selection,
 * text input, audio generation, playback controls,
 * and download functionality.
 */
import { Component, ElementRef, ViewChild, inject, signal, HostListener, effect, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TtsService, Voice } from '../../core/services/tts.service';
import { AuthService } from '../../core/auth/auth.service';
import { ThemeService } from '../../core/services/theme.service';
import { ToastService } from '../../core/services/toast.service';
import { FeatureFlagService } from '../../core/services/feature-flag.service';
import { RazorpayService } from '../../core/services/razorpay.service';
import { ToastComponent } from '../../shared/components/toast/toast.component';
import { NavbarComponent } from '../../shared/components/navbar/navbar.component';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-tts',
  standalone: true,
  imports: [CommonModule, FormsModule, ToastComponent, NavbarComponent],
  templateUrl: './tts.component.html',
  styleUrls: ['./tts.component.scss']
})
export class TtsComponent implements OnInit {
  @ViewChild('audioPlayer') audioPlayerRef!: ElementRef<HTMLAudioElement>;

  ttsService = inject(TtsService);
  authService = inject(AuthService);
  themeService = inject(ThemeService);
  featureFlags = inject(FeatureFlagService);
  private razorpayService = inject(RazorpayService);
  private toastService = inject(ToastService);
  private route = inject(ActivatedRoute);

  maxChars = signal<number>(3000);

  constructor() {
    // Reactively refresh UI when user status changes (e.g. after payment)
    effect(() => {
      const isPro = this.authService.hasNaturalAccess();
      this.refreshVoices();
      this.refreshLimits();
    });
  }

  text = '';
  currentFilter = signal<'All' | 'Standard' | 'Neural'>('All');
  selectedVoiceId = '';
  voices: Voice[] = [];
  filteredVoices = signal<Voice[]>([]);
  filterOptions = signal<('All' | 'Standard' | 'Neural')[]>(['All']);

  // Track available voice types from API
  hasStandardVoices = false;
  hasNeuralVoices = false;

  // Computed filter counts
  get standardCount(): number {
    return this.voices.filter(v => v.isStandard === true).length;
  }

  get neuralCount(): number {
    return this.voices.filter(v => v.isNeural === true).length;
  }

  get totalCount(): number {
    return this.voices.length;
  }

  isDropdownOpen = false;
  audioUrl = signal<string | null>(null);
  loading = signal(false);
  error = signal('');
  isPlaying = false;

  currentTime = 0;
  duration = 0;

  @HostListener('document:click')
  onDocumentClick(): void {
    this.isDropdownOpen = false;
  }

  async ngOnInit() {
    // 1. Check for autostart payment (after signup conversion)
    const autostart = this.route.snapshot.queryParams['autostart'];
    if (autostart) {
      this.invokeUpgrade(autostart);
    }
  }

  /**
   * Enterprise and Pro users have identical voice parity (full neural access).
   */
  get userCanUseNeural(): boolean {
    const plan = this.authService.currentPlanType();
    return plan === 'PRO' || plan === 'ENTERPRISE' || this.authService.hasNaturalAccess();
  }

  async refreshLimits() {
    // Fetch limits LIVE from database based on current plan
    const plan = this.authService.currentPlanType();
    let limitKey = 'MAX_FREE_CHARACTERS';
    let defaultVal = 3000;

    if (plan === 'ENTERPRISE') {
      limitKey = 'MAX_ENTERPRISE_CHARACTERS';
      defaultVal = 50000;
    } else if (plan === 'PRO') {
      limitKey = 'MAX_PRO_CHARACTERS';
      defaultVal = 10000;
    }
    
    const limit = await this.featureFlags.getLiveNumber(limitKey, defaultVal);
    this.maxChars.set(limit);
  }

  async invokeUpgrade(plan: string) {
    const amount = plan === 'PRO' ? 
      await this.featureFlags.getLiveNumber('PRO_PLAN_PRICE_INR', 499) : 
      await this.featureFlags.getLiveNumber('ENTERPRISE_PLAN_PRICE_INR', 1999);
    
    this.razorpayService.initiatePayment(plan, amount);
  }

  refreshVoices(): void {
    this.ttsService.getVoices().subscribe({
      next: (voices) => {
        this.voices = voices;

        // Determine available voice types from API
        this.hasStandardVoices = voices.some(v => v.isStandard === true);
        this.hasNeuralVoices = voices.some(v => v.isNeural === true);

        // Build filter options based on what's available and plan
        const options: ('All' | 'Standard' | 'Neural')[] = [];
        
        if (this.userCanUseNeural) {
          options.push('All');
          if (this.hasStandardVoices) options.push('Standard');
          if (this.hasNeuralVoices) options.push('Neural');
        } else {
          // Free users only see Standard filter
          if (this.hasStandardVoices) options.push('Standard');
          else options.push('All'); // Fallback if no standard voices found
        }
        
        this.filterOptions.set(options);

        // Set default filter
        if (this.userCanUseNeural) {
          this.currentFilter.set('All');
        } else if (this.hasStandardVoices) {
          this.currentFilter.set('Standard');
        } else {
          this.currentFilter.set('All');
        }

        this.applyFilter();

        if (this.filteredVoices().length > 0 && !this.selectedVoiceId) {
          this.selectedVoiceId = this.filteredVoices()[0].id;
        }
      },
      error: () => this.error.set('Failed to load voices.')
    });
  }

  applyFilter(): void {
    const filter = this.currentFilter();
    switch (filter) {
      case 'Standard':
        this.filteredVoices.set(this.voices.filter(v => v.isStandard === true));
        break;
      case 'Neural':
        this.filteredVoices.set(this.voices.filter(v => v.isNeural === true));
        break;
      default:
        this.filteredVoices.set([...this.voices]);
    }

    const voices = this.filteredVoices();
    if (voices.length > 0) {
      const currentExists = voices.find(v => v.id === this.selectedVoiceId);
      if (!currentExists) {
        this.selectedVoiceId = voices[0].id;
      }
    } else {
      this.selectedVoiceId = '';
    }
  }

  setFilter(filter: 'All' | 'Standard' | 'Neural'): void {
    if (filter === 'Neural' && !this.userCanUseNeural) {
      this.showNotification('Neural voices require a Pro subscription', 'error');
      return;
    }
    this.currentFilter.set(filter);
    this.applyFilter();
  }

  get selectedVoice(): Voice | undefined {
    return this.voices.find(v => v.id === this.selectedVoiceId);
  }

  toggleDropdown(event: MouseEvent): void {
    event.stopPropagation();
    this.isDropdownOpen = !this.isDropdownOpen;
  }

  selectVoice(voiceId: string): void {
    this.selectedVoiceId = voiceId;
    this.isDropdownOpen = false;
  }

  convert(): void {
    if (!this.text.trim() || !this.selectedVoiceId) return;
    this.loading.set(true);
    this.error.set('');

    if (this.audioUrl()) {
      URL.revokeObjectURL(this.audioUrl()!);
      this.audioUrl.set(null);
    }

    this.ttsService.synthesize(this.text, this.selectedVoiceId).subscribe({
      next: (blob) => {
        const audioBlob = new Blob([blob], { type: blob.type || 'audio/mpeg' });
        this.audioUrl.set(URL.createObjectURL(audioBlob));
        this.loading.set(false);
        this.showNotification('Audio generated successfully');
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set('Failed to generate audio. Please try again.');
        if (err.status === 400 || err.status === 403) {
          this.showNotification('Neural voices require a Pro subscription', 'error');
        }
      }
    });
  }

  download(): void {
    const url = this.audioUrl();
    if (!url) return;
    const a = document.createElement('a');
    a.href = url;
    a.download = `speakit-${Date.now()}.mp3`;
    a.click();
    this.showNotification('Download started');
  }

  onTimeUpdate(event: Event): void {
    const audio = event.target as HTMLAudioElement;
    this.currentTime = audio.currentTime;
    this.duration = audio.duration || 0;
  }

  get progressPercent(): number {
    return this.duration ? (this.currentTime / this.duration) * 100 : 0;
  }

  seekAudio(event: MouseEvent): void {
    const bar = event.currentTarget as HTMLElement;
    const audio = this.audioPlayerRef?.nativeElement;
    if (audio && audio.duration) {
      audio.currentTime = (event.offsetX / bar.clientWidth) * audio.duration;
    }
  }

  togglePlayPause(): void {
    const audio = this.audioPlayerRef?.nativeElement;
    if (!audio) return;
    this.isPlaying ? audio.pause() : audio.play();
    this.isPlaying = !this.isPlaying;
  }

  showNotification(message: string, type: 'success' | 'error' = 'success'): void {
    this.toastService.show(message, type);
  }
}
