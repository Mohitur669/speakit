import { Component, OnInit, ElementRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TtsService, Voice } from '../services/tts';

@Component({
  selector: 'app-tts',
  standalone: true,
  imports: [CommonModule, FormsModule],
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

  currentTime = 0;
  duration = 0;

  constructor(private ttsService: TtsService) {}

  ngOnInit(): void {
    this.ttsService.getVoices().subscribe({
      next: (voices) => this.voices = voices,
      error: () => this.error = 'Failed to load voices'
    });
  }

  convert(): void {
    if (!this.text.trim()) return;
    this.loading = true;
    this.error = '';
    this.audioUrl = null;

    this.ttsService.synthesize(this.text, this.selectedVoice).subscribe({
      next: (blob) => {
        this.audioUrl = URL.createObjectURL(blob);
        this.loading = false;
        setTimeout(() => this.audioPlayerRef?.nativeElement.play(), 100);
      },
      error: () => {
        this.error = 'Conversion failed. Please try again.';
        this.loading = false;
      }
    });
  }

  download(): void {
    if (!this.audioUrl) return;
    const a = document.createElement('a');
    a.href = this.audioUrl;
    a.download = 'speech.mp3';
    a.click();
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
}