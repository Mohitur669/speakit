import { Component, OnInit, signal, computed, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, Router, ActivatedRoute } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';
import { RazorpayService } from '../../../core/services/razorpay.service';
import { FeatureFlagService } from '../../../core/services/feature-flag.service';
import { ToastService } from '../../../core/services/toast.service';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { ConfirmModalComponent } from '../../../shared/components/confirm-modal/confirm-modal.component';

@Component({
  selector: 'app-manage-plan',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent, ConfirmModalComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950">
      <app-navbar></app-navbar>

      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12 flex flex-col gap-6">
        <!-- Header -->
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-3xl font-bold text-primary-900 dark:text-white mb-2">
              Billing & Plans
            </h1>
            <p class="text-base text-primary-500 dark:text-primary-400">
              Manage your subscription tier, upgrade with Razorpay, or view quotas.
            </p>
          </div>
          <button
            routerLink="/tts"
            class="p-2 -mt-2 rounded-xl text-primary-400 hover:text-primary-600 dark:hover:text-primary-200 hover:bg-white dark:hover:bg-primary-900 border border-transparent hover:border-primary-200 dark:hover:border-primary-700 transition-all group shadow-sm hover:shadow-md shrink-0"
            title="Back to Studio"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <!-- Navigation Tabs -->
        <div class="flex border-b border-primary-200 dark:border-primary-800 gap-6">
          <a
            routerLink="/settings/plan"
            class="pb-3 text-sm font-bold border-b-2 border-brand-blue text-brand-blue transition-colors"
          >
            Plan & Tiers
          </a>
          <a
            routerLink="/settings/payments"
            class="pb-3 text-sm font-medium text-primary-500 hover:text-primary-800 dark:text-primary-400 dark:hover:text-white transition-colors"
          >
            Payment History
          </a>
        </div>

        <!-- Current Active Plan Card -->
        <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 p-6 shadow-sm">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <div class="flex items-center gap-3">
                <span class="text-xs font-bold uppercase tracking-wider text-primary-400">Current Plan</span>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-brand-blue/10 text-brand-blue border border-brand-blue/20">
                  {{ currentPlan() }}
                </span>
              </div>
              <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-1">
                {{ planDisplayName(currentPlan()) }} Plan
              </h2>
              <p class="text-sm text-primary-500 dark:text-primary-400 mt-1">
                {{ planDescription(currentPlan()) }}
              </p>
            </div>

            @if (currentPlan() !== 'FREE') {
              <button
                (click)="showDowngradeModal.set(true)"
                class="self-start sm:self-center px-4 py-2 text-xs font-semibold text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/30 rounded-xl border border-red-200 dark:border-red-900/50 transition-all"
              >
                Downgrade to Free Tier
              </button>
            }
          </div>
        </div>

        <!-- Plan Comparison & Upgrade Grid -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 pt-2">
          <!-- Free Tier -->
          <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 p-6 flex flex-col justify-between shadow-sm relative">
            <div>
              <h3 class="text-lg font-bold text-primary-900 dark:text-white">Free</h3>
              <div class="mt-4 flex items-baseline gap-1">
                <span class="text-3xl font-extrabold text-primary-900 dark:text-white">₹0</span>
                <span class="text-xs text-primary-500 dark:text-primary-400">/ forever</span>
              </div>
              <p class="text-xs text-primary-500 dark:text-primary-400 mt-2">Essential AI speech synthesis for testing.</p>
              
              <ul class="mt-6 space-y-3 text-xs text-primary-600 dark:text-primary-300">
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-emerald-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span><strong>100</strong> chars per synthesis request</span>
                </li>
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-emerald-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span><strong>3,000</strong> monthly character quota</span>
                </li>
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-emerald-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span>5 daily syntheses • Standard Polly</span>
                </li>
              </ul>
            </div>

            <div class="mt-8">
              @if (currentPlan() === 'FREE') {
                <div class="w-full py-2.5 px-4 text-center rounded-xl bg-primary-100 dark:bg-primary-800 text-primary-500 text-xs font-bold">
                  Current Active Plan
                </div>
              } @else {
                <button
                  (click)="showDowngradeModal.set(true)"
                  class="w-full py-2.5 px-4 text-center rounded-xl border border-primary-200 dark:border-primary-700 hover:bg-primary-50 dark:hover:bg-primary-800 text-primary-700 dark:text-primary-200 text-xs font-bold transition-all"
                >
                  Downgrade to Free
                </button>
              }
            </div>
          </div>

          <!-- Pro Tier -->
          <div class="bg-white dark:bg-primary-900 rounded-2xl border-2 border-brand-blue/30 dark:border-brand-blue/50 p-6 flex flex-col justify-between shadow-sm relative">
            <div>
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-bold text-primary-900 dark:text-white">Pro</h3>
                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-brand-blue/10 text-brand-blue">CREATOR</span>
              </div>
              <div class="mt-4 flex items-baseline gap-1">
                <span class="text-3xl font-extrabold text-primary-900 dark:text-white">₹{{ proPrice() }}</span>
                <span class="text-xs text-primary-500 dark:text-primary-400">/ month</span>
              </div>
              <p class="text-xs text-primary-500 dark:text-primary-400 mt-2">Enhanced limits, Neural AI voices, and STT.</p>
              
              <ul class="mt-6 space-y-3 text-xs text-primary-600 dark:text-primary-300">
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-brand-blue shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span><strong>200</strong> chars per synthesis request</span>
                </li>
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-brand-blue shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span><strong>5,000</strong> monthly character quota</span>
                </li>
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-brand-blue shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span>Neural Polly AI Voices • File STT</span>
                </li>
              </ul>
            </div>

            <div class="mt-8">
              @if (currentPlan() === 'PRO') {
                <div class="w-full py-2.5 px-4 text-center rounded-xl bg-brand-blue/10 text-brand-blue text-xs font-bold border border-brand-blue/30">
                  Current Active Plan
                </div>
              } @else if (currentPlan() === 'PRO_PLUS') {
                <button
                  (click)="upgradeTo('PRO', proPrice())"
                  class="w-full py-2.5 px-4 text-center rounded-xl border border-primary-200 dark:border-primary-700 hover:bg-primary-50 dark:hover:bg-primary-800 text-primary-700 dark:text-primary-200 text-xs font-bold transition-all"
                >
                  Downgrade to Pro
                </button>
              } @else {
                <button
                  (click)="upgradeTo('PRO', proPrice())"
                  class="w-full py-2.5 px-4 text-center rounded-xl bg-brand-blue hover:bg-blue-600 text-white text-xs font-bold transition-all shadow-md active:scale-[0.98]"
                >
                  Upgrade to Pro • ₹{{ proPrice() }}
                </button>
              }
            </div>
          </div>

          <!-- Pro Plus Tier -->
          <div class="bg-white dark:bg-primary-900 rounded-2xl border-2 border-accent-500 p-6 flex flex-col justify-between shadow-lg relative">
            <div class="absolute -top-3 right-6 px-2.5 py-0.5 rounded-full text-[10px] font-extrabold bg-accent-500 text-white shadow-sm">
              MOST POPULAR
            </div>

            <div>
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-bold text-primary-900 dark:text-white">Pro Plus</h3>
              </div>
              <div class="mt-4 flex items-baseline gap-1">
                <span class="text-3xl font-extrabold text-primary-900 dark:text-white">₹{{ proPlusPrice() }}</span>
                <span class="text-xs text-primary-500 dark:text-primary-400">/ month</span>
              </div>
              <p class="text-xs text-primary-500 dark:text-primary-400 mt-2">ElevenLabs Indian AI voices & Live Mic STT.</p>
              
              <ul class="mt-6 space-y-3 text-xs text-primary-600 dark:text-primary-300">
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-accent-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span><strong>500</strong> chars per synthesis request</span>
                </li>
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-accent-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span><strong>10,000</strong> monthly character quota</span>
                </li>
                <li class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-accent-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                  <span>ElevenLabs & Indian Voices • Live Mic STT</span>
                </li>
              </ul>
            </div>

            <div class="mt-8">
              @if (currentPlan() === 'PRO_PLUS') {
                <div class="w-full py-2.5 px-4 text-center rounded-xl bg-accent-500/10 text-accent-500 text-xs font-bold border border-accent-500/30">
                  Current Active Plan
                </div>
              } @else {
                <button
                  (click)="upgradeTo('PRO_PLUS', proPlusPrice())"
                  class="w-full py-2.5 px-4 text-center rounded-xl bg-accent-500 hover:bg-accent-600 text-white text-xs font-bold transition-all shadow-md active:scale-[0.98]"
                >
                  Upgrade to Pro Plus • ₹{{ proPlusPrice() }}
                </button>
              }
            </div>
          </div>
        </div>

        <!-- Trust & Security Banner -->
        <div class="mt-2 p-4 bg-primary-100/60 dark:bg-primary-900/60 rounded-xl border border-primary-200 dark:border-primary-800 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-primary-500 dark:text-primary-400">
          <div class="flex items-center gap-2">
            <svg class="w-4 h-4 text-emerald-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
            <span>Secured by 256-Bit SSL Encryption via Razorpay Payment Gateway</span>
          </div>
          <div class="flex items-center gap-3 font-semibold text-primary-600 dark:text-primary-300">
            <span>UPI</span>
            <span>•</span>
            <span>Credit/Debit Cards</span>
            <span>•</span>
            <span>Net Banking</span>
          </div>
        </div>
      </div>

      <!-- Downgrade Confirmation Modal -->
      @if (showDowngradeModal()) {
        <app-confirm-modal
          title="Downgrade to Free Tier?"
          message="Are you sure you want to downgrade? You will lose access to neural voices and Indian regional voices at the end of the current billing cycle."
          confirmText="Yes, Downgrade"
          cancelText="Keep Plan"
          [isDanger]="true"
          (confirm)="executeDowngrade()"
          (cancelled)="showDowngradeModal.set(false)"
        ></app-confirm-modal>
      }
    </div>
  `
})
export class ManagePlanComponent implements OnInit {
  private authService = inject(AuthService);
  private razorpayService = inject(RazorpayService);
  private featureFlags = inject(FeatureFlagService);
  private toast = inject(ToastService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  currentPlan = computed(() => this.authService.currentPlanType());
  proPrice = signal<number>(1);
  proPlusPrice = signal<number>(2);
  showDowngradeModal = signal<boolean>(false);
  isSubmitting = signal<boolean>(false);

  async ngOnInit(): Promise<void> {
    await this.loadPricing();
    // Auto-trigger payment if iOS redirected with ?plan= query param
    const planParam = this.route.snapshot.queryParams['plan'] || '';
    if (planParam) {
      await this.handlePlanFromQueryParam(planParam);
    }
  }

  /**
   * Handles the ?plan= query param passed from the iOS app's "Manage on Web" redirect.
   * Automatically initiates the correct upgrade or downgrade flow so the user
   * doesn't have to manually tap again after login.
   */
  private async handlePlanFromQueryParam(plan: string): Promise<void> {
    const normalized = plan.toUpperCase();
    if (normalized === 'PRO') {
      await this.upgradeTo('PRO', this.proPrice());
    } else if (normalized === 'PRO_PLUS') {
      await this.upgradeTo('PRO_PLUS', this.proPlusPrice());
    } else if (normalized === 'FREE') {
      // Show downgrade confirmation modal instead of immediately downgrading
      this.showDowngradeModal.set(true);
    }
  }

  private async loadPricing(): Promise<void> {
    try {
      const pro = await this.featureFlags.getLiveNumber('PRO_PLAN_PRICE_INR', 1);
      const proPlus = await this.featureFlags.getLiveNumber('PRO_PLUS_PLAN_PRICE_INR', 2);
      this.proPrice.set(pro);
      this.proPlusPrice.set(proPlus);
    } catch {
      this.proPrice.set(1);
      this.proPlusPrice.set(2);
    }
  }


  planDisplayName(plan: string): string {
    switch (plan) {
      case 'PRO': return 'Pro';
      case 'PRO_PLUS': return 'Pro Plus';
      case 'ENTERPRISE': return 'Enterprise';
      default: return 'Free';
    }
  }

  planDescription(plan: string): string {
    switch (plan) {
      case 'PRO': return 'Includes Neural Polly voices and 5,000 monthly character quota.';
      case 'PRO_PLUS': return 'Includes ElevenLabs & Sarvam Indian regional AI voices and 10,000 monthly quota.';
      case 'ENTERPRISE': return 'Custom limits, dedicated SLA, and priority API access.';
      default: return 'Standard voices with 3,000 characters per month quota.';
    }
  }

  async upgradeTo(plan: string, amount: number): Promise<void> {
    await this.razorpayService.initiatePayment(plan, amount);
  }

  async executeDowngrade(): Promise<void> {
    this.showDowngradeModal.set(false);
    this.isSubmitting.set(true);
    try {
      await firstValueFrom(this.razorpayService.downgradeToFree());
      await firstValueFrom(this.authService.refreshStatus());
      this.toast.show('Plan successfully downgraded to Free tier.', 'info');
    } catch {
      this.toast.show('Failed to downgrade plan. Please try again.', 'error');
    } finally {
      this.isSubmitting.set(false);
    }
  }
}
