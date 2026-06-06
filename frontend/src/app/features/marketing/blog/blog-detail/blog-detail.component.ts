import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { NavbarComponent } from '../../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../../shared/components/footer/footer.component';
import { BLOG_POSTS, BlogPost } from '../blog.data';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';

@Component({
  selector: 'app-blog-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 pt-20 pb-16 md:pt-32 md:pb-24">
        <article *ngIf="post" class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          
          <div class="mb-12 animate-slide-up">
            <a routerLink="/blog" class="inline-flex items-center gap-2 text-sm font-medium text-primary-500 hover:text-brand-blue mb-8 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
              Back to blog
            </a>
            
            <div class="flex items-center gap-4 text-sm mb-6">
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-blue/10 text-brand-blue font-semibold">
                {{ post.category }}
              </span>
              <time class="text-primary-400">{{ post.date }}</time>
              <span class="text-primary-300 dark:text-primary-600">&middot;</span>
              <span class="text-primary-400">{{ post.readTime }}</span>
            </div>
            
            <h1 class="text-4xl sm:text-5xl font-bold text-primary-900 dark:text-white tracking-tight mb-8">
              {{ post.title }}
            </h1>
            
            <div class="flex items-center gap-4 py-6 border-y border-primary-200 dark:border-primary-800">
              <div class="w-12 h-12 rounded-full bg-primary-200 dark:bg-primary-700 overflow-hidden">
                <img src="data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40'><rect width='40' height='40' fill='%23e2e8f0'/><circle cx='20' cy='15' r='8' fill='%2394a3b8'/><path d='M4 40c0-10 6-16 16-16s16 6 16 16' fill='%2394a3b8'/></svg>" alt="Author" class="w-full h-full object-cover">
              </div>
              <div>
                <div class="font-semibold text-primary-900 dark:text-white">{{ post.author }}</div>
                <div class="text-sm text-primary-500">{{ post.authorRole }}</div>
              </div>
            </div>
          </div>

          <div class="prose prose-primary dark:prose-invert prose-lg max-w-none animate-slide-up stagger-1 text-primary-600 dark:text-primary-300" [innerHTML]="safeContent">
          </div>

          <!-- Share / Tags -->
          <div class="mt-12 pt-8 border-t border-primary-200 dark:border-primary-800 flex flex-col sm:flex-row sm:items-center justify-between gap-6 animate-slide-up stagger-2">
            <div class="flex flex-wrap gap-2">
              <span *ngFor="let tag of post.tags" class="px-3 py-1 rounded-full bg-primary-100 dark:bg-primary-800 text-primary-600 dark:text-primary-300 text-sm">{{ tag }}</span>
            </div>
            <div class="flex items-center gap-4">
              <span class="text-sm font-medium text-primary-500">Share article</span>
              <button class="w-10 h-10 rounded-full bg-primary-100 dark:bg-primary-800 flex items-center justify-center text-primary-600 dark:text-primary-300 hover:bg-brand-blue hover:text-white transition-all">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path></svg>
              </button>
            </div>
          </div>
          
        </article>

        <div *ngIf="!post" class="max-w-3xl mx-auto px-4 text-center py-20">
          <h2 class="text-2xl font-bold text-primary-900 dark:text-white">Article not found</h2>
          <a routerLink="/blog" class="text-brand-blue mt-4 inline-block hover:underline">Return to blog</a>
        </div>
      </main>

      <app-footer></app-footer>
    </div>
  `,
  styles: [`
    /* Minimal styles for code blocks within prose */
    ::ng-deep .prose pre {
      background-color: #1e293b !important;
      color: #f8fafc !important;
      border-radius: 0.75rem;
      padding: 1.25rem;
      overflow-x: auto;
      font-size: 0.875em;
    }
    ::ng-deep .dark .prose pre {
      background-color: #000 !important;
      border: 1px solid #27272a;
    }
    ::ng-deep .prose code {
      color: #3b82f6;
      background-color: rgba(59, 130, 246, 0.1);
      padding: 0.125rem 0.25rem;
      border-radius: 0.25rem;
      font-weight: 600;
    }
    ::ng-deep .prose pre code {
      color: inherit;
      background-color: transparent;
      padding: 0;
      font-weight: 400;
    }
  `]

})
export class BlogDetailComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private sanitizer = inject(DomSanitizer);
  
  post: BlogPost | undefined;
  safeContent: SafeHtml | undefined;

  ngOnInit() {
    this.route.paramMap.subscribe(params => {
      const slug = params.get('slug');
      this.post = BLOG_POSTS.find(p => p.slug === slug);
      if (this.post) {
        this.safeContent = this.sanitizer.bypassSecurityTrustHtml(this.post.content);
      }
    });
  }
}
