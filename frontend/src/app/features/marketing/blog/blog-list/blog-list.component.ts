import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NavbarComponent } from '../../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../../shared/components/footer/footer.component';

@Component({
  selector: 'app-blog-list',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 pt-20 pb-16 md:pt-32 md:pb-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          
          <div class="max-w-3xl mb-16 animate-slide-up">
            <h1 class="text-4xl sm:text-5xl font-bold text-primary-900 dark:text-white tracking-tight mb-6">
              The <span class="text-transparent bg-clip-text bg-gradient-to-r from-brand-blue to-brand-purple">SpeakIT</span> Blog
            </h1>
            <p class="text-xl text-primary-500 dark:text-primary-400 leading-relaxed">
              Insights on AI voice generation, product updates, and the future of auditory experiences.
            </p>
          </div>

          <!-- Featured Article -->
          <article class="relative group cursor-pointer mb-16 animate-slide-up stagger-1">
            <div class="absolute -inset-y-4 -inset-x-4 sm:-inset-y-6 sm:-inset-x-6 rounded-3xl bg-white dark:bg-primary-900 border border-primary-200 dark:border-primary-700 opacity-0 group-hover:opacity-100 transition-all shadow-xl scale-95 group-hover:scale-100 -z-10"></div>
            <div class="grid md:grid-cols-2 gap-8 items-center">
              <div class="aspect-[16/9] md:aspect-auto md:h-full w-full rounded-2xl bg-gradient-to-br from-brand-blue/20 to-brand-purple/20 border border-primary-200 dark:border-primary-700 overflow-hidden flex items-center justify-center">
                <svg class="w-24 h-24 text-brand-blue/50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path></svg>
              </div>
              <div class="py-4">
                <div class="flex items-center gap-4 text-sm mb-4">
                  <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-blue/10 text-brand-blue font-semibold">
                    Product Update
                  </span>
                  <time class="text-primary-400">May 15, 2026</time>
                </div>
                <h2 class="text-3xl font-bold text-primary-900 dark:text-white mb-4 group-hover:text-brand-blue transition-colors">
                  Introducing the Neural Voice Engine v2.0
                </h2>
                <p class="text-lg text-primary-500 dark:text-primary-400 mb-6 line-clamp-3">
                  Today we're thrilled to announce the next generation of our text-to-speech architecture. With completely rebuilt acoustic models, our new engine delivers unprecedented emotional range, breathing patterns, and context-aware intonation while reducing latency by 40%.
                </p>
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-full bg-primary-200 dark:bg-primary-700 overflow-hidden">
                    <img src="data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40'><rect width='40' height='40' fill='%23e2e8f0'/><circle cx='20' cy='15' r='8' fill='%2394a3b8'/><path d='M4 40c0-10 6-16 16-16s16 6 16 16' fill='%2394a3b8'/></svg>" alt="Author" class="w-full h-full object-cover">
                  </div>
                  <div>
                    <div class="text-sm font-semibold text-primary-900 dark:text-white">Alex Chen</div>
                    <div class="text-xs text-primary-400">Head of Audio Research</div>
                  </div>
                </div>
              </div>
            </div>
          </article>

          <!-- Article Grid -->
          <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-8 animate-slide-up stagger-2">
            
            <article class="group cursor-pointer">
              <div class="aspect-[16/9] w-full rounded-2xl bg-primary-100 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 mb-6 overflow-hidden flex items-center justify-center">
                 <svg class="w-12 h-12 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path></svg>
              </div>
              <div class="flex items-center gap-4 text-sm mb-3">
                <span class="text-accent-500 font-semibold">Engineering</span>
                <time class="text-primary-400">April 28, 2026</time>
              </div>
              <h3 class="text-xl font-bold text-primary-900 dark:text-white mb-3 group-hover:text-brand-blue transition-colors">
                How we achieved 50ms latency for streaming TTS
              </h3>
              <p class="text-primary-500 dark:text-primary-400 line-clamp-2">
                A deep dive into our Golang-based streaming architecture, memory-mapped byte buffers, and edge-edge CDN caching strategies.
              </p>
            </article>

            <article class="group cursor-pointer">
              <div class="aspect-[16/9] w-full rounded-2xl bg-primary-100 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 mb-6 overflow-hidden flex items-center justify-center">
                 <svg class="w-12 h-12 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"></path></svg>
              </div>
              <div class="flex items-center gap-4 text-sm mb-3">
                <span class="text-purple-500 font-semibold">Guides</span>
                <time class="text-primary-400">April 12, 2026</time>
              </div>
              <h3 class="text-xl font-bold text-primary-900 dark:text-white mb-3 group-hover:text-brand-blue transition-colors">
                Mastering SSML for podcast generation
              </h3>
              <p class="text-primary-500 dark:text-primary-400 line-clamp-2">
                Learn how to use Speech Synthesis Markup Language to add dramatic pauses, change pitch, and control pronunciation for long-form audio.
              </p>
            </article>

            <article class="group cursor-pointer">
              <div class="aspect-[16/9] w-full rounded-2xl bg-primary-100 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 mb-6 overflow-hidden flex items-center justify-center">
                 <svg class="w-12 h-12 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path></svg>
              </div>
              <div class="flex items-center gap-4 text-sm mb-3">
                <span class="text-emerald-500 font-semibold">Company</span>
                <time class="text-primary-400">March 05, 2026</time>
              </div>
              <h3 class="text-xl font-bold text-primary-900 dark:text-white mb-3 group-hover:text-brand-blue transition-colors">
                SpeakIT raises $5M Seed Round
              </h3>
              <p class="text-primary-500 dark:text-primary-400 line-clamp-2">
                We're excited to announce our seed funding led by top audio-tech investors to help us scale our infrastructure and expand our voice library.
              </p>
            </article>

          </div>
        </div>
      </main>

      <app-footer></app-footer>
    </div>
  `
})
export class BlogListComponent {}
