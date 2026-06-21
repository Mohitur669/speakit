import { Component, Output, EventEmitter, signal } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-upload-area',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div
      (dragover)="onDragOver($event)"
      (dragleave)="onDragLeave($event)"
      (drop)="onDrop($event)"
      [class.border-brand-blue]="isDragging()"
      [class.bg-brand-blue/5]="isDragging()"
      class="relative group cursor-pointer border-2 border-dashed border-primary-300 dark:border-primary-700 rounded-2xl p-12 text-center transition-all hover:border-brand-blue hover:bg-primary-50 dark:hover:bg-primary-800/30"
    >
      <input
        type="file"
        (change)="onFileSelected($event)"
        accept=".mp3,.wav,.m4a,.ogg"
        class="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
        #fileInput
      />

      <div class="flex flex-col items-center gap-4">
        <div
          class="w-16 h-16 rounded-full bg-primary-100 dark:bg-primary-800 flex items-center justify-center text-primary-400 group-hover:text-brand-blue transition-colors"
        >
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
            ></path>
          </svg>
        </div>

        @if (!selectedFile()) {
          <div>
            <h3 class="text-lg font-bold text-primary-900 dark:text-white mb-1">
              Drag and drop audio file
            </h3>
            <p class="text-sm text-primary-500">or click to browse from computer</p>
          </div>
        } @else {
          <div>
            <h3 class="text-lg font-bold text-brand-blue mb-1">{{ selectedFile()?.name }}</h3>
            <p class="text-sm text-primary-500">
              {{ (selectedFile()?.size || 0) / 1024 / 1024 | number: '1.1-2' }} MB
            </p>
          </div>
        }

        <div class="mt-4 flex flex-wrap justify-center gap-2">
          @for (fmt of ['MP3', 'WAV', 'M4A', 'OGG']; track fmt) {
            <span
              class="px-2.5 py-1 text-[10px] font-bold rounded-lg bg-primary-100 dark:bg-primary-800 text-primary-600 dark:text-primary-400"
            >
              {{ fmt }}
            </span>
          }
        </div>
      </div>
    </div>
  `,
})
export class UploadAreaComponent {
  @Output() fileChange = new EventEmitter<File>();

  isDragging = signal(false);
  selectedFile = signal<File | null>(null);

  onDragOver(event: DragEvent) {
    event.preventDefault();
    event.stopPropagation();
    this.isDragging.set(true);
  }

  onDragLeave(event: DragEvent) {
    event.preventDefault();
    event.stopPropagation();
    this.isDragging.set(false);
  }

  onDrop(event: DragEvent) {
    event.preventDefault();
    event.stopPropagation();
    this.isDragging.set(false);

    const files = event.dataTransfer?.files;
    if (files && files.length > 0) {
      this.handleFile(files[0]);
    }
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.handleFile(input.files[0]);
    }
  }

  private handleFile(file: File) {
    this.selectedFile.set(file);
    this.fileChange.emit(file);
  }
}
