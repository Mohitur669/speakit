import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NavbarComponent } from '../components/navbar.component';

@Component({
  selector: 'app-landing',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-screen bg-white dark:bg-[#0a0e1a] transition-colors duration-500 overflow-x-hidden relative font-body">
      <app-navbar></app-navbar>

      <!-- Ultra-Premium Hero Section -->
      <main class="relative pt-12 md:pt-24 pb-32">
        
        <!-- Subtle Ambient Background -->
        <div class="absolute inset-0 overflow-hidden pointer-events-none -z-10">
          <div class="absolute -top-[10%] -right-[10%] w-[70vw] h-[70vw] bg-amber-500/10 dark:bg-amber-500/5 rounded-full blur-[120px] animate-pulse"></div>
          <div class="absolute -bottom-[10%] -left-[10%] w-[60vw] h-[60vw] bg-indigo-500/10 dark:bg-indigo-500/5 rounded-full blur-[120px] animate-pulse" style="animation-delay: 2s"></div>
        </div>

        <div class="w-full px-6 sm:px-12 lg:px-24">
          <div class="max-w-screen-2xl mx-auto text-center">
            
            <!-- Floating Badge -->
            <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-slate-900 dark:bg-white text-white dark:text-slate-900 text-[10px] md:text-xs font-black uppercase tracking-[0.2em] mb-10 animate-fade-in shadow-2xl">
              <span class="flex h-2 w-2 relative">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
                <span class="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
              </span>
              Neural Engine 3.0 Available Now
            </div>

            <!-- Dynamic Heading with Letter Stagger Animation -->
            <h1 class="text-5xl sm:text-7xl lg:text-[7vw] xl:text-[8vw] font-black text-slate-900 dark:text-white mb-10 tracking-tightest leading-[0.95] md:leading-[0.85]">
              <div class="overflow-hidden">
                <span class="inline-block animate-text-reveal">The soul of human speech.</span>
              </div>
              <div class="overflow-hidden mt-2">
                <span class="inline-block animate-text-reveal text-gradient" style="animation-delay: 0.4s">Powered by AI.</span>
              </div>
            </h1>

            <!-- Subtitle -->
            <p class="text-lg md:text-xl lg:text-3xl text-slate-500 dark:text-slate-400 max-w-4xl mx-auto mb-16 leading-relaxed font-semibold animate-fade-in-up" style="animation-delay: 0.8s">
              Scale your content production with lifelike synthesis. Experience high-fidelity audio that captures every nuance, emotion, and inflection.
            </p>

            <!-- Primary CTAs -->
            <div class="flex flex-col sm:flex-row items-center justify-center gap-6 animate-fade-in-up" style="animation-delay: 1s">
              <a routerLink="/signup" class="group relative w-full sm:w-auto px-12 py-6 bg-amber-500 hover:bg-amber-600 text-white rounded-[2rem] font-black text-xl transition-all hover:scale-105 active:scale-95 shadow-2xl shadow-amber-500/40 overflow-hidden">
                <span class="relative z-10 flex items-center justify-center gap-4 uppercase tracking-widest">
                  Get Started Free <span class="group-hover:translate-x-2 transition-transform">→</span>
                </span>
                <div class="absolute inset-0 bg-gradient-to-r from-white/0 via-white/20 to-white/0 -translate-x-full group-hover:translate-x-full transition-transform duration-700"></div>
              </a>
              <a routerLink="/login" class="w-full sm:w-auto px-12 py-6 text-slate-900 dark:text-white font-black text-xl hover:bg-slate-100 dark:hover:bg-white/5 rounded-[2rem] transition-all uppercase tracking-widest border border-slate-200 dark:border-white/10">
                Explore Demo
              </a>
            </div>

            <!-- Sequential Feature Grid -->
            <div class="mt-40 md:mt-64 grid grid-cols-1 md:grid-cols-3 gap-8 lg:gap-12 text-left">
              
              <!-- Feature 1 -->
              <div class="p-10 lg:p-14 rounded-[3.5rem] bg-white dark:bg-[#0f1528] border border-slate-100 dark:border-white/5 hover:border-amber-500/50 transition-all group shadow-xl shadow-slate-200/20 dark:shadow-none animate-reveal-grid" style="animation-delay: 1.2s">
                <div class="w-20 h-20 rounded-3xl bg-amber-500/10 text-amber-500 flex items-center justify-center text-5xl mb-10 group-hover:scale-110 group-hover:rotate-6 transition-transform">🎭</div>
                <h3 class="text-3xl font-black text-slate-900 dark:text-white mb-6 tracking-tight uppercase">Emotional AI</h3>
                <p class="text-slate-500 dark:text-slate-400 leading-relaxed text-lg font-semibold">Voices that don't just speak, they perform. Natural inflections for stories that resonate.</p>
              </div>

              <!-- Feature 2 -->
              <div class="p-10 lg:p-14 rounded-[3.5rem] bg-white dark:bg-[#0f1528] border border-slate-100 dark:border-white/5 hover:border-indigo-500/50 transition-all group shadow-xl shadow-slate-200/20 dark:shadow-none animate-reveal-grid" style="animation-delay: 1.4s">
                <div class="w-20 h-20 rounded-3xl bg-indigo-500/10 text-indigo-500 flex items-center justify-center text-5xl mb-10 group-hover:scale-110 group-hover:-rotate-6 transition-transform">🌐</div>
                <h3 class="text-3xl font-black text-slate-900 dark:text-white mb-6 tracking-tight uppercase">Global Studio</h3>
                <p class="text-slate-500 dark:text-slate-400 leading-relaxed text-lg font-semibold">300+ voices across 30+ languages. Localization has never sounded so professional.</p>
              </div>

              <!-- Feature 3 -->
              <div class="p-10 lg:p-14 rounded-[3.5rem] bg-white dark:bg-[#0f1528] border border-slate-100 dark:border-white/5 hover:border-emerald-500/50 transition-all group shadow-xl shadow-slate-200/20 dark:shadow-none animate-reveal-grid" style="animation-delay: 1.6s">
                <div class="w-20 h-20 rounded-3xl bg-emerald-500/10 text-emerald-500 flex items-center justify-center text-5xl mb-10 group-hover:scale-110 transition-transform">⚡</div>
                <h3 class="text-3xl font-black text-slate-900 dark:text-white mb-6 tracking-tight uppercase">Instant Export</h3>
                <p class="text-slate-500 dark:text-slate-400 leading-relaxed text-lg font-semibold">Enterprise-grade speed. Stream audio in real-time or export master-quality MP3s.</p>
              </div>

            </div>
          </div>
        </div>
      </main>

      <!-- Decorative Bottom Blur -->
      <div class="fixed bottom-0 left-0 w-full h-32 bg-gradient-to-t from-white dark:from-[#0a0e1a] to-transparent pointer-events-none z-20"></div>
    </div>
  `,
  styles: [`
    :host { font-family: 'Inter', sans-serif; }
    .tracking-tightest { letter-spacing: -0.06em; }
    
    .text-gradient {
      background: linear-gradient(to r, #fbbf24, #f97316, #d97706);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    @keyframes textReveal {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }

    .animate-text-reveal {
      display: inline-block;
      animation: textReveal 1.2s cubic-bezier(0.16, 1, 0.3, 1) both;
    }

    @keyframes revealGrid {
      from { opacity: 0; transform: translateY(40px) scale(0.95); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    
    .animate-reveal-grid {
      animation: revealGrid 1s cubic-bezier(0.16, 1, 0.3, 1) both;
    }

    @media (max-width: 640px) {
      .tracking-tightest { letter-spacing: -0.04em; }
    }
  `]
})
export class LandingComponent {}
