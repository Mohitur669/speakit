import { Component, OnInit, ElementRef, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TtsService, Voice } from '../services/tts';
import { AuthService } from '../services/auth';
import { ThemeService } from '../services/theme';
import { ToastComponent } from '../components/toast.component';
import { NavbarComponent } from '../components/navbar.component';

@Component({
  selector: 'app-tts',
  standalone: true,
  imports: [CommonModule, FormsModule, ToastComponent, NavbarComponent],
  templateUrl: './tts.html',
  styleUrls: ['./tts.scss']
})
export class TtsComponent implements OnInit {
  @ViewChild('audioPlayer') audioPlayerRef!: ElementRef<HTMLAudioElement>;

  ttsService = inject(TtsService);
  authService = inject(AuthService);
  themeService = inject(ThemeService);

  text = '';
  selectedEngine: 'standard' | 'neural' = 'standard';
  selectedVoice = '';
  voices: Voice[] = [];
  filteredVoices: Voice[] = [];
  audioUrl: string | null = null;
  loading = false;
  error = '';
  isPlaying = false;
  
  toastMessage = '';
  toastType: 'success' | 'error' = 'success';
  showToast = false;

  currentTime = 0;
  duration = 0;

  ngOnInit(): void {
    this.refreshVoices();
  }

  refreshVoices(): void {
    this.ttsService.getVoices().subscribe({
      next: (voices) => {
        this.voices = voices;
        
        // Auto-engine selection logic
        const hasNeuralVoices = voices.some(v => v.isNeural === true);
        if (hasNeuralVoices) {
            this.selectedEngine = 'neural';
        } else {
            this.selectedEngine = 'standard';
        }

        this.filterByEngine();
      },
      error: () => this.error = 'Failed to load studio voices. Please refresh.'
    });
  }

  filterByEngine(): void {
    const isNeuralRequest = this.selectedEngine === 'neural';
    
    this.filteredVoices = this.voices.filter(v => {
      // Force boolean check for reliability
      const supportsNeural = v.isNeural === true || (v as any).isNeural === 'true';
      const supportsStandard = v.isStandard === true || (v as any).isStandard === 'true';
      
      return isNeuralRequest ? supportsNeural : supportsStandard;
    });

    if (this.filteredVoices.length > 0) {
      const currentExists = this.filteredVoices.find(v => v.id === this.selectedVoice);
      if (!currentExists) {
        this.selectedVoice = this.filteredVoices[0].id;
      }
    } else {
      this.selectedVoice = '';
    }
  }

  setEngine(engine: 'standard' | 'neural'): void {
    const hasNeuralSupport = this.voices.some(v => v.isNeural === true || (v as any).isNeural === 'true');
    
    if (engine === 'neural' && !hasNeuralSupport) {
      this.showNotification('⚠️ Neural Engine requires Premium Access', 'error');
      return;
    }
    
    this.selectedEngine = engine;
    this.filterByEngine();
  }

  convert(): void {
    if (!this.text.trim() || !this.selectedVoice) return;

    this.loading = true;
    this.error = '';

    if (this.audioUrl) {
      URL.revokeObjectURL(this.audioUrl);
      this.audioUrl = null;
    }

    this.ttsService.synthesize(this.text, this.selectedVoice).subscribe({
      next: (blob) => {
        const mimeType = blob.type || 'audio/mpeg';
        const audioBlob = new Blob([blob], { type: mimeType });
        this.audioUrl = URL.createObjectURL(audioBlob);
        this.loading = false;
        this.showNotification('✓ Master generated successfully');
      },
      error: (err) => {
        this.loading = false;
        this.error = 'Synthesis failed. Please try a different voice.';
      }
    });
  }

  download(): void {
    if (!this.audioUrl) return;
    const a = document.createElement('a');
    a.href = this.audioUrl;
    a.download = `speakit-export-${Date.now()}.mp3`;
    a.click();
    this.showNotification('✓ Exporting MP3...');
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

  showNotification(message: string, type: 'success' | 'error' = 'success'): void {
    this.toastMessage = message;
    this.toastType = type;
    this.showToast = true;
    setTimeout(() => {
      this.showToast = false;
    }, 3000);
  }
}
