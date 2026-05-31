/**
 * Landing page component displaying marketing content,
 * feature highlights, pricing, and trust indicators.
 */
import { Component, inject, OnInit, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, Router } from '@angular/router';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../shared/components/footer/footer.component';
import { RazorpayService } from '../../../core/services/razorpay.service';
import { AuthService } from '../../../core/auth/auth.service';
import { FeatureFlagService } from '../../../core/services/feature-flag.service';

@Component({
  selector: 'app-landing',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 transition-colors duration-300">
      <app-navbar></app-navbar>

      <!-- Hero Section -->
      <section id="home" class="relative pt-16 md:pt-24 pb-20 md:pb-32 overflow-hidden scroll-mt-16">
        <div class="absolute inset-0 bg-gradient-to-b from-primary-100/50 dark:from-primary-900/50 to-transparent -z-10"></div>
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[600px] bg-brand-blue/5 dark:bg-brand-blue/10 rounded-full blur-[120px] -z-10"></div>

        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center max-w-3xl mx-auto">
            <!-- Badge -->
            <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-800 shadow-sm mb-8 animate-fade-in">
              <span class="relative flex h-2 w-2">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent-500 opacity-75"></span>
                <span class="relative inline-flex rounded-full h-2 w-2 bg-accent-500"></span>
              </span>
              <span class="text-sm font-medium text-primary-600 dark:text-primary-300">Now with Neural Voice Engine</span>
            </div>

            <!-- Headline -->
            <h1 class="text-4xl sm:text-5xl md:text-6xl font-bold text-primary-900 dark:text-white tracking-tight leading-[1.1] mb-6 animate-slide-up">
              Transform text into
              <span class="text-transparent bg-clip-text bg-gradient-to-r from-brand-blue to-brand-purple"> natural speech</span>
            </h1>

            <!-- Subheadline -->
            <p class="text-lg sm:text-xl text-primary-500 dark:text-primary-400 max-w-2xl mx-auto mb-10 animate-slide-up stagger-1">
              Professional AI voice generation for content creators, developers, and businesses.
            </p>

            <!-- CTAs -->
            <div class="flex flex-col sm:flex-row items-center justify-center gap-4 animate-slide-up stagger-2">
              <button (click)="onStartTrial()" class="w-full sm:w-auto px-8 py-3.5 text-base font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-0.5 transition-all flex items-center justify-center gap-2">
                {{ authService.currentUser() ? 'Go to Dashboard' : 'Start Free Trial' }}
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6"></path></svg>
              </button>
              <a [routerLink]="authService.currentUser() ? '/tts' : '/login'" class="w-full sm:w-auto px-8 py-3.5 text-base font-semibold text-primary-700 dark:text-primary-200 bg-white dark:bg-primary-900 hover:bg-primary-100 dark:hover:bg-primary-800 border border-primary-200 dark:border-primary-700 rounded-xl transition-all flex items-center justify-center gap-2">
                {{ authService.currentUser() ? 'Open App' : 'View Demo' }}
              </a>
            </div>
          </div>
        </div>
      </section>

      <!-- Trust Section -->
      <div class="py-12 bg-white dark:bg-primary-900 border-y border-primary-100 dark:border-primary-800 transition-colors duration-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-sm text-primary-400 dark:text-primary-500 mb-8 text-center">Trusted by 50,000+ creators worldwide</p>

          <!-- Row 1 - Left to Right -->
          <div class="relative overflow-hidden mb-3">
            <div class="flex animate-marquee whitespace-nowrap">
              <div class="flex items-center gap-16 px-8 opacity-30">
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">TechCrunch</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Product Hunt</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Y Combinator</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">The Verge</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Wired</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Forbes</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Fast Company</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Bloomberg</span>
              </div>
              <div class="flex items-center gap-16 px-8 opacity-30">
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">TechCrunch</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Product Hunt</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Y Combinator</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">The Verge</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Wired</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Forbes</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Fast Company</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Bloomberg</span>
              </div>
            </div>
          </div>

          <!-- Row 2 - Right to Left (Reverse) -->
          <div class="relative overflow-hidden mb-3">
            <div class="flex animate-marquee-reverse whitespace-nowrap">
              <div class="flex items-center gap-16 px-8 opacity-50">
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Mashable</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">CNET</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">VentureBeat</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Ars Technica</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">PC Magazine</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Inc.</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Business Insider</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">MIT Tech Review</span>
              </div>
              <div class="flex items-center gap-16 px-8 opacity-50">
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Mashable</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">CNET</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">VentureBeat</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Ars Technica</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">PC Magazine</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Inc.</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Business Insider</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">MIT Tech Review</span>
              </div>
            </div>
          </div>

          <!-- Row 3 - Left to Right (Fast) -->
          <div class="relative overflow-hidden">
            <div class="flex animate-marquee-fast whitespace-nowrap">
              <div class="flex items-center gap-16 px-8 opacity-20">
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">The Next Web</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Smashing Magazine</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">CSS-Tricks</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Dev.to</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">HackerNoon</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">G2</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Capterra</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">TrustRadius</span>
              </div>
              <div class="flex items-center gap-16 px-8 opacity-20">
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">The Next Web</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Smashing Magazine</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">CSS-Tricks</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Dev.to</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">HackerNoon</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">G2</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">Capterra</span>
                <span class="text-xl font-bold text-primary-500 whitespace-nowrap">TrustRadius</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Features Section -->
      <section id="features" class="py-20 md:py-32 bg-primary-50 dark:bg-primary-950 scroll-mt-16 transition-colors duration-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center max-w-2xl mx-auto mb-16">
            <h2 class="text-3xl sm:text-4xl font-bold text-primary-900 dark:text-white mb-4">Everything you need for voice creation</h2>
            <p class="text-lg text-primary-500 dark:text-primary-400">From podcasts to audiobooks, create studio-quality voiceovers in minutes.</p>
          </div>
          <div class="grid md:grid-cols-3 gap-8">
            <div class="group p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 hover:shadow-lg hover:border-brand-blue/30 transition-all">
              <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path></svg>
              </div>
              <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">300+ Natural Voices</h3>
              <p class="text-primary-500 dark:text-primary-400">Access a vast library of lifelike voices across 30+ languages and accents.</p>
            </div>
            <div class="group p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 hover:shadow-lg hover:border-accent-500/30 transition-all">
              <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-accent-500 to-emerald-400 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
              </div>
              <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">Lightning Fast</h3>
              <p class="text-primary-500 dark:text-primary-400">Generate high-quality audio in seconds with our optimized neural engine.</p>
            </div>
            <div class="group p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 hover:shadow-lg hover:border-purple-500/30 transition-all">
              <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
              </div>
              <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">MP3 Export</h3>
              <p class="text-primary-500 dark:text-primary-400">Download your audio in industry-standard MP3 format.</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Stats Section -->
      <section class="py-16 bg-brand-blue">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid grid-cols-2 md:grid-cols-4 gap-8">
            <div class="text-center"><div class="text-3xl sm:text-4xl font-bold text-white mb-2">300+</div><div class="text-sm text-white/70">Premium Voices</div></div>
            <div class="text-center"><div class="text-3xl sm:text-4xl font-bold text-white mb-2">30+</div><div class="text-sm text-white/70">Languages</div></div>
            <div class="text-center"><div class="text-3xl sm:text-4xl font-bold text-white mb-2">50K+</div><div class="text-sm text-white/70">Active Users</div></div>
            <div class="text-center"><div class="text-3xl sm:text-4xl font-bold text-white mb-2">4.9</div><div class="text-sm text-white/70">User Rating</div></div>
          </div>
        </div>
      </section>

      <!-- Pricing Section -->
      <section id="pricing" class="py-20 md:py-32 bg-primary-50 dark:bg-primary-950 scroll-mt-16 transition-colors duration-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center max-w-2xl mx-auto mb-16">
            <h2 class="text-3xl sm:text-4xl font-bold text-primary-900 dark:text-white mb-4">Simple, transparent pricing</h2>
            <p class="text-lg text-primary-500 dark:text-primary-400">Start free, upgrade when you need more.</p>
          </div>
          <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-8 max-w-7xl mx-auto">
            <!-- Free Plan -->
            <div class="p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 flex flex-col transition-all">
              <div class="text-sm font-medium text-primary-500 mb-2">Basic</div>
              <div class="flex items-baseline gap-1 mb-6">
                <span class="text-4xl font-bold text-primary-900 dark:text-white">Free</span>
              </div>
              <ul class="space-y-4 mb-8 flex-grow text-left">
                <li *ngFor="let feature of freeFeatures()" class="flex items-center gap-3 text-primary-600 dark:text-primary-300">
                  <svg class="w-5 h-5 text-accent-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                  {{ feature }}
                </li>
              </ul>
              <button (click)="onStartTrial()" class="block w-full py-3 text-center font-semibold text-primary-700 dark:text-primary-200 bg-primary-100 dark:bg-primary-800 hover:bg-primary-200 dark:hover:bg-primary-700 rounded-xl transition-all">
                {{ authService.currentUser() ? 'Go to App' : 'Get Started' }}
              </button>
            </div>

            <!-- Pro Plan -->
            <div class="p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 flex flex-col transition-all">
              <div class="text-sm font-medium text-brand-blue mb-2">Pro</div>
              <div class="flex items-baseline gap-1 mb-6">
                <span class="text-4xl font-bold text-primary-900 dark:text-white">₹{{ proPrice() }}</span>
                <span class="text-primary-400">/mo</span>
              </div>
              <ul class="space-y-4 mb-8 flex-grow text-left">
                <li *ngFor="let feature of proFeatures()" class="flex items-center gap-3 text-primary-600 dark:text-primary-300">
                  <svg class="w-5 h-5 text-accent-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                  {{ feature }}
                </li>
              </ul>
              <button (click)="buyPlan('PRO', proPrice())" class="block w-full py-3 text-center font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 rounded-xl shadow-lg transition-all">Upgrade to Pro</button>
            </div>

            <!-- Pro Plus Plan -->
            <div class="relative p-8 rounded-2xl bg-white dark:bg-primary-900 border-2 border-brand-blue flex flex-col transform lg:scale-105 shadow-xl transition-all">
              <div class="absolute -top-4 left-1/2 -translate-x-1/2 px-4 py-1 bg-brand-blue text-white text-sm font-semibold rounded-full shadow-lg">Recommended</div>
              <div class="text-sm font-medium text-brand-blue mb-2">Pro Plus</div>
              <div class="flex items-baseline gap-1 mb-6">
                <span class="text-4xl font-bold text-primary-900 dark:text-white">₹{{ proPlusPrice() }}</span>
                <span class="text-primary-400">/mo</span>
              </div>
              <ul class="space-y-4 mb-8 flex-grow text-left">
                <li *ngFor="let feature of proPlusFeatures()" class="flex items-center gap-3 text-primary-600 dark:text-primary-300">
                  <svg class="w-5 h-5 text-accent-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                  {{ feature }}
                </li>
              </ul>
              <button (click)="buyPlan('PRO_PLUS', proPlusPrice())" class="block w-full py-3 text-center font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 rounded-xl shadow-lg transition-all">Go Pro Plus</button>
            </div>

            <!-- Enterprise Plan -->
            <div class="p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 flex flex-col transition-all">
              <div class="text-sm font-medium text-primary-500 mb-2">Enterprise</div>
              <div class="flex items-baseline gap-1 mb-6">
                <span class="text-4xl font-bold text-primary-900 dark:text-white">Custom</span>
              </div>
              <ul class="space-y-4 mb-8 flex-grow text-left">
                <li *ngFor="let feature of enterpriseFeatures()" class="flex items-center gap-3 text-primary-600 dark:text-primary-300">
                  <svg class="w-5 h-5 text-accent-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                  {{ feature }}
                </li>
              </ul>
              <a routerLink="/contact" class="block w-full py-3 text-center font-semibold text-primary-700 dark:text-primary-200 bg-primary-100 dark:bg-primary-800 hover:bg-primary-200 dark:hover:bg-primary-700 rounded-xl transition-all">Contact Sales</a>
            </div>
          </div>
        </div>
      </section>

      <app-footer></app-footer>
    </div>
  `
})
export class LandingComponent implements OnInit {
  private razorpay = inject(RazorpayService);
  private router = inject(Router);
  authService = inject(AuthService);
  featureFlags = inject(FeatureFlagService);

  proPrice = computed(() => Number(this.featureFlags.getCached('PRO_PLAN_PRICE_INR', '499')));
  proPlusPrice = computed(() => Number(this.featureFlags.getCached('PRO_PLUS_PLAN_PRICE_INR', '1999')));

  // Computed signals for features (Cached Track)
  freeFeatures = computed(() => this.getPlanFeatures('FREE'));
  proFeatures = computed(() => this.getPlanFeatures('PRO'));
  proPlusFeatures = computed(() => this.getPlanFeatures('PRO_PLUS'));
  enterpriseFeatures = computed(() => this.getPlanFeatures('ENTERPRISE'));

  private getPlanFeatures(plan: string): string[] {
    const raw = this.featureFlags.getCached(`${plan}_PLAN_FEATURES`, '');
    return raw ? raw.split(';').map(f => f.trim()).filter(f => f) : [];
  }

  async ngOnInit() {
    // Combine everything into ONE batch request for maximum speed
    // Computed signals will auto-update when this finishes
    await this.featureFlags.init([
      'MAX_FREE_CHARACTERS', 
      'MAX_PRO_CHARACTERS', 
      'MAX_PRO_PLUS_CHARACTERS',
      'ENABLE_RAZORPAY',
      'FREE_PLAN_FEATURES',
      'PRO_PLAN_FEATURES',
      'PRO_PLUS_PLAN_FEATURES',
      'ENTERPRISE_PLAN_FEATURES',
      'PRO_PLAN_PRICE_INR',
      'PRO_PLUS_PLAN_PRICE_INR'
    ]);
  }

  buyPlan(plan: string, amount: number) {
    if (this.authService.isLoggedIn()) {
      this.razorpay.initiatePayment(plan, amount);
    } else {
      this.router.navigate(['/signup'], { queryParams: { plan } });
    }
  }

  onStartTrial() {
    if (this.authService.isLoggedIn()) {
      this.router.navigate(['/tts']);
    } else {
      this.router.navigate(['/signup']);
    }
  }
}
