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
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-500 opacity-75"></span>
                <span class="relative inline-flex rounded-full h-2 w-2 bg-orange-500"></span>
              </span>
              <span class="text-sm font-medium text-primary-600 dark:text-primary-300">Now with 10+ Indian Regional Languages</span>
            </div>

            <!-- Headline -->
            <h1 class="text-4xl sm:text-5xl md:text-6xl font-bold text-primary-900 dark:text-white tracking-tight leading-[1.1] mb-6 animate-slide-up">
              Transform text into
              <span class="text-transparent bg-clip-text bg-gradient-to-r from-brand-blue to-brand-purple"> lifelike speech</span>
            </h1>

            <!-- Subheadline -->
            <p class="text-lg sm:text-xl text-primary-600 dark:text-primary-400 max-w-2xl mx-auto mb-10 animate-slide-up stagger-1">
              Professional AI voice generation featuring Indian Regional, Natural AI, and Neural voices for creators and businesses.
            </p>

            <!-- CTAs -->
            <div class="flex flex-col sm:flex-row items-center justify-center gap-4 animate-slide-up stagger-2">
              <button (click)="onStartTrial()" class="w-full sm:w-auto px-8 py-3.5 text-base font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-0.5 transition-all flex items-center justify-center gap-2">
                {{ authService.currentUser() ? 'Go to Studio' : 'Start Free Trial' }}
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6"></path></svg>
              </button>
              <a [routerLink]="authService.currentUser() ? '/tts' : '/login'" class="w-full sm:w-auto px-8 py-3.5 text-base font-semibold text-primary-700 dark:text-primary-200 bg-white dark:bg-primary-900 hover:bg-primary-50 dark:hover:bg-primary-800 border border-primary-200 dark:border-primary-700 rounded-xl transition-all flex items-center justify-center gap-2">
                {{ authService.currentUser() ? 'Open App' : 'View Demo' }}
              </a>
            </div>
          </div>
        </div>
      </section>

      <!-- Trust Section -->
      <div class="py-6 sm:py-12 bg-white dark:bg-primary-900 border-y border-primary-100 dark:border-primary-800 transition-colors duration-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-xs sm:text-sm text-primary-400 dark:text-primary-500 mb-4 sm:mb-8 text-center">Trusted by 50,000+ creators worldwide</p>

          <!-- Row 1 - Left to Right -->
          <div class="relative overflow-hidden mb-2 sm:mb-3">
            <div class="flex animate-marquee whitespace-nowrap">
              <div class="flex items-center gap-8 sm:gap-16 px-4 sm:px-8 opacity-30">
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">TechCrunch</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Product Hunt</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Y Combinator</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">The Verge</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Wired</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Forbes</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Fast Company</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Bloomberg</span>
              </div>
              <div class="flex items-center gap-8 sm:gap-16 px-4 sm:px-8 opacity-30">
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">TechCrunch</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Product Hunt</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Y Combinator</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">The Verge</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Wired</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Forbes</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Fast Company</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Bloomberg</span>
              </div>
            </div>
          </div>

          <!-- Row 2 - Right to Left (Reverse) -->
          <div class="relative overflow-hidden mb-2 sm:mb-3">
            <div class="flex animate-marquee-reverse whitespace-nowrap">
              <div class="flex items-center gap-8 sm:gap-16 px-4 sm:px-8 opacity-50">
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Mashable</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">CNET</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">VentureBeat</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Ars Technica</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">PC Magazine</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Inc.</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Business Insider</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">MIT Tech Review</span>
              </div>
              <div class="flex items-center gap-8 sm:gap-16 px-4 sm:px-8 opacity-50">
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Mashable</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">CNET</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">VentureBeat</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Ars Technica</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">PC Magazine</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Inc.</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Business Insider</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">MIT Tech Review</span>
              </div>
            </div>
          </div>

          <!-- Row 3 - Left to Right (Fast) -->
          <div class="relative overflow-hidden">
            <div class="flex animate-marquee-fast whitespace-nowrap">
              <div class="flex items-center gap-8 sm:gap-16 px-4 sm:px-8 opacity-20">
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">The Next Web</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Smashing Magazine</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">CSS-Tricks</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Dev.to</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">HackerNoon</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">G2</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Capterra</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">TrustRadius</span>
              </div>
              <div class="flex items-center gap-8 sm:gap-16 px-4 sm:px-8 opacity-20">
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">The Next Web</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Smashing Magazine</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">CSS-Tricks</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Dev.to</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">HackerNoon</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">G2</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">Capterra</span>
                <span class="text-lg sm:text-xl font-bold text-primary-500 whitespace-nowrap">TrustRadius</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Features Section -->
      <section id="features" class="py-12 sm:py-20 md:py-32 bg-primary-50 dark:bg-primary-950 scroll-mt-16 transition-colors duration-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center max-w-2xl mx-auto mb-8 sm:mb-16">
            <h2 class="text-2xl sm:text-4xl font-bold text-primary-900 dark:text-white mb-4">Everything you need for voice creation</h2>
            <p class="text-sm sm:text-lg text-primary-600 dark:text-primary-400">From podcasts to regional content, create studio-quality voiceovers in minutes.</p>
          </div>
          <div class="grid md:grid-cols-3 gap-6 sm:gap-8">
            <!-- Feature 1: Indian Regional -->
            <div class="group p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 hover:shadow-lg hover:border-orange-500/30 transition-all">
              <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-orange-500 to-amber-400 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5c1.738 0 3.147.162 4.249.448"></path></svg>
              </div>
              <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">Indian Regional Voices</h3>
              <p class="text-primary-500 dark:text-primary-400 text-sm leading-relaxed">Authentic voices for Hindi, Bengali, Tamil, and 7+ regional languages powered by Sarvam AI.</p>
            </div>
            <!-- Feature 2: Natural AI -->
            <div class="group p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 hover:shadow-lg hover:border-brand-blue/30 transition-all">
              <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-brand-blue to-brand-purple flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path></svg>
              </div>
              <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">Natural AI Quality</h3>
              <p class="text-primary-500 dark:text-primary-400 text-sm leading-relaxed">Industry-leading emotional depth and realism for your scripts with ElevenLabs integration.</p>
            </div>
            <!-- Feature 3: Neural Engine -->
            <div class="group p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 hover:shadow-lg hover:border-emerald-500/30 transition-all">
              <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-400 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
              </div>
              <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">High-Speed Neural Engine</h3>
              <p class="text-primary-500 dark:text-primary-400 text-sm leading-relaxed">Generate high-quality global voices in seconds using our optimized AWS Polly neural pipeline.</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Stats Section -->
      <section class="py-10 sm:py-16 bg-brand-blue">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid grid-cols-2 md:grid-cols-4 gap-6 sm:gap-8">
            <div class="text-center"><div class="text-2xl sm:text-4xl font-bold text-white mb-2">300+</div><div class="text-xs sm:text-sm text-white/70">Premium Voices</div></div>
            <div class="text-center"><div class="text-2xl sm:text-4xl font-bold text-white mb-2">30+</div><div class="text-xs sm:text-sm text-white/70">Languages</div></div>
            <div class="text-center"><div class="text-2xl sm:text-4xl font-bold text-white mb-2">50K+</div><div class="text-xs sm:text-sm text-white/70">Active Users</div></div>
            <div class="text-center"><div class="text-2xl sm:text-4xl font-bold text-white mb-2">4.9</div><div class="text-xs sm:text-sm text-white/70">User Rating</div></div>
          </div>
        </div>
      </section>

      <!-- Pricing Section -->
      <section id="pricing" class="pt-12 sm:pt-20 md:pt-32 pb-6 sm:pb-10 bg-primary-50 dark:bg-primary-950 scroll-mt-16 transition-colors duration-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center max-w-2xl mx-auto mb-10 sm:mb-16">
            <h2 class="text-2xl sm:text-4xl font-bold text-primary-900 dark:text-white mb-4">Simple, transparent pricing</h2>
            <p class="text-sm sm:text-lg text-primary-600 dark:text-primary-400">Start free, upgrade when you need more.</p>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 sm:gap-8 max-w-7xl mx-auto">
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
              <button (click)="onStartTrial()" 
                [disabled]="authService.currentPlanType() === 'FREE' && authService.isLoggedIn()"
                [ngClass]="authService.currentPlanType() === 'FREE' && authService.isLoggedIn() ? 'bg-primary-100 dark:bg-primary-800 text-primary-400 cursor-not-allowed opacity-50' : 'bg-primary-900 dark:bg-white text-white dark:text-primary-900 hover:opacity-90 active:scale-95'"
                class="block w-full py-3 text-center font-bold rounded-xl transition-all shadow-lg text-sm uppercase tracking-wider">
                {{ authService.currentPlanType() === 'FREE' && authService.isLoggedIn() ? 'Current Plan' : (authService.currentUser() ? 'Go to App' : 'Get Started') }}
              </button>
            </div>

            <!-- PRO Plan -->
            <div class="p-8 rounded-2xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 flex flex-col transition-all">
              <div class="text-sm font-medium text-orange-500 mb-2">PRO</div>
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
              <button (click)="buyPlan('PRO', proPrice())" 
                [disabled]="authService.currentPlanType() === 'PRO'"
                [ngClass]="authService.currentPlanType() === 'PRO' ? 'bg-primary-100 dark:bg-primary-800 text-primary-400 cursor-not-allowed opacity-50' : 'bg-brand-blue text-white hover:bg-blue-600 shadow-brand-blue/20 active:scale-95'"
                class="block w-full py-3 text-center font-bold rounded-xl shadow-lg transition-all text-sm uppercase tracking-wider">
                {{ authService.currentPlanType() === 'PRO' ? 'Current Plan' : 'Go PRO' }}
              </button>
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
              <button (click)="buyPlan('PRO_PLUS', proPlusPrice())" 
                [disabled]="authService.currentPlanType() === 'PRO_PLUS'"
                [ngClass]="authService.currentPlanType() === 'PRO_PLUS' ? 'bg-primary-100 dark:bg-primary-800 text-primary-400 cursor-not-allowed opacity-50' : 'bg-brand-blue text-white hover:bg-blue-600 shadow-brand-blue/20 active:scale-95'"
                class="block w-full py-3 text-center font-bold rounded-xl shadow-lg transition-all text-sm uppercase tracking-wider">
                {{ authService.currentPlanType() === 'PRO_PLUS' ? 'Current Plan' : 'Go Pro Plus' }}
              </button>
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
              <a [routerLink]="authService.currentPlanType() === 'ENTERPRISE' ? null : '/contact'" 
                [queryParams]="{ topic: 'enterprise' }"
                [ngClass]="authService.currentPlanType() === 'ENTERPRISE' ? 'bg-primary-100 dark:bg-primary-800 text-primary-400 cursor-not-allowed opacity-50 pointer-events-none' : 'bg-primary-900 dark:bg-white text-white dark:text-primary-900 hover:opacity-90 active:scale-95'"
                class="block w-full py-3 text-center font-bold rounded-xl shadow-lg transition-all text-sm uppercase tracking-wider">
                {{ authService.currentPlanType() === 'ENTERPRISE' ? 'Current Plan' : 'Contact Sales' }}
              </a>
            </div>
          </div>
        </div>
      </section>

      <!-- Plan Comparison Table Section -->
      <section id="compare" class="pt-6 sm:pt-10 pb-12 sm:pb-20 bg-primary-50 dark:bg-primary-950 scroll-mt-16 transition-colors duration-300">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-10 sm:mb-16">
            <h2 class="text-2xl sm:text-3xl font-bold text-primary-900 dark:text-white mb-4">Compare Plans</h2>
            <p class="text-primary-700 dark:text-primary-400 text-sm sm:text-base">Find the perfect plan for your voice creation needs.</p>
          </div>

          <div class="overflow-x-auto rounded-2xl border border-primary-200 dark:border-primary-800 shadow-xl bg-white dark:bg-primary-900">
            <table class="w-full text-left border-collapse min-w-[800px]">
              <thead>
                <tr class="bg-primary-50 dark:bg-primary-800/50">
                  <th class="p-6 text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider border-b border-primary-100 dark:border-primary-800">Feature</th>
                  <th class="p-6 text-sm font-bold text-primary-900 dark:text-white uppercase tracking-wider text-center border-b border-primary-100 dark:border-primary-800">Basic (Free)</th>
                  <th class="p-6 text-sm font-bold text-orange-500 uppercase tracking-wider text-center border-b border-primary-100 dark:border-primary-800">PRO</th>
                  <th class="p-6 text-sm font-bold text-brand-blue uppercase tracking-wider text-center border-b border-primary-100 dark:border-primary-800">Pro Plus</th>
                  <th class="p-6 text-sm font-bold text-primary-500 uppercase tracking-wider text-center border-b border-primary-100 dark:border-primary-800">Enterprise</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-primary-100 dark:divide-primary-800">
                <!-- Voice Engines -->
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">Global AWS Voices</td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                </tr>
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">Indian Voices (Sarvam AI)</td>
                  <td class="p-6 text-center"><span class="text-primary-300 dark:text-primary-700">\u2014</span></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                </tr>
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">Natural AI (ElevenLabs)</td>
                  <td class="p-6 text-center"><span class="text-primary-300 dark:text-primary-700">\u2014</span></td>
                  <td class="p-6 text-center"><span class="text-primary-300 dark:text-primary-700">\u2014</span></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                </tr>

                <!-- Limits -->
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">Characters per request</td>
                  <td class="p-6 text-center text-sm font-bold text-primary-600 dark:text-primary-300">{{ freeChars() }}</td>
                  <td class="p-6 text-center text-sm font-bold text-primary-600 dark:text-primary-300">{{ proChars() }}</td>
                  <td class="p-6 text-center text-sm font-bold text-primary-600 dark:text-primary-300">{{ proPlusChars() }}</td>
                  <td class="p-6 text-center text-sm font-bold text-primary-600 dark:text-primary-300">{{ enterpriseChars() }}+</td>
                </tr>
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">Daily syntheses</td>
                  <td class="p-6 text-center text-sm font-bold text-primary-600 dark:text-primary-300">{{ freeDailyLimit() }}</td>
                  <td class="p-6 text-center text-sm font-bold text-emerald-500">Unlimited</td>
                  <td class="p-6 text-center text-sm font-bold text-emerald-500">Unlimited</td>
                  <td class="p-6 text-center text-sm font-bold text-emerald-500">Unlimited</td>
                </tr>

                <!-- Additional Features -->
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">MP3 Downloads</td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                </tr>
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">Support</td>
                  <td class="p-6 text-center text-xs text-primary-500">Community</td>
                  <td class="p-6 text-center text-xs text-primary-500">Standard</td>
                  <td class="p-6 text-center text-xs font-bold text-brand-blue">Priority</td>
                  <td class="p-6 text-center text-xs font-bold text-primary-900 dark:text-white">Dedicated Account Manager</td>
                </tr>
                <tr>
                  <td class="p-6 text-sm font-medium text-primary-700 dark:text-primary-200">API Access</td>
                  <td class="p-6 text-center"><span class="text-primary-300 dark:text-primary-700">\u2014</span></td>
                  <td class="p-6 text-center"><span class="text-primary-300 dark:text-primary-700">\u2014</span></td>
                  <td class="p-6 text-center"><span class="text-primary-300 dark:text-primary-700">\u2014</span></td>
                  <td class="p-6 text-center"><svg class="w-5 h-5 text-emerald-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg></td>
                </tr>
              </tbody>
            </table>
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

  proPrice = computed(() => Number(this.featureFlags.getCached('PRO_PLAN_PRICE_INR', '1')));
  proPlusPrice = computed(() => Number(this.featureFlags.getCached('PRO_PLUS_PLAN_PRICE_INR', '2')));

  // Computed signals for features (Cached Track)
  freeFeatures = computed(() => this.getPlanFeatures('FREE'));
  proFeatures = computed(() => this.getPlanFeatures('PRO'));
  proPlusFeatures = computed(() => this.getPlanFeatures('PRO_PLUS'));
  enterpriseFeatures = computed(() => this.getPlanFeatures('ENTERPRISE'));

  // Computed signals for limits in comparison table
  freeChars = computed(() => this.featureFlags.getCached('MAX_FREE_CHARACTERS', '100'));
  proChars = computed(() => this.featureFlags.getCached('MAX_PRO_CHARACTERS', '200'));
  proPlusChars = computed(() => this.featureFlags.getCached('MAX_PRO_PLUS_CHARACTERS', '500'));
  enterpriseChars = computed(() => this.featureFlags.getCached('MAX_ENTERPRISE_CHARACTERS', '2000'));
  freeDailyLimit = computed(() => this.featureFlags.getCached('FREE_PLAN_SYNTHESIZE_LIMIT', '5'));

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
      'PRO_PLUS_PLAN_PRICE_INR',
      'FREE_PLAN_SYNTHESIZE_LIMIT'
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
