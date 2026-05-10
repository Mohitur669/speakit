import { Component, OnInit, ElementRef, ViewChild, inject, HostListener } from '@angular/core';
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
  currentFilter: 'All' | 'Standard' | 'Neural' = 'All';
  selectedVoiceId = '';
  voices: Voice[] = [];
  filteredVoices: Voice[] = [];
  
  isDropdownOpen = false;
  audioUrl: string | null = null;
  loading = false;
  error = '';
  isPlaying = false;
  
  toastMessage = '';
  toastType: 'success' | 'error' = 'success';
  showToast = false;

  currentTime = 0;
  duration = 0;

  @HostListener('document:click')
  onDocumentClick() {
    this.isDropdownOpen = false;
  }

  ngOnInit(): void {
    this.refreshVoices();
  }

  public checkAccess(val: any): boolean {
    return val === true || val === 'true';
  }

  get userCanUseNeural(): boolean {
    return this.authService.hasNaturalAccess();
  }

  refreshVoices(): void {
    this.ttsService.getVoices().subscribe({
      next: (voices) => {
        this.voices = voices;
        this.currentFilter = this.userCanUseNeural ? 'All' : 'Standard';
        this.applyFilter();
        
        if (this.filteredVoices.length > 0 && !this.selectedVoiceId) {
          this.selectedVoiceId = this.filteredVoices[0].id;
        }
      },
      error: () => this.error = 'Failed to load studio voices.'
    });
  }

  applyFilter(): void {
    switch (this.currentFilter) {
      case 'Standard':
        this.filteredVoices = this.voices.filter(v => v.isStandard === true);
        break;
      case 'Neural':
        this.filteredVoices = this.voices.filter(v => v.isNeural === true);
        break;
      case 'All':
      default:
        this.filteredVoices = [...this.voices];
        break;
    }

    if (this.filteredVoices.length > 0) {
      const currentExists = this.filteredVoices.find(v => v.id === this.selectedVoiceId);
      if (!currentExists) {
        this.selectedVoiceId = this.filteredVoices[0].id;
      }
    } else {
      this.selectedVoiceId = '';
    }
  }

  setFilter(filter: 'All' | 'Standard' | 'Neural'): void {
    if (filter === 'Neural' && !this.userCanUseNeural) {
      this.showNotification('⚡ Neural voices require a Pro plan', 'error');
      return;
    }
    this.currentFilter = filter;
    this.applyFilter();
  }

  voiceBadge(voice: Voice): string {
    if (voice.isNeural && voice.isStandard) return 'Standard + Neural';
    if (voice.isNeural) return 'Neural';
    if (voice.isStandard) return 'Standard';
    return '';
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
    this.loading = true;
    this.error = '';

    if (this.audioUrl) {
      URL.revokeObjectURL(this.audioUrl);
      this.audioUrl = null;
    }

    this.ttsService.synthesize(this.text, this.selectedVoiceId).subscribe({
      next: (blob) => {
        const audioBlob = new Blob([blob], { type: blob.type || 'audio/mpeg' });
        this.audioUrl = URL.createObjectURL(audioBlob);
        this.loading = false;
        this.showNotification('✓ Render Successful');
      },
      error: (err) => {
        this.loading = false;
        this.error = 'Synthesis failed.';
      }
    });
  }

  download(): void {
    if (!this.audioUrl) return;
    const a = document.createElement('a');
    a.href = this.audioUrl;
    a.download = `speakit-master-${Date.now()}.mp3`;
    a.click();
    this.showNotification('✓ Download Started');
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
    this.toastMessage = message;
    this.toastType = type;
    this.showToast = true;
    setTimeout(() => {
      this.showToast = false;
    }, 3000);
  }
}
