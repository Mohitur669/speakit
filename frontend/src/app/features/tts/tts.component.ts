/**
 * Main TTS workspace component managing voice selection,
 * text input, audio generation, playback controls,
 * and download functionality.
 */
import { Component, inject, signal, HostListener, effect, OnInit, OnDestroy, DestroyRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Subscription, interval } from 'rxjs';
import { switchMap } from 'rxjs/operators';

import { FormsModule } from '@angular/forms';
import { DecimalPipe } from '@angular/common';
import { TtsService, Voice, DocumentAnalysisDto, LongFormJobStatusDto } from '../../core/services/tts.service';
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
    FormsModule,
    DecimalPipe,
    ToastComponent,
    NavbarComponent,
    VoiceSelectorComponent,
    TtsInputComponent,
    TtsOutputComponent,
    UsageStatsComponent,
    RouterLink,
  ],
  templateUrl: './tts.component.html',
  styleUrls: ['./tts.component.scss'],
})
export class TtsComponent implements OnInit, OnDestroy {
  ttsService = inject(TtsService);
  private destroyRef = inject(DestroyRef);
  authService = inject(AuthService);
  featureFlags = inject(FeatureFlagService);
  private razorpayService = inject(RazorpayService);
  private toastService = inject(ToastService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  // Mode Selection: 'text' = standard synchronous TTS, 'document' = PDF audiobook synthesis
  mode = signal<'text' | 'document'>('text');

  maxChars = signal<number>(3000);
  usage = signal<any>(null);
  text = '';
  selectedVoiceId = '';
  selectedVoiceType = 'STANDARD';
  voices: Voice[] = [];
  audioUrl = signal<string | null>(null);
  loading = signal(false);
  showSettings = signal(false);
  error = signal('');

  // Document to Speech signals
  selectedFile = signal<File | null>(null);
  isDragging = signal(false);
  analyzingDocument = signal(false);
  documentAnalysis = signal<DocumentAnalysisDto | null>(null);
  documentError = signal<string | null>(null);
  activeJob = signal<LongFormJobStatusDto | null>(null);
  synthesizingJob = signal(false);
  jobAudioUrl = signal<string | null>(null);
  jobComplete = signal(false);
  private pollingSubscription: Subscription | null = null;

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
    this.route.queryParams.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(async (params) => {
      const autostart = params['autostart'];
      if (autostart) {
        const redirected = await this.invokeUpgrade(autostart);

        // Only clear params if we are still on the same page
        if (!redirected) {
          this.router.navigate([], {
            relativeTo: this.route,
            queryParams: { autostart: null },
            queryParamsHandling: 'merge',
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
    this.ttsService.getUsage().subscribe((u) => this.usage.set(u));
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

    const amount =
      plan === 'PRO'
        ? await this.featureFlags.getLiveNumber('PRO_PLAN_PRICE_INR', 499)
        : await this.featureFlags.getLiveNumber('PRO_PLUS_PLAN_PRICE_INR', 1999);

    this.razorpayService.initiatePayment(plan, amount);
    return false;
  }

  refreshVoices(): void {
    this.ttsService.getVoices().subscribe({
      next: (voices) => {
        this.voices = voices;
        if (this.voices.length > 0 && !this.selectedVoiceId) {
          const standard = this.voices.filter((v) => !v.isElevenLabs && !v.isSarvam);
          if (standard.length > 0) this.selectedVoiceId = standard[0].id;
        }
      },
      error: () => this.error.set('Failed to load voices.'),
    });
  }

  get selectedVoice(): Voice | undefined {
    return this.voices.find((v) => v.id === this.selectedVoiceId);
  }

  handleNotification(event: { message: string; type: 'success' | 'error' }): void {
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

    const { text, voiceId, voiceName, voiceType, isElevenLabs, isSarvam, languageCode } =
      this.buildRequest();

    this.ttsService
      .synthesize(text, voiceId, voiceName, voiceType, isElevenLabs, isSarvam, languageCode)
      .subscribe({
        next: (blob) => {
          const audioBlob = new Blob([blob], { type: blob.type || 'audio/mpeg' });
          this.audioUrl.set(URL.createObjectURL(audioBlob));
          this.loading.set(false);
          this.showNotification('Audio generated successfully');
          this.refreshUsage();
        },
        error: (err) => this.handleError(err),
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
      languageCode: voice?.languageCode,
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

  ngOnDestroy(): void {
    this.stopPolling();
  }

  switchMode(newMode: 'text' | 'document'): void {
    this.mode.set(newMode);
  }

  // --- Document-to-Speech Workflow ---

  onDragOver(event: DragEvent): void {
    event.preventDefault();
    event.stopPropagation();
    this.isDragging.set(true);
  }

  onDragLeave(event: DragEvent): void {
    event.preventDefault();
    event.stopPropagation();
    this.isDragging.set(false);
  }

  onFileDropped(event: DragEvent): void {
    event.preventDefault();
    event.stopPropagation();
    this.isDragging.set(false);

    if (event.dataTransfer?.files && event.dataTransfer.files.length > 0) {
      this.processFile(event.dataTransfer.files[0]);
    }
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.processFile(input.files[0]);
    }
  }

  processFile(file: File): void {
    this.documentError.set(null);
    this.documentAnalysis.set(null);
    this.activeJob.set(null);
    this.jobComplete.set(false);
    this.jobAudioUrl.set(null);

    // Client-side pre-validation
    const name = file.name.toLowerCase();
    if (!name.endsWith('.pdf')) {
      this.documentError.set('Only PDF documents (.pdf) are supported.');
      this.showNotification('Only PDF documents are supported.', 'error');
      return;
    }

    if (file.size === 0) {
      this.documentError.set('Uploaded file is empty.');
      this.showNotification('Uploaded file is empty.', 'error');
      return;
    }

    this.selectedFile.set(file);
    this.analyzingDocument.set(true);

    this.ttsService.analyzeDocument(file).subscribe({
      next: (analysis) => {
        this.documentAnalysis.set(analysis);
        this.analyzingDocument.set(false);
        this.showNotification('Document analyzed successfully.');
      },
      error: (err) => {
        this.analyzingDocument.set(false);
        const msg = err.error?.error || err.error?.message || 'Failed to analyze document.';
        this.documentError.set(msg);
        this.showNotification(msg, 'error');
      },
    });
  }

  clearDocument(): void {
    this.selectedFile.set(null);
    this.documentAnalysis.set(null);
    this.documentError.set(null);
    this.activeJob.set(null);
    this.jobComplete.set(false);
    this.jobAudioUrl.set(null);
    this.synthesizingJob.set(false);
    this.stopPolling();
  }

  synthesizeDocument(): void {
    const analysis = this.documentAnalysis();
    if (!analysis) return;

    if (!this.selectedVoiceId) {
      this.showNotification('Please select a narrator voice.', 'error');
      return;
    }

    this.synthesizingJob.set(true);
    this.documentError.set(null);
    const voice = this.selectedVoice;

    const payload = {
      documentToken: analysis.documentToken,
      sourceFileName: analysis.fileName,
      title: analysis.fileName.replace(/\.pdf$/i, ''),
      voiceId: this.selectedVoiceId,
      outputFormat: 'mp3',
      isElevenLabs: !!voice?.isElevenLabs,
      isSarvam: !!voice?.isSarvam,
      languageCode: voice?.languageCode,
    };

    this.ttsService.submitJob(payload).subscribe({
      next: (job) => {
        this.activeJob.set(job);
        this.startPolling(job.jobId);
        this.showNotification('Audiobook synthesis started.');
      },
      error: (err) => {
        this.synthesizingJob.set(false);
        const msg = err.error?.error || err.error?.message || 'Failed to submit synthesis job.';
        this.documentError.set(msg);
        this.showNotification(msg, 'error');
      },
    });
  }

  private startPolling(jobId: string): void {
    this.stopPolling();
    this.pollingSubscription = interval(2500)
      .pipe(
        switchMap(() => this.ttsService.getJobStatus(jobId)),
        takeUntilDestroyed(this.destroyRef)
      )
      .subscribe({
        next: (job) => {
          this.activeJob.set(job);
          if (job.status === 'COMPLETED') {
            this.stopPolling();
            this.synthesizingJob.set(false);
            this.jobComplete.set(true);
            if (job.audioUrl) {
              this.jobAudioUrl.set(job.audioUrl);
            }
            this.showNotification('Audiobook generated successfully!');
            this.refreshUsage();
          } else if (job.status === 'FAILED') {
            this.stopPolling();
            this.synthesizingJob.set(false);
            const msg = job.errorMessage || 'Synthesis job failed.';
            this.documentError.set(msg);
            this.showNotification(msg, 'error');
          }
        },
        error: (err) => {
          this.stopPolling();
          this.synthesizingJob.set(false);
          this.documentError.set('Connection lost during status polling.');
        },
      });
  }

  private stopPolling(): void {
    if (this.pollingSubscription) {
      this.pollingSubscription.unsubscribe();
      this.pollingSubscription = null;
    }
  }

  downloadAudiobook(): void {
    const url = this.jobAudioUrl();
    if (!url) return;
    const a = document.createElement('a');
    a.href = url;
    a.target = '_blank';
    a.download = `${this.documentAnalysis()?.fileName || 'audiobook'}.mp3`;
    a.click();
    this.showNotification('Audiobook download started.');
  }

  showNotification(message: string, type: 'success' | 'error' = 'success'): void {
    this.toastService.show(message, type);
  }
}
