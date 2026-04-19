import { Component, OnInit, ElementRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TtsService, Voice } from '../services/tts';
import { ToastComponent } from '../components/toast.component';

@Component({
  selector: 'app-tts',
  standalone: true,
  imports: [CommonModule, FormsModule, ToastComponent],
  templateUrl: './tts.html',
  styleUrls: ['./tts.scss']
})
export class TtsComponent implements OnInit {
  @ViewChild('audioPlayer') audioPlayerRef!: ElementRef<HTMLAudioElement>;

  text = '';
  selectedVoice = 'Joanna';
  voices: Voice[] = [];
  audioUrl: string | null = null;
  loading = false;
  error = '';
  isPlaying = false;
  isDarkMode = true;
  toastMessage = '';
  toastType: 'success' | 'error' = 'success';
  showToast = false;

  currentTime = 0;
  duration = 0;

  constructor(private ttsService: TtsService) {}

  ngOnInit(): void {
    this.ttsService.getVoices().subscribe({
      next: (voices) => this.voices = voices,
      error: () => this.error = 'Failed to load voices'
    });
    // Initialize dark mode state from localStorage or system preference
    const isDark = localStorage['theme'] === 'dark' || (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches);
    this.isDarkMode = isDark;
  }

  convert(): void {
    if (!this.text.trim()) return;

    this.loading = true;
    this.error = '';

    // Clean previous audio URL (prevents memory leak)
    if (this.audioUrl) {
      URL.revokeObjectURL(this.audioUrl);
      this.audioUrl = null;
    }

    this.ttsService.synthesize(this.text, this.selectedVoice).subscribe({
      next: (blob) => {

        // ✅ Detect correct mime type (important for ogg/mp3 switching)
        const mimeType = blob.type || 'audio/mpeg';
        const audioBlob = new Blob([blob], { type: mimeType });

        this.audioUrl = URL.createObjectURL(audioBlob);

        this.loading = false;
        this.showNotification('✓ Conversion successful!');
      },

      error: (err) => {
        this.loading = false;

        // If backend sends structured JSON error
        if (err.error?.type === 'TTS_ERROR') {
          this.error = err.error.message;
          return;
        }

        // Fallback for blob/plain-text errors (streaming case)
        if (err.error instanceof Blob) {
          err.error.text().then((text: string) => {
            this.error = text || 'Conversion failed. Try another voice.';
          });
        } else {
          this.error = 'Conversion failed. Try another voice.';
        }
      }
    });
  }

  download(): void {
    if (!this.audioUrl) return;
    const a = document.createElement('a');
    a.href = this.audioUrl;
    a.download = 'speech.mp3';
    a.click();
    this.showNotification('✓ File downloaded successfully!');
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
    const ratio = event.offsetX / bar.clientWidth;
    const audio = this.audioPlayerRef?.nativeElement;
    if (audio && audio.duration) {
      audio.currentTime = ratio * audio.duration;
    }
  }

  togglePlayPause(): void {
    const audio = this.audioPlayerRef?.nativeElement;
    if (!audio) return;

    if (this.isPlaying) {
      audio.pause();
    } else {
      audio.play();
    }
    this.isPlaying = !this.isPlaying;
  }

  toggleDarkMode(): void {
    this.isDarkMode = !this.isDarkMode;
    if (this.isDarkMode) {
      document.documentElement.classList.add('dark');
      localStorage['theme'] = 'dark';
    } else {
      document.documentElement.classList.remove('dark');
      localStorage['theme'] = 'light';
    }
  }

  showNotification(message: string, type: 'success' | 'error' = 'success'): void {
    this.toastMessage = message;
    this.toastType = type;
    this.showToast = true;
    setTimeout(() => {
      this.showToast = false;
    }, 3000);
  }
}
