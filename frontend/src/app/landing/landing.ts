import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NavbarComponent } from '../components/navbar.component';

@Component({
  selector: 'app-landing',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent],
  template: `
    <div class="min-h-screen bg-white dark:bg-[#090b11] transition-colors duration-500 overflow-x-hidden relative font-body">
      <app-navbar></app-navbar>

      <!-- Premium Hero Section -->
      <main class="relative pt-16 md:pt-28 pb-32">
        
        <!-- Subtle Ambient Background -->
        <div class="absolute inset-0 overflow-hidden pointer-events-none -z-10">
          <div class="absolute -top-[10%] -right-[10%] w-[60vw] h-[60vw] bg-amber-500/5 dark:bg-amber-500/[0.03] rounded-full blur-[100px]"></div>
          <div class="absolute -bottom-[10%] -left-[10%] w-[50vw] h-[50vw] bg-indigo-500/5 dark:bg-indigo-500/[0.03] rounded-full blur-[100px]"></div>
        </div>

        <div class="max-w-7xl mx-auto px-6 lg:px-8 text-center">
          
          <!-- Floating Badge -->
          <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900/5 dark:bg-white/5 border border-slate-900/10 dark:border-white/10 text-slate-900 dark:text-white text-[10px] md:text-xs font-bold uppercase tracking-wider mb-8 animate-fade-in">
            <span class="flex h-2 w-2 relative">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
            </span>
            New: Neural Engine 3.0
          </div>

          <!-- Hero Heading -->
          <h1 class="text-4xl sm:text-6xl lg:text-7xl font-bold text-slate-900 dark:text-white mb-8 tracking-tight leading-[1.1] md:leading-[1.05]">
            <span class="block animate-slide-up" style="animation-delay: 0.1s">The soul of human speech.</span>
            <span class="block text-amber-500 animate-slide-up" style="animation-delay: 0.3s">Powered by AI.</span>
          </h1>

          <!-- Subtitle -->
          <p class="text-base md:text-lg lg:text-xl text-slate-500 dark:text-slate-400 max-w-2xl mx-auto mb-12 leading-relaxed font-medium animate-slide-up" style="animation-delay: 0.5s">
            Create lifelike voiceovers in seconds. Experience high-fidelity audio that captures every nuance, emotion, and inflection for your content.
          </p>

          <!-- Primary CTAs -->
          <div class="flex flex-col sm:flex-row items-center justify-center gap-4 animate-slide-up" style="animation-delay: 0.7s">
            <a routerLink="/signup" class="w-full sm:w-auto px-8 py-3.5 bg-amber-500 hover:bg-amber-600 text-white rounded-xl font-bold text-base transition-all hover:scale-[1.02] active:scale-95 shadow-lg shadow-amber-500/20">
              Get Started Free
            </a>
            <a routerLink="/login" class="w-full sm:w-auto px-8 py-3.5 text-slate-900 dark:text-white font-bold text-base hover:bg-slate-100 dark:hover:bg-white/5 rounded-xl transition-all border border-slate-200 dark:border-white/10">
              View Showcase
            </a>
          </div>

          <!-- Feature Grid -->
          <div class="mt-32 md:mt-48 grid grid-cols-1 md:grid-cols-3 gap-6 lg:gap-8 text-left">
            
            <!-- Feature 1 -->
            <div class="p-8 rounded-3xl bg-white dark:bg-[#0f172a] border border-slate-100 dark:border-slate-800 hover:border-amber-500/30 transition-all group shadow-sm animate-slide-up" style="animation-delay: 0.9s">
              <div class="w-12 h-12 rounded-2xl bg-amber-500/10 text-amber-500 flex items-center justify-center text-2xl mb-6 group-hover:scale-110 transition-transform">🎭</div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-3 tracking-tight">Emotional AI</h3>
              <p class="text-slate-500 dark:text-slate-400 leading-relaxed text-sm font-medium">Voices that don't just speak, they perform. Natural inflections for stories that resonate with your audience.</p>
            </div>

            <!-- Feature 2 -->
            <div class="p-8 rounded-3xl bg-white dark:bg-[#0f172a] border border-slate-100 dark:border-slate-800 hover:border-indigo-500/30 transition-all group shadow-sm animate-slide-up" style="animation-delay: 1.1s">
              <div class="w-12 h-12 rounded-2xl bg-indigo-500/10 text-indigo-500 flex items-center justify-center text-2xl mb-6 group-hover:scale-110 transition-transform">🌐</div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-3 tracking-tight">Global Reach</h3>
              <p class="text-slate-500 dark:text-slate-400 leading-relaxed text-sm font-medium">Access 300+ voices across 30+ languages. Professional localization is now just one click away.</p>
            </div>

            <!-- Feature 3 -->
            <div class="p-8 rounded-3xl bg-white dark:bg-[#0f172a] border border-slate-100 dark:border-slate-800 hover:border-emerald-500/30 transition-all group shadow-sm animate-slide-up" style="animation-delay: 1.3s">
              <div class="w-12 h-12 rounded-2xl bg-emerald-500/10 text-emerald-500 flex items-center justify-center text-2xl mb-6 group-hover:scale-110 transition-transform">⚡</div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-3 tracking-tight">Instant Export</h3>
              <p class="text-slate-500 dark:text-slate-400 leading-relaxed text-sm font-medium">Real-time streaming and master-quality MP3 exports. Built for creators who value speed and quality.</p>
            </div>

          </div>
        </div>
      </main>
    </div>
  `,
  styles: [`
    :host { font-family: 'Inter', sans-serif; }
  `]
})
export class LandingComponent {}
