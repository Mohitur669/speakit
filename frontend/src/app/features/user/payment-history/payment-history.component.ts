import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { RazorpayService, PaymentHistoryDto } from '../../../core/services/razorpay.service';
import { ToastService } from '../../../core/services/toast.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';

@Component({
  selector: 'app-payment-history',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12 flex flex-col gap-2 md:gap-8">
        <!-- Page Header -->
        <div class="mb-4 flex items-start justify-between">
          <div>
            <h1 class="text-3xl font-bold text-primary-900 dark:text-white mb-2">Payment History</h1>
            <p class="text-base text-primary-500 dark:text-primary-400">View your past subscription payments</p>
          </div>
          <button routerLink="/tts" 
            class="p-2 rounded-xl text-primary-400 hover:text-primary-600 dark:hover:text-primary-200 hover:bg-white dark:hover:bg-primary-900 border border-transparent hover:border-primary-200 dark:hover:border-primary-700 transition-all group shadow-sm hover:shadow-md shrink-0"
            title="Back to Studio">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <!-- History Table -->
        <div class="bg-white dark:bg-primary-900 rounded-xl border border-primary-200 dark:border-primary-700 shadow-xl overflow-hidden animate-slide-up">
          <div class="overflow-x-auto max-h-150 custom-scrollbar">
            <table class="w-full text-left border-separate border-spacing-0">
              <thead class="sticky top-0 z-10">
                <tr class="bg-primary-50/95 dark:bg-primary-800/95 backdrop-blur-sm border-t border-primary-100 dark:border-primary-800">
                  <th class="px-4 py-4 text-[10px] sm:text-xs font-bold text-primary-500 tracking-wider border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">Plan</th>
                  <th class="px-4 py-4 text-[10px] sm:text-xs font-bold text-primary-500 tracking-wider border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">Amount</th>
                  <th class="px-4 py-4 text-[10px] sm:text-xs font-bold text-primary-500 tracking-wider border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">Status</th>
                  <th class="px-4 py-4 text-[10px] sm:text-xs font-bold text-primary-500 tracking-wider border-b border-primary-100 dark:border-primary-800 whitespace-nowrap">Date & Time</th>
                </tr>
              </thead>
              <tbody>
                <ng-container *ngIf="!loading(); else skeletonLoader">
                  <tr *ngFor="let item of history()" 
                    class="hover:bg-primary-50/50 dark:hover:bg-primary-800/30 transition-colors group">
                    <td class="px-4 py-2.5 md:py-5 border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">
                      <span class="text-xs sm:text-sm font-bold text-brand-blue">{{ item.planName === 'FREE' ? 'Basic' : item.planName.replace('_', ' ') }}</span>
                    </td>
                    <td class="px-4 py-2.5 md:py-5 border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">
                      <span class="text-xs sm:text-sm font-medium text-primary-900 dark:text-white">{{ item.amount | currency:item.currency:'symbol':'1.2-2' }}</span>
                    </td>
                    <td class="px-4 py-2.5 md:py-5 border-b border-r border-primary-100 dark:border-primary-800 whitespace-nowrap">
                      <span class="px-2 py-1 rounded text-[10px] sm:text-xs font-bold capitalize"
                        [ngClass]="{
                          'bg-green-500/10 text-green-600': item.status === 'SUCCESS' || item.status === 'CAPTURED',
                          'bg-red-500/10 text-red-600': item.status === 'FAILED',
                          'bg-yellow-500/10 text-yellow-600': item.status === 'PENDING' || item.status === 'CREATED' || item.status === 'INITIATED'
                        }">
                        {{ item.status.toLowerCase() }}
                      </span>
                    </td>
                    <td class="px-4 py-2.5 md:py-5 border-b border-primary-100 dark:border-primary-800 whitespace-nowrap">
                      <div class="flex items-baseline gap-2">
                        <span class="text-xs sm:text-sm font-medium text-primary-900 dark:text-white">{{ item.createdAt | date:'mediumDate' }}</span>
                        <span class="text-[10px] sm:text-xs text-primary-400 font-mono">{{ item.createdAt | date:'shortTime' }}</span>
                      </div>
                    </td>
                  </tr>

                  <!-- Empty State -->
                  <tr *ngIf="history().length === 0">
                    <td colspan="4" class="p-20 text-center">
                      <div class="flex flex-col items-center gap-4">
                        <div class="w-16 h-16 rounded-full bg-primary-100 dark:bg-primary-800 flex items-center justify-center text-primary-400">
                          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                          </svg>
                        </div>
                        <div>
                          <h3 class="text-lg font-bold text-primary-900 dark:text-white">No payments yet</h3>
                          <p class="text-sm text-primary-500">Your subscription payments will appear here.</p>
                        </div>
                      </div>
                    </td>
                  </tr>
                </ng-container>

                <!-- Skeleton Loader -->
                <ng-template #skeletonLoader>
                  <tr *ngFor="let i of [1,2,3,4,5]" class="animate-pulse">
                    <td class="px-4 py-5 border-b border-r border-primary-100 dark:border-primary-800">
                      <div class="w-20 h-4 bg-primary-200 dark:bg-primary-700 rounded"></div>
                    </td>
                    <td class="px-4 py-5 border-b border-r border-primary-100 dark:border-primary-800">
                      <div class="w-16 h-4 bg-primary-100 dark:bg-primary-800 rounded"></div>
                    </td>
                    <td class="px-4 py-5 border-b border-r border-primary-100 dark:border-primary-800">
                      <div class="w-12 h-4 bg-primary-100 dark:bg-primary-800 rounded"></div>
                    </td>
                    <td class="px-4 py-5 border-b border-primary-100 dark:border-primary-800">
                      <div class="w-32 h-4 bg-primary-100 dark:bg-primary-800 rounded"></div>
                    </td>
                  </tr>
                </ng-template>
              </tbody>
            </table>
          </div>

          <!-- Pagination -->
          <div *ngIf="totalPages() > 1" class="py-2 px-4 bg-white dark:bg-primary-900 border-t border-primary-100 dark:border-primary-800 flex items-center justify-between">
            <span class="text-xs text-primary-500 dark:text-primary-400 font-medium">
              Showing {{ history().length }} of {{ totalElements() }} entries
            </span>
            <div class="flex items-center gap-2">
              <button (click)="changePage(currentPage() - 1)" [disabled]="currentPage() === 0 || loading()"
                class="p-2 rounded-lg hover:bg-primary-100 dark:hover:bg-primary-800 disabled:opacity-30 transition-colors text-primary-600 dark:text-primary-300">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path></svg>
              </button>
              <span class="text-sm font-bold text-primary-700 dark:text-primary-200">{{ currentPage() + 1 }} / {{ totalPages() }}</span>
              <button (click)="changePage(currentPage() + 1)" [disabled]="currentPage() >= totalPages() - 1 || loading()"
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
  `]
})
export class PaymentHistoryComponent implements OnInit {
  private razorpayService = inject(RazorpayService);
  private toast = inject(ToastService);

  history = signal<PaymentHistoryDto[]>([]);
  loading = signal(false);
  
  currentPage = signal(0);
  totalPages = signal(0);
  totalElements = signal(0);
  pageSize = 5;

  ngOnInit(): void {
    this.loadHistory();
  }

  loadHistory(): void {
    this.loading.set(true);
    this.razorpayService.getPaymentHistory(this.currentPage(), this.pageSize).subscribe({
      next: (res) => {
        this.history.set(res.content || []);
        this.totalPages.set(res.page.totalPages);
        this.totalElements.set(res.page.totalElements);
        this.loading.set(false);
      },
      error: () => {
        this.toast.show('Failed to load payment history', 'error');
        this.loading.set(false);
      }
    });
  }

  changePage(page: number): void {
    this.currentPage.set(page);
    this.loadHistory();
  }
}
