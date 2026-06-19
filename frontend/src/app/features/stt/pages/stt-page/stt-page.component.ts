import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavbarComponent } from '../../../../shared/components/navbar/navbar.component';
import { AuthService } from '../../../../core/auth/auth.service';
import { SttService } from '../../services/stt.service';
import { UploadAreaComponent } from '../../components/upload-area/upload-area.component';
import { TranscriptCardComponent } from '../../components/transcript-card/transcript-card.component';
import { LockedFeatureCardComponent } from '../../components/locked-feature-card/locked-feature-card.component';
import { CustomDropdownComponent, DropdownOption } from '../../../../shared/components/custom-dropdown/custom-dropdown.component';
import { SttResult } from '../../models/stt.models';
import { ToastService } from '../../../../core/services/toast.service';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { RazorpayService } from '../../../../core/services/razorpay.service';
import { FeatureFlagService } from '../../../../core/services/feature-flag.service';

@Component({
  selector: 'app-stt-page',
  standalone: true,
  imports: [
    CommonModule, 
    NavbarComponent, 
    UploadAreaComponent, 
    TranscriptCardComponent, 
    LockedFeatureCardComponent,
    CustomDropdownComponent,
    RouterLink
  ],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 py-4 sm:py-8 md:py-12">
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          
          <!-- Studio Module Toggle -->
          <div class="flex justify-center mb-8 sm:mb-12">
            <div class="inline-flex p-1.5 bg-primary-100 dark:bg-primary-800/40 rounded-2xl border border-primary-300 dark:border-primary-700/50 shadow-inner backdrop-blur-sm">
              <a routerLink="/tts" class="flex items-center gap-2.5 px-6 py-2.5 rounded-xl text-sm font-bold transition-all text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white group">
                <svg class="w-4 h-4 transition-transform group-hover:scale-110" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"></path>
                </svg>
                Text to Speech
              </a>
              <button class="flex items-center gap-2.5 px-6 py-2.5 rounded-xl text-sm font-bold transition-all bg-white dark:bg-primary-900 text-brand-blue shadow-xl dark:shadow-[0_10px_25px_-5px_rgba(0,0,0,0.5)] ring-1 ring-black/5 dark:ring-white/10">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z M19 10v1a7 7 0 01-14 0v-1 M12 18v4 M8 22h8"></path>
                </svg>
                Speech to Text
              </button>
            </div>
          </div>

          <div class="mb-12 animate-slide-up">
            <h1 class="text-4xl md:text-5xl font-bold text-primary-900 dark:text-white tracking-tight mb-4">
              Speech to <span class="text-transparent bg-clip-text bg-gradient-to-r from-brand-blue via-brand-purple to-accent-500">Text</span>
            </h1>
            <p class="text-lg text-primary-600 dark:text-primary-400">Transform your audio files into accurate text instantly.</p>
          </div>

          <!-- Feature Locked State -->
          <ng-container *ngIf="!hasAccess(); else featureContent">
            <app-locked-feature-card></app-locked-feature-card>
          </ng-container>

          <!-- Feature Active State -->
          <ng-template #featureContent>
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
              
              <!-- Sidebar: Configuration -->
              <div class="lg:col-span-1 space-y-6">
                <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-300 dark:border-primary-700 p-6 shadow-lg">
                  <h3 class="text-sm font-bold text-primary-900 dark:text-white tracking-wider mb-4">Settings</h3>
                  
                  <div class="grid grid-cols-2 lg:grid-cols-1 gap-6">
                    <div>
                      <label class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest">Engine</label>
                      <app-custom-dropdown
                        [options]="engines"
                        [(value)]="selectedProvider"
                        [disabled]="isProviderLocked()"
                        placeholder="Sarvam (Default)">
                      </app-custom-dropdown>
                      <p *ngIf="isProviderLocked()" class="mt-2 text-[10px] text-primary-400 font-medium italic">
                        * Pro Plus required.
                      </p>
                    </div>
 
                    <div>
                      <label class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest">Language</label>
                      <app-custom-dropdown
                        [options]="languages"
                        [(value)]="selectedLanguage"
                        placeholder="English (IN)">
                      </app-custom-dropdown>
                    </div>

                    <div class="col-span-2 lg:col-span-1 p-4 bg-primary-50 dark:bg-primary-800/50 rounded-xl border border-primary-200 dark:border-primary-700/50">
                      <div class="flex items-center gap-3 text-brand-blue mb-2">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                        <span class="text-sm font-bold">Plan Quota</span>
                      </div>
                      <p class="text-xs text-primary-600 dark:text-primary-400 leading-relaxed">
                        Your plan allows files up to {{ maxFileSize }}MB and {{ maxDuration }} minutes.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Main: Upload & Results -->
              <div class="lg:col-span-2 flex flex-col gap-6">
                <app-upload-area (fileChange)="onFileSelected($event)"></app-upload-area>

                <button 
                  (click)="onTranscribe()"
                  [disabled]="loading() || !selectedFile()"
                  class="w-full py-4 px-6 rounded-2xl font-bold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed shadow-xl hover:shadow-brand-blue/20 active:scale-[0.98] transition-all flex items-center justify-center gap-3">
                  <svg *ngIf="loading()" class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                  </svg>
                  <svg *ngIf="!loading()" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z M19 10v1a7 7 0 01-14 0v-1 M12 18v4 M8 22h8"></path>
                  </svg>
                  <span>{{ loading() ? 'Transcribing...' : 'Start Transcription' }}</span>
                </button>

                <div *ngIf="error()" class="p-4 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-xl text-sm font-medium border border-red-200 dark:border-red-800/30 animate-shake">
                  {{ error() }}
                </div>

                <app-transcript-card *ngIf="result()" [result]="result()!"></app-transcript-card>
              </div>

            </div>
          </ng-template>
        </div>
      </main>
    </div>
  `
})
export class SttPageComponent implements OnInit {
  private authService = inject(AuthService);
  private sttService = inject(SttService);
  private toast = inject(ToastService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private razorpayService = inject(RazorpayService);
  private featureFlags = inject(FeatureFlagService);

  loading = signal(false);
  error = signal('');
  selectedFile = signal<File | null>(null);
  selectedLanguage = 'en-IN';
  selectedProvider = 'SARVAM';
  result = signal<SttResult | null>(null);

  engines: DropdownOption[] = [
    { value: 'SARVAM', label: 'Indian' },
    { value: 'ELEVEN_LABS', label: 'Global' }
  ];

  languages: DropdownOption[] = [
    { value: 'en-IN', label: 'English (IN)' },
    { value: 'hi-IN', label: 'Hindi' },
    { value: 'bn-IN', label: 'Bengali' },
    { value: 'ta-IN', label: 'Tamil' },
    { value: 'te-IN', label: 'Telugu' },
    { value: 'mr-IN', label: 'Marathi' },
    { value: 'kn-IN', label: 'Kannada' },
    { value: 'gu-IN', label: 'Gujarati' }
  ];

  ngOnInit(): void {
    // Lock provider to Sarvam if only on PRO plan
    if (this.authService.currentPlanType() === 'PRO') {
      this.selectedProvider = 'SARVAM';
    }

    // Process autostart query parameter for upgrades
    this.route.queryParams.subscribe(async params => {
      const autostart = params['autostart'];
      if (autostart) {
        await this.invokeUpgrade(autostart);
        
        // Clear params after invoking the upgrade
        this.router.navigate([], {
          relativeTo: this.route,
          queryParams: { autostart: null },
          queryParamsHandling: 'merge'
        });
      }
    });
  }

  async invokeUpgrade(plan: string) {
    if (plan === 'ENTERPRISE') {
      this.router.navigate(['/contact']);
      return;
    }

    const amount = plan === 'PRO' ? 
      await this.featureFlags.getLiveNumber('PRO_PLAN_PRICE_INR', 499) : 
      await this.featureFlags.getLiveNumber('PRO_PLUS_PLAN_PRICE_INR', 1999);
    
    this.razorpayService.initiatePayment(plan, amount);
  }

  hasAccess(): boolean {
    const plan = this.authService.currentPlanType();
    return ['PRO_PLUS', 'ENTERPRISE'].includes(plan);
  }

  isProviderLocked(): boolean {
    return false;
  }

  get maxFileSize(): number {
    const plan = this.authService.currentPlanType();
    return plan === 'PRO_PLUS' || plan === 'ENTERPRISE' ? 50 : 25;
  }

  get maxDuration(): number {
    const plan = this.authService.currentPlanType();
    return plan === 'PRO_PLUS' || plan === 'ENTERPRISE' ? 30 : 15;
  }

  onFileSelected(file: File) {
    this.selectedFile.set(file);
    this.error.set('');
    this.result.set(null);
  }

  onTranscribe() {
    const file = this.selectedFile();
    if (!file) return;

    if (file.size > this.maxFileSize * 1024 * 1024) {
      this.error.set('File is too large. Your plan limit is ' + this.maxFileSize + 'MB.');
      return;
    }

    this.loading.set(true);
    this.error.set('');
    this.result.set(null);

    this.sttService.transcribe(file, this.selectedLanguage, this.selectedProvider).subscribe({
      next: (res) => {
        this.result.set(res);
        this.loading.set(false);
        this.toast.show('Transcription complete', 'success');
      },
      error: (err) => {
        this.loading.set(false);
        if (err.status === 403) {
          this.error.set('Speech-to-Text is available only for Pro plans.');
        } else if (err.status === 413) {
          this.error.set('Audio file is too large for the server to process.');
        } else {
          // Check for detailed business rule violation
          const serverMsg = err.error?.message;
          this.error.set(serverMsg || 'Transcription failed. Please check the file format.');
        }
        this.toast.show('Operation failed', 'error');
      }
    });
  }
}
