import { Component, EventEmitter, Output, signal, ViewChild, ElementRef, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-audio-recorder',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flex flex-col items-center justify-center p-8 bg-primary-50/50 dark:bg-primary-900/20 border-2 border-dashed border-primary-300 dark:border-primary-700/80 rounded-2xl transition-all">
      @if (status() === 'inactive') {
        <!-- Idle State -->
        <button
          type="button"
          (click)="startRecording()"
          class="w-20 h-20 rounded-full bg-brand-blue hover:bg-blue-600 text-white flex items-center justify-center shadow-xl hover:shadow-brand-blue/30 active:scale-95 transition-all group relative"
        >
          <span class="absolute inset-0 rounded-full bg-brand-blue/20 animate-ping group-hover:duration-75"></span>
          <svg class="w-10 h-10 relative z-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z M19 10v1a7 7 0 01-14 0v-1 M12 18v4 M8 22h8"
            ></path>
          </svg>
        </button>
        <p class="mt-4 text-sm font-semibold text-primary-700 dark:text-primary-300">Click to record voice</p>
        <p class="text-xs text-primary-500 dark:text-primary-400 mt-1">Supports up to 10 minutes</p>
      } @else {
        <!-- Recording / Paused State -->
        <div class="w-full max-w-sm flex flex-col items-center">
          <!-- Visualizer Canvas -->
          <canvas #visualizer class="w-full h-24 bg-primary-100/50 dark:bg-primary-800/40 rounded-xl mb-6 border border-primary-200 dark:border-primary-700/50"></canvas>

          <!-- Timer -->
          <div class="text-3xl font-mono font-bold text-primary-800 dark:text-primary-100 mb-6 flex items-center gap-2">
            <span class="w-3.5 h-3.5 rounded-full bg-red-500" [class.animate-pulse]="status() === 'recording'"></span>
            {{ formatTime(secondsElapsed()) }}
          </div>

          <!-- Controls -->
          <div class="flex items-center justify-center gap-6">
            <!-- Cancel Button -->
            <button
              type="button"
              (click)="cancelRecording()"
              class="w-12 h-12 rounded-xl bg-primary-200 dark:bg-primary-800 hover:bg-primary-300 dark:hover:bg-primary-700 text-primary-700 dark:text-primary-200 flex items-center justify-center transition-all active:scale-95"
              title="Cancel Recording"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>

            <!-- Pause / Resume Button -->
            <button
              type="button"
              (click)="togglePause()"
              class="w-16 h-16 rounded-full bg-primary-100 hover:bg-primary-200 dark:bg-primary-800 dark:hover:bg-primary-700 text-brand-blue flex items-center justify-center shadow-lg transition-all active:scale-95"
              [title]="status() === 'recording' ? 'Pause' : 'Resume'"
            >
              @if (status() === 'recording') {
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>
                </svg>
              } @else {
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z"/>
                </svg>
              }
            </button>

            <!-- Stop & Save Button -->
            <button
              type="button"
              (click)="stopRecording()"
              class="w-12 h-12 rounded-xl bg-red-500 hover:bg-red-600 text-white flex items-center justify-center transition-all active:scale-95 shadow-md shadow-red-500/20"
              title="Stop and Save"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M6 6h12v12H6z"/>
              </svg>
            </button>
          </div>
        </div>
      }

      @if (permissionError()) {
        <p class="mt-4 text-xs text-red-500 dark:text-red-400 font-medium text-center animate-fade-in">
          {{ permissionError() }}
        </p>
      }
    </div>
  `
})
export class AudioRecorderComponent implements OnDestroy {
  @Output() recordingComplete = new EventEmitter<Blob>();
  @Output() recordingStarted = new EventEmitter<void>();
  @Output() recordingCancelled = new EventEmitter<void>();
  @Output() recordingDuration = new EventEmitter<number>();

  @ViewChild('visualizer') private canvasRef?: ElementRef<HTMLCanvasElement>;

  status = signal<'inactive' | 'recording' | 'paused'>('inactive');
  secondsElapsed = signal(0);
  permissionError = signal('');

  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];
  private timerInterval?: any;
  private maxDurationSeconds = 600; // 10 minutes limit

  // Web Audio Visualizer state
  private audioCtx?: AudioContext;
  private analyser?: AnalyserNode;
  private source?: MediaStreamAudioSourceNode;
  private animationFrameId?: number;
  private mediaStream?: MediaStream;

  startRecording(): void {
    this.permissionError.set('');
    this.audioChunks = [];
    this.secondsElapsed.set(0);

    navigator.mediaDevices.getUserMedia({ audio: true })
      .then(stream => {
        this.mediaStream = stream;
        this.recordingStarted.emit();

        // Detect supported MIME type
        let options = { mimeType: 'audio/webm;codecs=opus' };
        if (!MediaRecorder.isTypeSupported(options.mimeType)) {
          options = { mimeType: 'audio/webm' };
        }
        if (!MediaRecorder.isTypeSupported(options.mimeType)) {
          options = { mimeType: 'audio/mp4' }; // Fallback for iOS/Safari
        }

        try {
          this.mediaRecorder = new MediaRecorder(stream, options);
        } catch (e) {
          // Native fallback fallback
          this.mediaRecorder = new MediaRecorder(stream);
        }

        this.mediaRecorder.ondataavailable = (event) => {
          if (event.data.size > 0) {
            this.audioChunks.push(event.data);
          }
        };

        this.mediaRecorder.onstop = () => {
          const mimeType = this.mediaRecorder?.mimeType || 'audio/webm';
          const audioBlob = new Blob(this.audioChunks, { type: mimeType });
          
          this.cleanupStream();
          this.status.set('inactive');
          
          if (audioBlob.size > 0 && this.secondsElapsed() > 0) {
            this.recordingDuration.emit(this.secondsElapsed());
            this.recordingComplete.emit(audioBlob);
          }
          this.secondsElapsed.set(0);
        };

        this.mediaRecorder.start(250); // Collect data slices every 250ms
        this.status.set('recording');
        this.startTimer();
        this.initVisualizer(stream);
      })
      .catch(err => {
        console.error('Microphone access denied:', err);
        this.permissionError.set('Microphone access denied. Please enable permission in your browser settings.');
      });
  }

  togglePause(): void {
    if (!this.mediaRecorder) return;

    if (this.status() === 'recording') {
      this.mediaRecorder.pause();
      this.status.set('paused');
      this.stopTimerInterval();
    } else if (this.status() === 'paused') {
      this.mediaRecorder.resume();
      this.status.set('recording');
      this.startTimer();
    }
  }

  stopRecording(): void {
    if (this.mediaRecorder && this.status() !== 'inactive') {
      this.mediaRecorder.stop();
      this.stopTimerInterval();
    }
  }

  cancelRecording(): void {
    if (this.mediaRecorder && this.status() !== 'inactive') {
      // Discard callbacks
      this.mediaRecorder.onstop = null;
      this.mediaRecorder.stop();
    }
    this.cleanupStream();
    this.status.set('inactive');
    this.stopTimerInterval();
    this.secondsElapsed.set(0);
    this.recordingCancelled.emit();
  }

  formatTime(totalSeconds: number): string {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  private startTimer(): void {
    this.stopTimerInterval();
    this.timerInterval = setInterval(() => {
      const val = this.secondsElapsed() + 1;
      this.secondsElapsed.set(val);
      if (val >= this.maxDurationSeconds) {
        this.stopRecording();
      }
    }, 1000);
  }

  private stopTimerInterval(): void {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = undefined;
    }
  }

  private initVisualizer(stream: MediaStream): void {
    try {
      this.audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
      this.analyser = this.audioCtx.createAnalyser();
      this.analyser.fftSize = 256;
      this.source = this.audioCtx.createMediaStreamSource(stream);
      this.source.connect(this.analyser);

      const bufferLength = this.analyser.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);

      setTimeout(() => this.drawVisualizer(dataArray, bufferLength), 0);
    } catch (e) {
      console.warn('Web Audio API not supported or failed to initialize', e);
    }
  }

  private drawVisualizer(dataArray: any, bufferLength: number): void {
    if (!this.canvasRef || !this.analyser) return;

    const canvas = this.canvasRef.nativeElement;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const draw = () => {
      if (this.status() === 'inactive') return;
      this.animationFrameId = requestAnimationFrame(draw);

      this.analyser!.getByteFrequencyData(dataArray);

      const width = canvas.width = canvas.offsetWidth;
      const height = canvas.height = canvas.offsetHeight;

      ctx.clearRect(0, 0, width, height);

      // Display 45 slim bars stretched across the full width, mapping to the active vocal bins (first 20)
      const displayBins = 45;
      const barWidth = width / displayBins;
      const activeBinsCount = 20;

      for (let i = 0; i < displayBins; i++) {
        const activeIndex = Math.floor((i / displayBins) * activeBinsCount);
        const value = this.status() === 'paused' ? 5 : dataArray[activeIndex];
        const percent = value / 255;
        const barHeight = Math.max(3, height * percent * 0.85);

        // Solid theme color matching application branding (brand-blue)
        ctx.fillStyle = '#3b82f6';
        ctx.fillRect(i * barWidth, height - barHeight, Math.max(2, barWidth - 3.5), barHeight);
      }
    };

    draw();
  }

  private cleanupStream(): void {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }
    if (this.source) {
      this.source.disconnect();
    }
    if (this.audioCtx && this.audioCtx.state !== 'closed') {
      this.audioCtx.close();
    }
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
      this.mediaStream = undefined;
    }
  }

  ngOnDestroy(): void {
    this.cleanupStream();
    this.stopTimerInterval();
  }
}
