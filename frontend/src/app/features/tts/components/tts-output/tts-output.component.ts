import {
  Component,
  Input,
  Output,
  EventEmitter,
  signal,
  ViewChild,
  ElementRef,
} from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-tts-output',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div
      class="bg-white dark:bg-primary-900 rounded-xl border border-primary-300 dark:border-primary-700 overflow-hidden"
    >
      <div class="px-6 py-4 border-b border-primary-200 dark:border-primary-800">
        <h2 class="text-lg sm:text-sm font-semibold text-primary-900 dark:text-white">
          Generated Audio
        </h2>
      </div>
      <div class="p-6">
        <div class="flex flex-col sm:flex-row items-center justify-between gap-6 w-full">
          <div class="flex items-center gap-4 w-full sm:flex-1">
            <button
              (click)="togglePlayPause()"
              class="w-14 h-14 rounded-full bg-gradient-to-br from-brand-blue to-brand-purple text-white flex items-center justify-center hover:scale-105 hover:shadow-xl hover:shadow-brand-blue/30 active:scale-95 transition-all shadow-lg shrink-0"
            >
              @if (!isPlaying) {
                <svg class="w-6 h-6 ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
              }
              @if (isPlaying) {
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
                </svg>
              }
            </button>

            <div class="flex-1 w-full">
              <div class="flex justify-between text-xs text-primary-400 mb-2">
                <span>{{ currentTime | number: '1.1-1' }}s</span>
                <span>{{ duration | number: '1.1-1' }}s</span>
              </div>
              <div
                class="h-2 bg-primary-100 dark:bg-primary-800 rounded-full cursor-pointer overflow-hidden group"
                (click)="seekAudio($event)"
              >
                <div
                  class="h-full bg-brand-blue rounded-full group-hover:shadow-lg group-hover:shadow-brand-blue/30"
                  [style.width.%]="progressPercent"
                ></div>
              </div>
            </div>
          </div>

          <button
            (click)="download.emit()"
            class="flex items-center justify-center gap-2 w-full sm:w-40 h-12 rounded-xl font-semibold text-sm text-white bg-accent-500 hover:bg-accent-600 transition-all shadow-lg hover:shadow-xl hover:-translate-y-0.5 active:scale-95 shrink-0"
          >
            <svg class="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
              ></path>
            </svg>
            <span class="whitespace-nowrap">Download</span>
          </button>
        </div>
      </div>
      <audio
        #audioPlayer
        [src]="audioUrl"
        (timeupdate)="onTimeUpdate($event)"
        (play)="isPlaying = true"
        (pause)="isPlaying = false"
        (ended)="isPlaying = false"
      ></audio>
    </div>
  `,
})
export class TtsOutputComponent {
  @Input() audioUrl: string | null = null;
  @Output() download = new EventEmitter<void>();

  @ViewChild('audioPlayer') audioPlayerRef!: ElementRef<HTMLAudioElement>;

  isPlaying = false;
  currentTime = 0;
  duration = 0;

  get progressPercent(): number {
    return this.duration ? (this.currentTime / this.duration) * 100 : 0;
  }

  onTimeUpdate(event: Event): void {
    const audio = event.target as HTMLAudioElement;
    this.currentTime = audio.currentTime;
    this.duration = audio.duration || 0;
  }

  togglePlayPause(): void {
    const audio = this.audioPlayerRef.nativeElement;
    if (!audio) return;
    this.isPlaying ? audio.pause() : audio.play();
  }

  seekAudio(event: MouseEvent): void {
    const bar = event.currentTarget as HTMLElement;
    const audio = this.audioPlayerRef.nativeElement;
    if (audio && audio.duration) {
      audio.currentTime = (event.offsetX / bar.clientWidth) * audio.duration;
    }
  }
}
