import { Component, OnInit, signal, computed, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TtsService, TtsHistoryDto } from '../../../core/services/tts.service';
import { ToastService } from '../../../core/services/toast.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { getVoiceTypeLabel, getVoiceTypeClass } from '../../../shared';

@Component({
  selector: 'app-chat-history',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12 flex flex-col gap-2 md:gap-8">
        <!-- Page Header -->
        <div class="mb-4 flex items-start justify-between">
          <div>
            <h1 class="text-3xl font-bold text-primary-900 dark:text-white mb-2">Chat History</h1>
            <p class="text-base text-primary-500 dark:text-primary-400">View and manage your past generations</p>
          </div>
          <button routerLink="/tts" 
            class="p-2 rounded-xl text-primary-400 hover:text-primary-600 dark:hover:text-primary-200 hover:bg-white dark:hover:bg-primary-900 border border-transparent hover:border-primary-200 dark:hover:border-primary-700 transition-all group shadow-sm hover:shadow-md"
            title="Back to Studio">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 animate-fade-in">
          <div class="flex items-center gap-3">
            <button *ngIf="history().length > 0"
              (click)="toggleSelectAll()"
              class="px-4 py-2 bg-brand-blue hover:bg-blue-600 text-white text-sm font-bold rounded-xl shadow-lg transition-all active:scale-95 flex items-center gap-2">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path>
              </svg>
              {{ isAllSelected() ? 'Deselect All' : 'Select All' }}
            </button>
            <button *ngIf="selectedIds().size > 0" 
              (click)="deleteSelected()"
              class="px-4 py-2 bg-red-500 hover:bg-red-600 text-white text-sm font-bold rounded-xl shadow-lg transition-all active:scale-95 flex items-center gap-2">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              </svg>
              Delete ({{ selectedIds().size }})
            </button>
            <button *ngIf="history().length > 0"
              (click)="clearAll()"
              class="px-4 py-2 bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 text-primary-600 dark:text-primary-400 text-sm font-bold rounded-xl hover:bg-primary-50 dark:hover:bg-primary-800 transition-all active:scale-95">
              Clear All
            </button>
          </div>
        </div>

        <!-- History Table -->
        <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden animate-slide-up">
          <div class="overflow-x-auto max-h-150 custom-scrollbar">
            <table class="w-full text-left border-separate border-spacing-0">
              <thead class="sticky top-0 z-10">
                <tr class="bg-primary-50/95 dark:bg-primary-800/95 backdrop-blur-sm border-t border-primary-100 dark:border-primary-800">
                  <th class="p-2 sm:p-4 w-10 sm:w-12 border-b border-r border-primary-100 dark:border-primary-800 text-center text-xs font-bold text-primary-500 uppercase">
                    Sel
                  </th>
                  <th class="p-2 sm:p-4 text-[10px] sm:text-xs font-bold text-primary-500 uppercase tracking-wider border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">Voice</th>
                  <th class="p-2 sm:p-4 text-[10px] sm:text-xs font-bold text-primary-500 uppercase tracking-wider border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">Text Snippet</th>
                  <th class="p-2 sm:p-4 text-[10px] sm:text-xs font-bold text-primary-500 uppercase tracking-wider border-b border-r border-primary-100 dark:border-primary-800 text-right whitespace-nowrap">Chars</th>
                  <th class="p-2 sm:p-4 text-[10px] sm:text-xs font-bold text-primary-500 uppercase tracking-wider border-b border-primary-100 dark:border-primary-800 whitespace-nowrap">Date & Time</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let item of history()" 
                  class="hover:bg-primary-50/50 dark:hover:bg-primary-800/30 transition-colors group">
                  <td class="p-2 sm:p-4 border-b border-r border-primary-100 dark:border-primary-800">
                    <input type="checkbox" 
                      [checked]="selectedIds().has(item.id)" 
                      (change)="toggleSelect(item.id)"
                      class="w-4 h-4 rounded border-primary-300 text-brand-blue focus:ring-brand-blue/50">
                  </td>
                  <td class="p-2 sm:p-4 border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">
                    <div class="flex items-center gap-1.5 sm:gap-2">
                      <span class="px-1.5 py-0.5 rounded text-[8px] sm:text-[10px] font-bold uppercase"
                        [ngClass]="getVoiceClass(item)">
                        {{ getVoiceLabel(item) }}
                      </span>
                      <span class="text-xs sm:text-sm text-primary-700 dark:text-primary-200">{{ item.voiceName || item.voiceId }}</span>
                    </div>
                  </td>
                  <td class="p-2 sm:p-4 border-b border-r border-primary-100 dark:border-primary-800 min-w-37.5 max-w-xs">
                    <p class="text-xs sm:text-sm text-primary-600 dark:text-primary-400 truncate italic">
                      "{{ item.textSnippet.length > 15 ? (item.textSnippet | slice:0:15) + '...' : item.textSnippet }}"
                    </p>
                  </td>
                  <td class="p-2 sm:p-4 border-b border-r border-primary-100 dark:border-primary-800 text-right whitespace-nowrap">
                    <span class="text-xs sm:text-sm font-mono text-primary-500">{{ item.characterCount | number }}</span>
                  </td>
                  <td class="p-2 sm:p-4 border-b border-primary-100 dark:border-primary-800 whitespace-nowrap">
                    <div class="flex items-baseline gap-2">
                      <span class="text-xs sm:text-sm font-medium text-primary-900 dark:text-white">{{ item.createdAt | date:'mediumDate' }}</span>
                      <span class="text-[10px] sm:text-xs text-primary-400 font-mono">{{ item.createdAt | date:'shortTime' }}</span>
                    </div>
                  </td>
                </tr>

                <!-- Empty State -->
                <tr *ngIf="history().length === 0 && !loading()">
                  <td colspan="5" class="p-20 text-center">
                    <div class="flex flex-col items-center gap-4">
                      <div class="w-16 h-16 rounded-full bg-primary-100 dark:bg-primary-800 flex items-center justify-center text-primary-400">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                      </div>
                      <div>
                        <h3 class="text-lg font-bold text-primary-900 dark:text-white">No history yet</h3>
                        <p class="text-sm text-primary-500">Generations will appear here once you start using the studio.</p>
                      </div>
                      <button routerLink="/tts" class="mt-2 px-6 py-2 bg-brand-blue text-white font-bold rounded-xl shadow-lg hover:bg-blue-600 transition-all">
                        Go to Studio
                      </button>
                    </div>
                  </td>
                </tr>

                <!-- Loading State -->
                <tr *ngIf="loading()">
                  <td colspan="5" class="p-12 text-center">
                    <div class="flex justify-center">
                      <div class="w-8 h-8 border-4 border-brand-blue border-t-transparent rounded-full animate-spin"></div>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Pagination -->
          <div *ngIf="totalPages() > 1" class="p-4 bg-white dark:bg-primary-900 border-t border-primary-100 dark:border-primary-800 flex items-center justify-between">
            <span class="text-xs text-primary-500 dark:text-primary-400 font-medium">
              Showing {{ history().length }} of {{ totalElements() }} entries
            </span>
            <div class="flex items-center gap-2">
              <button (click)="changePage(currentPage() - 1)" [disabled]="currentPage() === 0"
                class="p-2 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 disabled:opacity-30 transition-colors text-primary-600 dark:text-primary-300">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path></svg>
              </button>
              <span class="text-sm font-bold text-primary-700 dark:text-primary-200">{{ currentPage() + 1 }} / {{ totalPages() }}</span>
              <button (click)="changePage(currentPage() + 1)" [disabled]="currentPage() >= totalPages() - 1"
                class="p-2 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 disabled:opacity-30 transition-colors text-primary-600 dark:text-primary-300">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    :host { display: block; }
    .line-clamp-1 {
      display: -webkit-box;
      -webkit-line-clamp: 1;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
  `]
})
export class ChatHistoryComponent implements OnInit {
  private ttsService = inject(TtsService);
  private toast = inject(ToastService);

  history = signal<TtsHistoryDto[]>([]);
  loading = signal(false);
  
  currentPage = signal(0);
  totalPages = signal(0);
  totalElements = signal(0);
  pageSize = 15;

  selectedIds = signal<Set<number>>(new Set());

  isAllSelected = computed(() => {
    const currentHistory = this.history();
    return currentHistory.length > 0 && currentHistory.every(item => this.selectedIds().has(item.id));
  });

  ngOnInit(): void {
    this.loadHistory();
  }

  getVoiceLabel(item: TtsHistoryDto): string {
    const filter = item.voiceType === 'NATURAL' ? 'Natural' : (item.voiceType === 'NEURAL' ? 'Neural' : 'Standard');
    const mockVoice: any = { isElevenLabs: item.voiceType === 'NATURAL', isNeural: item.voiceType === 'NEURAL' };
    return getVoiceTypeLabel(mockVoice, filter);
  }

  getVoiceClass(item: TtsHistoryDto): string {
    const filter = item.voiceType === 'NATURAL' ? 'Natural' : (item.voiceType === 'NEURAL' ? 'Neural' : 'Standard');
    const mockVoice: any = { isElevenLabs: item.voiceType === 'NATURAL', isNeural: item.voiceType === 'NEURAL' };
    return getVoiceTypeClass(mockVoice, filter);
  }

  loadHistory(): void {
    this.loading.set(true);
    this.ttsService.getHistory(this.currentPage(), this.pageSize).subscribe({
      next: (res) => {
        this.history.set(res._embedded?.ttsHistoryDtoList || []);
        this.totalPages.set(res.page.totalPages);
        this.totalElements.set(res.page.totalElements);
        this.loading.set(false);
      },
      error: () => {
        this.toast.show('Failed to load history', 'error');
        this.loading.set(false);
      }
    });
  }

  changePage(page: number): void {
    this.currentPage.set(page);
    this.loadHistory();
    this.selectedIds.set(new Set()); // Reset selection on page change
  }

  toggleSelect(id: number): void {
    this.selectedIds.update(set => {
      const newSet = new Set(set);
      if (newSet.has(id)) newSet.delete(id);
      else newSet.add(id);
      return newSet;
    });
  }

  toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.selectedIds.set(new Set());
    } else {
      const ids = this.history().map(item => item.id);
      this.selectedIds.set(new Set(ids));
    }
  }

  deleteSelected(): void {
    const ids = Array.from(this.selectedIds());
    if (ids.length === 0) return;

    if (confirm(`Are you sure you want to delete ${ids.length} selected entries?`)) {
      this.ttsService.deleteHistoryEntries(ids).subscribe({
        next: () => {
          this.toast.show(`Deleted ${ids.length} entries`, 'success');
          this.selectedIds.set(new Set());
          this.loadHistory();
        },
        error: () => this.toast.show('Failed to delete entries', 'error')
      });
    }
  }

  clearAll(): void {
    if (confirm('Are you sure you want to clear your entire history? This cannot be undone.')) {
      this.ttsService.clearAllHistory().subscribe({
        next: () => {
          this.toast.show('History cleared successfully', 'success');
          this.history.set([]);
          this.totalElements.set(0);
          this.totalPages.set(0);
          this.selectedIds.set(new Set());
        },
        error: () => this.toast.show('Failed to clear history', 'error')
      });
    }
  }
}
