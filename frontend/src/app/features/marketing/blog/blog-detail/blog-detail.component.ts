import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NavbarComponent } from '../../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../../shared/components/footer/footer.component';

@Component({
  selector: 'app-blog-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 pt-20 pb-16 md:pt-32 md:pb-24">
        <article class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          
          <div class="mb-12 animate-slide-up">
            <a routerLink="/blog" class="inline-flex items-center gap-2 text-sm font-medium text-primary-500 hover:text-brand-blue mb-8 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
              Back to blog
            </a>
            
            <div class="flex items-center gap-4 text-sm mb-6">
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-blue/10 text-brand-blue font-semibold">
                Product Update
              </span>
              <time class="text-primary-400">May 15, 2026</time>
              <span class="text-primary-300 dark:text-primary-600">&middot;</span>
              <span class="text-primary-400">4 min read</span>
            </div>
            
            <h1 class="text-4xl sm:text-5xl font-bold text-primary-900 dark:text-white tracking-tight mb-8">
              Introducing the Neural Voice Engine v2.0
            </h1>
            
            <div class="flex items-center gap-4 py-6 border-y border-primary-200 dark:border-primary-800">
              <div class="w-12 h-12 rounded-full bg-primary-200 dark:bg-primary-700 overflow-hidden">
                <img src="data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40'><rect width='40' height='40' fill='%23e2e8f0'/><circle cx='20' cy='15' r='8' fill='%2394a3b8'/><path d='M4 40c0-10 6-16 16-16s16 6 16 16' fill='%2394a3b8'/></svg>" alt="Author" class="w-full h-full object-cover">
              </div>
              <div>
                <div class="font-semibold text-primary-900 dark:text-white">Alex Chen</div>
                <div class="text-sm text-primary-500">Head of Audio Research at SpeakIT</div>
              </div>
            </div>
          </div>

          <div class="prose prose-primary dark:prose-invert prose-lg max-w-none animate-slide-up stagger-1 text-primary-600 dark:text-primary-300">
            <p class="lead text-xl text-primary-700 dark:text-primary-200 font-medium">
              Today we're thrilled to announce the next generation of our text-to-speech architecture. With completely rebuilt acoustic models, our new engine delivers unprecedented emotional range, breathing patterns, and context-aware intonation while reducing latency by 40%.
            </p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">The challenge with legacy TTS</h2>
            <p>
              For years, text-to-speech engines relied on concatenative synthesis—stitching together tiny fragments of recorded speech. While functional, it lacked soul. The introduction of neural TTS (like our v1 engine) solved the robotic cadence but still struggled with long-form context. If a sentence ended with an exclamation mark, the engine knew to sound excited, but it didn't know <em>why</em>.
            </p>
            
            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">Enter v2.0: Context-Aware Generation</h2>
            <p>
              Our v2.0 engine doesn't just read words; it understands semantic intent. By increasing our attention window from 128 tokens to 4096 tokens, the model analyzes the entire paragraph before generating the first phoneme. 
            </p>
            <p>
              This means:
            </p>
            <ul>
              <li><strong>Natural Breathing:</strong> Pauses are inserted not just at commas, but where a human would naturally draw breath based on sentence complexity.</li>
              <li><strong>Emotional Trajectory:</strong> A story that starts sad and ends happy will smoothly transition in tone, rather than shifting abruptly.</li>
              <li><strong>Zero-Shot Voice Cloning:</strong> Improved fidelity when adapting to new voices with under 3 seconds of reference audio.</li>
            </ul>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">Available Today</h2>
            <p>
              The v2.0 engine is rolling out today for all Pro tier users. You don't need to change any API endpoints; simply select any voice marked with the "Neural" badge in the dashboard.
            </p>
            <p>
              We can't wait to hear what you build with it.
            </p>
          </div>

          <!-- Share / Tags -->
          <div class="mt-12 pt-8 border-t border-primary-200 dark:border-primary-800 flex flex-col sm:flex-row sm:items-center justify-between gap-6 animate-slide-up stagger-2">
            <div class="flex gap-2">
              <span class="px-3 py-1 rounded-full bg-primary-100 dark:bg-primary-800 text-primary-600 dark:text-primary-300 text-sm">Product</span>
              <span class="px-3 py-1 rounded-full bg-primary-100 dark:bg-primary-800 text-primary-600 dark:text-primary-300 text-sm">AI</span>
              <span class="px-3 py-1 rounded-full bg-primary-100 dark:bg-primary-800 text-primary-600 dark:text-primary-300 text-sm">Engineering</span>
            </div>
            <div class="flex items-center gap-4">
              <span class="text-sm font-medium text-primary-500">Share article</span>
              <button class="w-10 h-10 rounded-full bg-primary-100 dark:bg-primary-800 flex items-center justify-center text-primary-600 dark:text-primary-300 hover:bg-brand-blue hover:text-white transition-all">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path></svg>
              </button>
            </div>
          </div>
          
        </article>
      </main>

      <app-footer></app-footer>
    </div>
  `,
  styles: [`
    .prose h2 { scroll-margin-top: 6rem; }
    .prose ul { list-style-type: disc; padding-left: 1.5rem; margin-top: 1rem; margin-bottom: 1rem; }
    .prose li { margin-bottom: 0.5rem; }
    .prose strong { color: inherit; font-weight: 600; }
  `]
})
export class BlogDetailComponent {}
