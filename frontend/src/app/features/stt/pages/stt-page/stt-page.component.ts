import { Component, inject, signal, OnInit, OnDestroy, DestroyRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { NavbarComponent } from '../../../../shared/components/navbar/navbar.component';
import { AuthService } from '../../../../core/auth/auth.service';
import { SttService } from '../../services/stt.service';
import { UploadAreaComponent } from '../../components/upload-area/upload-area.component';
import { AudioRecorderComponent } from '../../components/audio-recorder/audio-recorder.component';
import { TranscriptCardComponent } from '../../components/transcript-card/transcript-card.component';
import { LockedFeatureCardComponent } from '../../components/locked-feature-card/locked-feature-card.component';
import {
  CustomDropdownComponent,
  DropdownOption,
} from '../../../../shared/components/custom-dropdown/custom-dropdown.component';
import { SttResult } from '../../models/stt.models';
import { ToastService } from '../../../../core/services/toast.service';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { RazorpayService } from '../../../../core/services/razorpay.service';
import { FeatureFlagService } from '../../../../core/services/feature-flag.service';
import { getSpeakersForLanguage, DEFAULT_SPEAKERS } from '../../models/sarvam-voices.config';


@Component({
  selector: 'app-stt-page',
  standalone: true,
  imports: [
    NavbarComponent,
    UploadAreaComponent,
    AudioRecorderComponent,
    TranscriptCardComponent,
    LockedFeatureCardComponent,
    CustomDropdownComponent,
    RouterLink,
  ],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 py-4 sm:py-8 md:py-12">
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Studio Module Toggle -->
          <div class="flex justify-center mb-8 sm:mb-12">
            <div
              class="inline-flex p-1.5 bg-primary-100 dark:bg-primary-800/40 rounded-2xl border border-primary-300 dark:border-primary-700/50 shadow-inner backdrop-blur-sm"
            >
              <a
                routerLink="/tts"
                class="flex items-center gap-2.5 px-6 py-2.5 rounded-xl text-sm font-bold transition-all text-primary-500 hover:text-primary-900 dark:text-primary-400 dark:hover:text-white group"
              >
                <svg
                  class="w-4 h-4 transition-transform group-hover:scale-110"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"
                  ></path>
                </svg>
                Text to Speech
              </a>
              <button
                class="flex items-center gap-2.5 px-6 py-2.5 rounded-xl text-sm font-bold transition-all bg-white dark:bg-primary-900 text-brand-blue shadow-xl dark:shadow-[0_10px_25px_-5px_rgba(0,0,0,0.5)] ring-1 ring-black/5 dark:ring-white/10"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z M19 10v1a7 7 0 01-14 0v-1 M12 18v4 M8 22h8"
                  ></path>
                </svg>
                Speech to Text
              </button>
            </div>
          </div>

          <div class="mb-12 animate-slide-up">
            <h1
              class="text-4xl md:text-5xl font-bold text-primary-900 dark:text-white tracking-tight mb-4"
            >
              Speech to
              <span
                class="text-transparent bg-clip-text bg-gradient-to-r from-brand-blue via-brand-purple to-accent-500"
                >Text</span
              >
            </h1>
            <p class="text-lg text-primary-600 dark:text-primary-400">
              Transform your audio files and recorded voice into accurate text instantly.
            </p>
          </div>

          <!-- Feature Locked State -->
          @if (!hasAccess()) {
            <app-locked-feature-card></app-locked-feature-card>
          } @else {
            <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
              <!-- Sidebar: Configuration -->
              <div class="hidden md:block md:col-span-1 space-y-6">
                <div
                  class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-300 dark:border-primary-700 p-6 shadow-lg"
                >
                  <h3
                    class="text-sm font-bold text-primary-900 dark:text-white tracking-wider mb-4"
                  >
                    Settings
                  </h3>
                  <div class="grid grid-cols-2 lg:grid-cols-1 gap-6">
                    <div>
                      <label
                        class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest"
                        >Engine</label
                      >
                      <app-custom-dropdown
                        [options]="engines"
                        [value]="selectedProvider"
                        (valueChange)="onProviderChange($event)"
                        [disabled]="isProviderLocked() || isRecording()"
                        placeholder="Sarvam (Default)"
                        direction="up"
                      >
                      </app-custom-dropdown>
                      @if (isProviderLocked()) {
                        <p class="mt-2 text-[10px] text-primary-400 font-medium italic">
                          * Pro Plus required.
                        </p>
                      }
                    </div>
                    <div>
                      <label
                        class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest"
                        >Language</label
                      >
                      <app-custom-dropdown
                        [options]="languages"
                        [value]="selectedLanguage"
                        (valueChange)="onLanguageChange($event)"
                        [disabled]="isRecording()"
                        placeholder="English (IN)"
                        direction="up"
                      >
                      </app-custom-dropdown>
                    </div>
                    @if (isSarvamSupported()) {
                      <div class="col-span-2 lg:col-span-1 animate-slide-up">
                        <label
                          class="block text-xs font-semibold text-primary-500 mb-2 tracking-widest"
                          >Narrator Voice</label
                        >
                        <app-custom-dropdown
                          [options]="narratorOptions()"
                          [value]="selectedNarrator()"
                          (valueChange)="selectedNarrator.set($event)"
                          [disabled]="isRecording()"
                          placeholder="Select Speaker..."
                          direction="up"
                        >
                        </app-custom-dropdown>
                      </div>
                    }
                    <div
                      class="col-span-2 lg:col-span-1 p-4 bg-primary-50 dark:bg-primary-800/50 rounded-xl border border-primary-200 dark:border-primary-700/50"
                    >
                      <div class="flex items-center gap-3 text-brand-blue mb-2">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                          ></path>
                        </svg>
                        <span class="text-sm font-bold">Plan Quota</span>
                      </div>
                      <p class="text-xs text-primary-600 dark:text-primary-400 leading-relaxed">
                        Your plan allows files up to {{ maxFileSize }}MB and
                        {{ maxDuration }} minutes.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <!-- Main: Upload & Results -->
              <div class="md:col-span-2 flex flex-col gap-6">
                <!-- Navigation Tabs & Settings Gear (Mobile Only) -->
                <div class="flex items-center justify-between border-b border-primary-200 dark:border-primary-800 pb-2">
                  <div class="flex items-center gap-4">
                    <button
                      type="button"
                      (click)="selectRecordTab()"
                      [disabled]="isRecording() || loading()"
                      [class]="activeTab() === 'record' ? 'text-brand-blue border-b-2 border-brand-blue font-bold' : 'text-primary-500 dark:text-primary-400 font-medium hover:text-primary-700 dark:hover:text-primary-200'"
                      class="px-4 py-2 text-sm transition-all flex items-center gap-1.5 disabled:opacity-50"
                    >
                      @if (!isProPlusOrAbove()) {
                        <svg class="w-3.5 h-3.5 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                        </svg>
                      }
                      <span>Record Voice</span>
                      @if (isRecording()) {
                        <span class="w-2 h-2 rounded-full bg-red-500 animate-pulse" title="Recording active"></span>
                      } @else if (recordedBlob()) {
                        <span class="w-2 h-2 rounded-full bg-brand-blue" title="Recording ready for transcription"></span>
                      }
                    </button>
                    <button
                      type="button"
                      (click)="activeTab.set('upload')"
                      [disabled]="isRecording() || loading()"
                      [class]="activeTab() === 'upload' ? 'text-brand-blue border-b-2 border-brand-blue font-bold' : 'text-primary-500 dark:text-primary-400 font-medium hover:text-primary-700 dark:hover:text-primary-200'"
                      class="px-4 py-2 text-sm transition-all disabled:opacity-50 flex items-center gap-1.5"
                    >
                      <span>Upload File</span>
                      @if (selectedFile()) {
                        <span class="w-2 h-2 rounded-full bg-brand-blue" title="File selected"></span>
                      }
                    </button>
                  </div>

                  <!-- Gear Icon (Visible only on mobile, hidden on tablet/desktop md:) -->
                  <button
                    type="button"
                    (click)="showSettings.set(true)"
                    class="md:hidden p-2 text-primary-500 hover:text-brand-blue dark:text-primary-400 dark:hover:text-white rounded-xl bg-primary-100 hover:bg-primary-200 dark:bg-primary-800 dark:hover:bg-primary-700/80 transition-all border border-primary-300 dark:border-primary-700/50 shadow-inner"
                    title="Speech to Text Settings"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                    </svg>
                  </button>
                </div>

                @if (activeTab() === 'upload') {
                  <app-upload-area (fileChange)="onFileSelected($event)"></app-upload-area>
                  <button
                    (click)="onTranscribe()"
                    [disabled]="loading() || !selectedFile()"
                    class="w-full py-4 px-6 rounded-2xl font-bold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed shadow-xl hover:shadow-brand-blue/20 active:scale-[0.98] transition-all flex items-center justify-center gap-3"
                  >
                    @if (loading()) {
                      <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle
                          class="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          stroke-width="4"
                        ></circle>
                        <path
                          class="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                        ></path>
                      </svg>
                    }
                    @if (!loading()) {
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z M19 10v1a7 7 0 01-14 0v-1 M12 18v4 M8 22h8"
                        ></path>
                      </svg>
                    }
                    <span>{{ loading() ? 'Transcribing...' : 'Start Transcription' }}</span>
                  </button>
                } @else {
                  @if (recordedBlob()) {
                    <!-- Recorded Audio Review State -->
                    <div class="flex flex-col items-center justify-center p-8 bg-primary-50/50 dark:bg-primary-900/20 border-2 border-dashed border-primary-300 dark:border-primary-700/80 rounded-2xl animate-slide-up gap-6 w-full">
                      <div class="w-16 h-16 rounded-full bg-brand-blue/10 text-brand-blue flex items-center justify-center">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
                        </svg>
                      </div>
                      
                      <div class="text-center">
                        <h4 class="text-base font-bold text-primary-900 dark:text-white">Voice Recording Ready</h4>
                        <p class="text-xs text-primary-500 mt-1">Review your audio recording before starting transcription</p>
                      </div>

                      <!-- Custom Playback (Matches the App Styling) -->
                      <div class="w-full max-w-md bg-white dark:bg-primary-900 rounded-xl border border-primary-300 dark:border-primary-700 p-6 shadow-md">
                        <div class="flex items-center gap-4 w-full">
                          <!-- Play/Pause Button -->
                          <button
                            type="button"
                            (click)="togglePlayback(audioPlayer)"
                            class="w-12 h-12 rounded-full bg-gradient-to-br from-brand-blue to-brand-purple text-white flex items-center justify-center hover:scale-105 active:scale-95 transition-all shadow-lg shrink-0"
                          >
                            @if (!isPlaying()) {
                              <svg class="w-5 h-5 ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M8 5v14l11-7z" />
                              </svg>
                            } @else {
                              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
                              </svg>
                            }
                          </button>

                          <!-- Progress & Times -->
                          <div class="flex-1 min-w-0">
                            <div class="flex justify-between text-xs text-primary-400 mb-2">
                              <span>{{ formatTime(currentTime()) }}</span>
                              <span>{{ formatTime(duration()) }}</span>
                            </div>
                            <div
                              class="h-2 bg-primary-100 dark:bg-primary-800 rounded-full cursor-pointer overflow-hidden group relative"
                              (click)="seekAudio(audioPlayer, $event)"
                            >
                              <div
                                class="h-full bg-brand-blue rounded-full group-hover:shadow-lg group-hover:shadow-brand-blue/30"
                                [style.width.%]="(currentTime() / (duration() || 1)) * 100"
                              ></div>
                            </div>
                          </div>
                        </div>

                        <!-- Hidden Audio Element -->
                        <audio
                          #audioPlayer
                          [src]="audioUrl()"
                          (timeupdate)="onTimeUpdate(audioPlayer)"
                          (loadedmetadata)="onLoadedMetadata(audioPlayer)"
                          (play)="isPlaying.set(true)"
                          (pause)="isPlaying.set(false)"
                          (ended)="isPlaying.set(false)"
                          class="hidden"
                        ></audio>
                      </div>

                      <!-- Action Buttons -->
                      <div class="flex flex-col sm:flex-row items-center gap-4 w-full max-w-md">
                        <button
                          type="button"
                          (click)="discardRecording()"
                          [disabled]="loading()"
                          class="w-full sm:flex-1 py-3.5 px-5 rounded-xl font-bold text-primary-700 dark:text-primary-200 bg-primary-100 hover:bg-primary-200 dark:bg-primary-800 dark:hover:bg-primary-700 disabled:opacity-50 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                          </svg>
                          <span>Record Again</span>
                        </button>

                        <button
                          type="button"
                          (click)="transcribeRecordedAudio()"
                          [disabled]="loading()"
                          class="w-full sm:flex-1 py-3.5 px-5 rounded-xl font-bold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 transition-all active:scale-[0.98] flex items-center justify-center gap-2 shadow-lg shadow-brand-blue/10"
                        >
                          @if (loading()) {
                            <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                            </svg>
                            <span>Transcribing...</span>
                          } @else {
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                            <span>Transcribe</span>
                          }
                        </button>
                      </div>
                    </div>
                  } @else {
                    <app-audio-recorder
                      (recordingStarted)="onRecordingStarted()"
                      (recordingCancelled)="onRecordingCancelled()"
                      (recordingComplete)="onRecordingComplete($event)"
                      (recordingDuration)="onRecordingDuration($event)"
                    ></app-audio-recorder>
                  }
                }

                <!-- Minimal Progress Bar
                @if (loading()) {
                  <div class="w-full bg-primary-100 dark:bg-primary-800/50 rounded-full h-1.5 overflow-hidden mb-4 border border-primary-200/30 dark:border-primary-700/20">
                    <div
                      class="bg-gradient-to-r from-brand-blue to-brand-purple h-1.5 rounded-full transition-all duration-300 ease-out"
                      [style.width.%]="transcribeProgress()"
                    ></div>
                  </div>
                }
                -->

                @if (error()) {
                  <div
                    class="p-4 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-xl text-sm font-medium border border-red-200 dark:border-red-800/30 animate-shake"
                  >
                    {{ error() }}
                  </div>
                }
                @if (result()) {
                  <app-transcript-card 
                    [result]="result()!"
                    [defaultNarratorVoice]="selectedNarrator()"
                    [defaultNarratorLanguage]="selectedLanguage"
                  ></app-transcript-card>
                }
              </div>
            </div>
          }

          <!-- STT Settings Modal (Mobile Only) -->
          @if (showSettings()) {
            <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-4" (click)="showSettings.set(false)">
              <div 
                class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-300 dark:border-primary-700 shadow-2xl w-full max-w-md overflow-hidden animate-slide-up flex flex-col max-h-[85vh]"
                (click)="$event.stopPropagation()"
              >
                <!-- Header -->
                <div class="px-6 py-4 border-b border-primary-200 dark:border-primary-800 flex items-center justify-between bg-primary-50 dark:bg-primary-800/40">
                  <div class="flex items-center gap-2">
                    <svg class="w-5 h-5 text-brand-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                    </svg>
                    <h3 class="text-base font-bold text-primary-900 dark:text-white">Speech to Text Settings</h3>
                  </div>
                  <button
                    type="button"
                    (click)="showSettings.set(false)"
                    class="p-1.5 text-primary-500 hover:text-primary-700 dark:text-primary-400 dark:hover:text-white rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 transition-colors"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                  </button>
                </div>

                <!-- Body -->
                <div class="p-6 overflow-y-auto space-y-6 flex-1">
                  <div>
                    <label class="block text-xs font-bold text-primary-500 mb-2 tracking-wider">ENGINE</label>
                    <app-custom-dropdown
                      [options]="engines"
                      [value]="selectedProvider"
                      (valueChange)="onProviderChange($event)"
                      [disabled]="isProviderLocked() || isRecording()"
                      placeholder="Sarvam (Default)"
                      direction="down"
                    >
                    </app-custom-dropdown>
                    @if (isProviderLocked()) {
                      <p class="mt-2 text-[10px] text-primary-400 font-medium italic">
                        * Pro Plus required.
                      </p>
                    }
                  </div>

                  <div>
                    <label class="block text-xs font-bold text-primary-500 mb-2 tracking-wider">LANGUAGE</label>
                    <app-custom-dropdown
                      [options]="languages"
                      [value]="selectedLanguage"
                      (valueChange)="onLanguageChange($event)"
                      [disabled]="isRecording()"
                      placeholder="English (IN)"
                      direction="down"
                    >
                    </app-custom-dropdown>
                  </div>

                  @if (isSarvamSupported()) {
                    <div class="animate-slide-up">
                      <label class="block text-xs font-bold text-primary-500 mb-2 tracking-wider">NARRATOR VOICE</label>
                      <app-custom-dropdown
                        [options]="narratorOptions()"
                        [value]="selectedNarrator()"
                        (valueChange)="selectedNarrator.set($event)"
                        [disabled]="isRecording()"
                        placeholder="Select Speaker..."
                        direction="down"
                      >
                      </app-custom-dropdown>
                    </div>
                  }

                  <div class="p-4 bg-primary-50 dark:bg-primary-800/50 rounded-xl border border-primary-200 dark:border-primary-700/50">
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

                <!-- Footer -->
                <div class="px-6 py-4 border-t border-primary-200 dark:border-primary-800 flex justify-end bg-primary-50 dark:bg-primary-800/20">
                  <button
                    type="button"
                    (click)="showSettings.set(false)"
                    class="px-5 py-2 rounded-xl text-sm font-bold text-white bg-brand-blue hover:bg-brand-blue/90 shadow-lg active:scale-[0.98] transition-all"
                  >
                    Apply Settings
                  </button>
                </div>
              </div>
            </div>
          }
        </div>
      </main>
    </div>
  `,
})
export class SttPageComponent implements OnInit, OnDestroy {
  private authService = inject(AuthService);
  private destroyRef = inject(DestroyRef);
  private sttService = inject(SttService);
  private toast = inject(ToastService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private razorpayService = inject(RazorpayService);
  private featureFlags = inject(FeatureFlagService);

  loading = signal(false);
  showSettings = signal(false);
  error = signal('');
  selectedFile = signal<File | null>(null);
  selectedLanguage = 'auto';
  selectedProvider = 'SARVAM';
  result = signal<SttResult | null>(null);

  selectedNarrator = signal('');
  narratorOptions = signal<DropdownOption[]>([]);
  isSarvamSupported = signal(false);

  activeTab = signal<'upload' | 'record'>('record');
  isRecording = signal(false);

  recordedBlob = signal<Blob | null>(null);
  audioUrl = signal<string | null>(null);
  isPlaying = signal(false);
  currentTime = signal(0);
  duration = signal(0);
  recordedDuration = signal(0);

  transcribeProgress = signal(0);
  private progressInterval?: any;

  engines: DropdownOption[] = [
    { value: 'SARVAM', label: 'Indian' },
    { value: 'ELEVEN_LABS', label: 'Global' },
  ];

  languages: DropdownOption[] = [
    { value: 'auto', label: 'Auto-Detect' },
    { value: 'en-IN', label: 'English (IN)' },
    { value: 'hi-IN', label: 'Hindi' },
    { value: 'bn-IN', label: 'Bengali' },
    { value: 'ta-IN', label: 'Tamil' },
    { value: 'te-IN', label: 'Telugu' },
    { value: 'mr-IN', label: 'Marathi' },
    { value: 'kn-IN', label: 'Kannada' },
    { value: 'gu-IN', label: 'Gujarati' },
    { value: 'ml-IN', label: 'Malayalam' },
    { value: 'pa-IN', label: 'Punjabi' },
    { value: 'or-IN', label: 'Odia' },
  ];

  onProviderChange(provider: string) {
    this.selectedProvider = provider;
    this.updateNarratorOptions();
  }

  onLanguageChange(lang: string) {
    this.selectedLanguage = lang;
    this.updateNarratorOptions();
  }

  updateNarratorOptions() {
    const isSarvam = this.selectedProvider === 'SARVAM';
    const lang = this.selectedLanguage;
    
    if (isSarvam && lang && lang !== 'auto') {
      const speakers = getSpeakersForLanguage(lang);
      if (speakers.length > 0) {
        this.narratorOptions.set(speakers);
        this.isSarvamSupported.set(true);
        
        // Auto-switch to default speaker
        const defaultSpeaker = DEFAULT_SPEAKERS[lang] || speakers[0].value;
        this.selectedNarrator.set(defaultSpeaker);
        return;
      }
    }
    
    this.isSarvamSupported.set(false);
    this.narratorOptions.set([]);
    this.selectedNarrator.set('');
  }

  startProgressSimulation() {
    this.transcribeProgress.set(0);
    if (this.progressInterval) {
      clearInterval(this.progressInterval);
    }
    this.progressInterval = setInterval(() => {
      const current = this.transcribeProgress();
      if (current < 90) {
        const increment = Math.max(1, Math.floor((95 - current) / 6));
        this.transcribeProgress.set(current + increment);
      }
    }, 250);
  }

  stopProgressSimulation() {
    if (this.progressInterval) {
      clearInterval(this.progressInterval);
      this.progressInterval = undefined;
    }
    this.transcribeProgress.set(100);
  }

  ngOnInit(): void {
    // Lock provider to Sarvam if only on PRO plan
    if (this.authService.currentPlanType() === 'PRO') {
      this.selectedProvider = 'SARVAM';
    }

    // Initialize narrator options based on defaults
    this.updateNarratorOptions();

    // Set default active tab based on plan entitlement
    if (this.isProPlusOrAbove()) {
      this.activeTab.set('record');
    } else {
      this.activeTab.set('upload');
    }

    // Process autostart query parameter for upgrades
    this.route.queryParams.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(async (params) => {
      const autostart = params['autostart'];
      if (autostart) {
        await this.invokeUpgrade(autostart);

        // Clear params after invoking the upgrade
        this.router.navigate([], {
          relativeTo: this.route,
          queryParams: { autostart: null },
          queryParamsHandling: 'merge',
        });
      }
    });
  }

  async invokeUpgrade(plan: string) {
    if (plan === 'ENTERPRISE') {
      this.router.navigate(['/contact']);
      return;
    }

    const amount =
      plan === 'PRO'
        ? await this.featureFlags.getLiveNumber('PRO_PLAN_PRICE_INR', 499)
        : await this.featureFlags.getLiveNumber('PRO_PLUS_PLAN_PRICE_INR', 1999);

    this.razorpayService.initiatePayment(plan, amount);
  }

  hasAccess(): boolean {
    const plan = this.authService.currentPlanType();
    return ['PRO', 'PRO_PLUS', 'ENTERPRISE'].includes(plan);
  }

  isProviderLocked(): boolean {
    const plan = this.authService.currentPlanType();
    return plan === 'PRO';
  }

  isProPlusOrAbove(): boolean {
    const plan = this.authService.currentPlanType();
    return ['PRO_PLUS', 'ENTERPRISE'].includes(plan);
  }

  selectRecordTab(): void {
    if (!this.isProPlusOrAbove()) {
      this.toast.show('Voice recording is a Pro Plus feature. Please upgrade to unlock.', 'info');
      this.invokeUpgrade('PRO_PLUS');
      return;
    }
    this.activeTab.set('record');
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

  onRecordingStarted(): void {
    this.isRecording.set(true);
    this.result.set(null);
    this.error.set('');
  }

  onRecordingCancelled(): void {
    this.isRecording.set(false);
  }

  onRecordingComplete(blob: Blob): void {
    this.isRecording.set(false);
    this.recordedBlob.set(blob);
    if (this.audioUrl()) {
      window.URL.revokeObjectURL(this.audioUrl()!);
    }
    this.audioUrl.set(window.URL.createObjectURL(blob));
    this.error.set('');
    this.result.set(null);
  }

  discardRecording() {
    if (this.audioUrl()) {
      window.URL.revokeObjectURL(this.audioUrl()!);
      this.audioUrl.set(null);
    }
    this.recordedBlob.set(null);
    this.isPlaying.set(false);
    this.currentTime.set(0);
    this.duration.set(0);
    this.recordedDuration.set(0);
    this.error.set('');
  }

  onRecordingDuration(duration: number): void {
    this.recordedDuration.set(duration);
    this.duration.set(duration);
  }

  togglePlayback(player: HTMLAudioElement): void {
    if (!player) return;
    this.isPlaying() ? player.pause() : player.play();
  }

  onTimeUpdate(player: HTMLAudioElement): void {
    this.currentTime.set(player.currentTime);
    if (player.duration && isFinite(player.duration)) {
      this.duration.set(player.duration);
    } else if (this.recordedDuration() > 0) {
      this.duration.set(this.recordedDuration());
    }
  }

  onLoadedMetadata(player: HTMLAudioElement): void {
    if (player.duration && isFinite(player.duration)) {
      this.duration.set(player.duration);
    } else if (this.recordedDuration() > 0) {
      this.duration.set(this.recordedDuration());
    }
  }

  seekAudio(player: HTMLAudioElement, event: MouseEvent): void {
    const bar = event.currentTarget as HTMLElement;
    if (player) {
      const rect = bar.getBoundingClientRect();
      const clickX = event.clientX - rect.left;
      const totalDuration = (isFinite(player.duration) && player.duration > 0) ? player.duration : this.recordedDuration();
      if (totalDuration > 0) {
        player.currentTime = (clickX / rect.width) * totalDuration;
      }
    }
  }

  formatTime(secs: number): string {
    if (isNaN(secs) || !isFinite(secs)) return '0:00';
    const minutes = Math.floor(secs / 60);
    const seconds = Math.floor(secs % 60);
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  transcribeRecordedAudio() {
    const blob = this.recordedBlob();
    if (!blob) return;

    this.loading.set(true);
    this.startProgressSimulation();
    this.error.set('');
    this.result.set(null);

    this.sttService.transcribeLive(blob, this.selectedLanguage, this.selectedProvider).subscribe({
      next: (res) => {
        this.stopProgressSimulation();
        this.result.set(res);
        this.loading.set(false);
        this.discardRecording();
        this.toast.show('Transcription complete', 'success');
      },
      error: (err) => {
        this.stopProgressSimulation();
        this.loading.set(false);
        if (err.status === 403) {
          this.error.set('Live Voice Recording is restricted to Pro Plus and Enterprise tiers.');
        } else {
          const serverMsg = err.error?.message;
          this.error.set(serverMsg || 'Live voice transcription failed.');
        }
        this.toast.show('Operation failed', 'error');
      },
    });
  }

  onTranscribe() {
    const file = this.selectedFile();
    if (!file) return;

    if (file.size > this.maxFileSize * 1024 * 1024) {
      this.error.set('File is too large. Your plan limit is ' + this.maxFileSize + 'MB.');
      return;
    }

    this.loading.set(true);
    this.startProgressSimulation();
    this.error.set('');
    this.result.set(null);

    this.sttService.transcribe(file, this.selectedLanguage, this.selectedProvider).subscribe({
      next: (res) => {
        this.stopProgressSimulation();
        this.result.set(res);
        this.loading.set(false);
        this.toast.show('Transcription complete', 'success');
      },
      error: (err) => {
        this.stopProgressSimulation();
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
      },
    });
  }

  ngOnDestroy(): void {
    if (this.progressInterval) {
      clearInterval(this.progressInterval);
    }
    if (this.audioUrl()) {
      window.URL.revokeObjectURL(this.audioUrl()!);
    }
  }
}
