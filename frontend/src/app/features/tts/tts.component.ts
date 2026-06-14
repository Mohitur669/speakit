/**
 * Main TTS workspace component managing voice selection,
 * text input, audio generation, playback controls,
 * and download functionality.
 */
import { Component, inject, signal, HostListener, effect, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TtsService, Voice } from '../../core/services/tts.service';
import { AuthService } from '../../core/auth/auth.service';
import { ToastService } from '../../core/services/toast.service';
import { FeatureFlagService } from '../../core/services/feature-flag.service';
import { RazorpayService } from '../../core/services/razorpay.service';
import { deriveVoiceType } from '../../shared';
import { ToastComponent } from '../../shared/components/toast/toast.component';
import { NavbarComponent } from '../../shared/components/navbar/navbar.component';
import { VoiceSelectorComponent } from './components/voice-selector/voice-selector.component';
import { TtsInputComponent } from './components/tts-input/tts-input.component';
import { TtsOutputComponent } from './components/tts-output/tts-output.component';
import { UsageStatsComponent } from './components/usage-stats/usage-stats.component';
import { UpgradeCardComponent } from './components/upgrade-card/upgrade-card.component';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

@Component({
  selector: 'app-tts',
  standalone: true,
  imports: [
    CommonModule, 
    FormsModule, 
    ToastComponent, 
    NavbarComponent,
    VoiceSelectorComponent,
    TtsInputComponent,
    TtsOutputComponent,
    UsageStatsComponent,
    // UpgradeCardComponent,
    RouterLink
  ],
  templateUrl: './tts.component.html',
  styleUrls: ['./tts.component.scss']
})
export class TtsComponent implements OnInit {
  ttsService = inject(TtsService);
  authService = inject(AuthService);
  featureFlags = inject(FeatureFlagService);
  private razorpayService = inject(RazorpayService);
  private toastService = inject(ToastService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  maxChars = signal<number>(3000);
  usage = signal<any>(null);
  text = '';
  selectedVoiceId = '';
  selectedVoiceType = 'STANDARD';
  voices: Voice[] = [];
  audioUrl = signal<string | null>(null);
  loading = signal(false);
  error = signal('');

  constructor() {
    effect(() => {
      // Track both login status and plan type to ensure UI refreshes after upgrade
      const isLoggedIn = this.authService.isLoggedIn();
      const plan = this.authService.currentPlanType();
      
      if (isLoggedIn) {
        this.refreshVoices();
        this.refreshLimits();
        this.refreshUsage();
      }
    });
  }

  @HostListener('window:keydown.control.enter', ['$event'])
  onCtrlEnter(event: Event): void {
    event.preventDefault();
    if (this.text.trim()) {
      this.convert();
    } else {
      this.showNotification('Please enter some text to generate audio', 'error');
    }
  }

  async ngOnInit() {
    this.checkAutostart();
    this.route.queryParams.subscribe(async params => {
      const autostart = params['autostart'];
      if (autostart) {
        const redirected = await this.invokeUpgrade(autostart);
        
        // Only clear params if we are still on the same page
        if (!redirected) {
          this.router.navigate([], {
            relativeTo: this.route,
            queryParams: { autostart: null },
            queryParamsHandling: 'merge'
          });
        }
      }
    });
  }

  private async checkAutostart() {
    const autostart = this.route.snapshot.queryParams['autostart'];
    if (autostart) {
      await this.invokeUpgrade(autostart);
    }
  }

  get userCanUseNeural(): boolean {
    return true; // AWS Polly Neural is now open to all Free users
  }

  get userCanUseNatural(): boolean {
    const plan = this.authService.currentPlanType();
    return plan === 'PRO_PLUS' || plan === 'ENTERPRISE';
  }

  get userCanUseSarvam(): boolean {
    const plan = this.authService.currentPlanType();
    return plan === 'PRO' || plan === 'PRO_PLUS' || plan === 'ENTERPRISE';
  }

  async refreshUsage() {
    this.ttsService.getUsage().subscribe(u => this.usage.set(u));
  }

  async refreshLimits() {
    const plan = this.authService.currentPlanType();
    let limitKey = 'MAX_FREE_CHARACTERS';
    let defaultVal = 100;

    if (plan === 'ENTERPRISE') {
      limitKey = 'MAX_ENTERPRISE_CHARACTERS';
      defaultVal = 2000;
    } else if (plan === 'PRO_PLUS') {
      limitKey = 'MAX_PRO_PLUS_CHARACTERS';
      defaultVal = 500;
    } else if (plan === 'PRO') {
      limitKey = 'MAX_PRO_CHARACTERS';
      defaultVal = 200;
    }
    
    const limit = await this.featureFlags.getLiveNumber(limitKey, defaultVal);
    this.maxChars.set(limit);
  }

  async invokeUpgrade(plan: string): Promise<boolean> {
    if (plan === 'ENTERPRISE') {
      this.router.navigate(['/contact']);
      return true;
    }

    const amount = plan === 'PRO' ? 
      await this.featureFlags.getLiveNumber('PRO_PLAN_PRICE_INR', 499) : 
      await this.featureFlags.getLiveNumber('PRO_PLUS_PLAN_PRICE_INR', 1999);
    
    this.razorpayService.initiatePayment(plan, amount);
    return false;
  }

  refreshVoices(): void {
    this.ttsService.getVoices().subscribe({
      next: (voices) => {
        this.voices = voices;
        if (this.voices.length > 0 && !this.selectedVoiceId) {
          const standard = this.voices.filter(v => !v.isElevenLabs && !v.isSarvam);
          if (standard.length > 0) this.selectedVoiceId = standard[0].id;
        }
      },
      error: () => this.error.set('Failed to load voices.')
    });
  }

  get selectedVoice(): Voice | undefined {
    return this.voices.find(v => v.id === this.selectedVoiceId);
  }

  handleNotification(event: {message: string, type: 'success' | 'error'}): void {
    this.showNotification(event.message, event.type);
  }

  handleVoiceChange(voiceId: string): void {
    this.selectedVoiceId = voiceId;
    if (this.audioUrl()) {
      URL.revokeObjectURL(this.audioUrl()!);
      this.audioUrl.set(null);
    }
  }

  convert(): void {
    if (!this.validateInput()) return;

    this.loading.set(true);
    this.error.set('');

    if (this.audioUrl()) {
      URL.revokeObjectURL(this.audioUrl()!);
      this.audioUrl.set(null);
    }

    const { text, voiceId, voiceName, voiceType, isElevenLabs, isSarvam, languageCode } = this.buildRequest();
    
    this.ttsService.synthesize(text, voiceId, voiceName, voiceType, isElevenLabs, isSarvam, languageCode).subscribe({
      next: (blob) => {
        const audioBlob = new Blob([blob], { type: blob.type || 'audio/mpeg' });
        this.audioUrl.set(URL.createObjectURL(audioBlob));
        this.loading.set(false);
        this.showNotification('Audio generated successfully');
        this.refreshUsage();
      },
      error: (err) => this.handleError(err)
    });
  }

  private validateInput(): boolean {
    if (!this.text.trim() || !this.selectedVoiceId) return false;
    
    if (this.usage()?.dailyLimit > 0 && this.usage()?.dailyCount >= this.usage()?.dailyLimit) {
      this.showNotification('Daily limit reached for Free plan. Please upgrade to Pro.', 'error');
      return false;
    }
    return true;
  }

  private buildRequest() {
    const voice = this.selectedVoice;
    const type = deriveVoiceType(voice);

    return {
      text: this.text,
      voiceId: this.selectedVoiceId,
      voiceName: voice?.name || this.selectedVoiceId,
      voiceType: type,
      isElevenLabs: !!voice?.isElevenLabs,
      isSarvam: !!voice?.isSarvam,
      languageCode: voice?.languageCode
    };
  }

  private handleError(err: any): void {
    this.loading.set(false);
    this.error.set('Failed to generate audio. Please try again.');
    if (err.status === 403) {
      this.showNotification(err.error?.message || 'Access denied', 'error');
    }
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

  showNotification(message: string, type: 'success' | 'error' = 'success'): void {
    this.toastService.show(message, type);
  }
}
