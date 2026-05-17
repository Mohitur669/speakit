import { Component, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../shared/components/footer/footer.component';
import { ToastService } from '../../../core/services/toast.service';
import { environment } from '../../../core/config/environment';

@Component({
  selector: 'app-contact',
  standalone: true,
  imports: [CommonModule, FormsModule, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 pt-20 pb-16 md:pt-32 md:pb-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid md:grid-cols-2 gap-16 lg:gap-24">
            
            <!-- Left: Info -->
            <div class="animate-slide-up">
              <h1 class="text-4xl sm:text-5xl font-bold text-primary-900 dark:text-white tracking-tight mb-6">
                Get in <span class="text-transparent bg-clip-text bg-gradient-to-r from-brand-blue to-brand-purple">touch</span>
              </h1>
              <p class="text-lg text-primary-500 dark:text-primary-400 mb-12 leading-relaxed">
                Whether you have a question about our enterprise plans, need technical support, or just want to share feedback, our team is ready to help.
              </p>

              <div class="space-y-8">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 rounded-lg bg-brand-blue/10 flex items-center justify-center flex-shrink-0">
                    <svg class="w-5 h-5 text-brand-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg>
                  </div>
                  <div>
                    <h3 class="font-semibold text-primary-900 dark:text-white mb-1">Email Support</h3>
                    <p class="text-primary-500 dark:text-primary-400 text-sm">support&#64;speakit.ai</p>
                  </div>
                </div>

                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 rounded-lg bg-brand-purple/10 flex items-center justify-center flex-shrink-0">
                    <svg class="w-5 h-5 text-brand-purple" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z"></path></svg>
                  </div>
                  <div>
                    <h3 class="font-semibold text-primary-900 dark:text-white mb-1">Community</h3>
                    <p class="text-primary-500 dark:text-primary-400 text-sm">Join our Discord server for developer help.</p>
                  </div>
                </div>

                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 rounded-lg bg-accent-500/10 flex items-center justify-center flex-shrink-0">
                    <svg class="w-5 h-5 text-accent-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path></svg>
                  </div>
                  <div>
                    <h3 class="font-semibold text-primary-900 dark:text-white mb-1">Enterprise Sales</h3>
                    <p class="text-primary-500 dark:text-primary-400 text-sm">Interested in volume discounts? Select "Enterprise" below.</p>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right: Form -->
            <div class="animate-slide-up stagger-1">
              <div class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 p-8 shadow-xl">
                <form (ngSubmit)="onSubmit()" #contactForm="ngForm" class="space-y-6">
                  
                  <div *ngIf="success()" class="p-4 bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-400 rounded-xl text-sm font-medium flex items-center gap-3 border border-emerald-200 dark:border-emerald-800/30">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                    Thanks for reaching out! We'll get back to you shortly.
                  </div>
                  
                  <div *ngIf="error()" class="p-4 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-xl text-sm font-medium border border-red-200 dark:border-red-800/30">
                    {{ error() }}
                  </div>

                  <div *ngIf="!success()">
                    <div class="grid grid-cols-2 gap-6 mb-6">
                      <div>
                        <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">First Name</label>
                        <input type="text" name="firstName" [(ngModel)]="formData.firstName" required class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Last Name</label>
                        <input type="text" name="lastName" [(ngModel)]="formData.lastName" required class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
                      </div>
                    </div>

                    <div class="mb-6">
                      <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Email</label>
                      <input type="email" name="email" [(ngModel)]="formData.email" required email class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all">
                    </div>

                    <div class="mb-6">
                      <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Topic</label>
                      <select name="topic" [(ngModel)]="formData.topic" class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all appearance-none">
                        <option value="support">Technical Support</option>
                        <option value="billing">Billing</option>
                        <option value="enterprise">Enterprise Sales</option>
                        <option value="feedback">Product Feedback</option>
                      </select>
                    </div>

                    <div class="mb-6">
                      <label class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2">Message</label>
                      <textarea name="message" [(ngModel)]="formData.message" required rows="4" class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all resize-none"></textarea>
                    </div>

                    <button type="submit" [disabled]="!contactForm.valid || loading()" class="w-full px-8 py-3.5 text-base font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-0.5 transition-all flex items-center justify-center gap-2">
                      <svg *ngIf="loading()" class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                      </svg>
                      {{ loading() ? 'Sending...' : 'Send Message' }}
                    </button>
                  </div>
                </form>
              </div>
            </div>

          </div>
        </div>
      </main>

      <app-footer></app-footer>
    </div>
  `
})
export class ContactComponent {
  private http = inject(HttpClient);
  private toast = inject(ToastService);

  formData = {
    firstName: '',
    lastName: '',
    email: '',
    topic: 'support',
    message: ''
  };

  loading = signal(false);
  success = signal(false);
  error = signal('');

  onSubmit() {
    this.loading.set(true);
    this.error.set('');
    
    this.http.post(`${environment.apiUrl}/api/contact`, this.formData).subscribe({
      next: () => {
        this.loading.set(false);
        this.success.set(true);
        this.toast.show('Message sent successfully', 'success');
        this.formData = { firstName: '', lastName: '', email: '', topic: 'support', message: '' };
      },
      error: () => {
        this.loading.set(false);
        this.error.set('Failed to send message. Please try again later or email us directly.');
      }
    });
  }
}
