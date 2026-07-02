import { Component, signal, inject, OnInit } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { ActivatedRoute } from '@angular/router';
import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../shared/components/footer/footer.component';
import {
  CustomDropdownComponent,
  DropdownOption,
} from '../../../shared/components/custom-dropdown/custom-dropdown.component';
import { ToastService } from '../../../core/services/toast.service';
import { AuthService } from '../../../core/auth/auth.service';
import { environment } from '../../../core/config/environment';

@Component({
  selector: 'app-contact-us',
  standalone: true,
  imports: [FormsModule, NavbarComponent, FooterComponent, CustomDropdownComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 pt-20 pb-16 md:pt-32 md:pb-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid md:grid-cols-2 gap-16 lg:gap-24">
            <!-- Left: Info -->
            <div class="animate-slide-up">
              <h1 class="text-4xl sm:text-5xl font-bold text-primary-900 dark:text-white mb-6">
                Get in
                <span
                  class="inline-block text-transparent bg-clip-text bg-gradient-to-r from-brand-blue to-brand-purple"
                  >touch</span
                >
              </h1>
              <p class="text-lg text-primary-500 dark:text-primary-400 mb-12 leading-relaxed">
                Whether you have a question about our enterprise plans, need technical support, or
                just want to share feedback, our team is ready to help.
              </p>

              <div class="space-y-8">
                <div class="flex items-start gap-4">
                  <div
                    class="w-10 h-10 rounded-lg bg-brand-blue/10 flex items-center justify-center shrink-0"
                  >
                    <svg
                      class="w-5 h-5 text-brand-blue"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                      ></path>
                    </svg>
                  </div>
                  <div>
                    <h3 class="font-semibold text-primary-900 dark:text-white mb-1">
                      Email Support
                    </h3>
                    <p class="text-primary-500 dark:text-primary-400 text-sm">
                      support&#64;mohitur.com
                    </p>
                  </div>
                </div>

                <div class="flex items-start gap-4">
                  <div
                    class="w-10 h-10 rounded-lg bg-brand-purple/10 flex items-center justify-center shrink-0"
                  >
                    <svg
                      class="w-5 h-5 text-brand-purple"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z"
                      ></path>
                    </svg>
                  </div>
                  <div>
                    <h3 class="font-semibold text-primary-900 dark:text-white mb-1">Community</h3>
                    <p class="text-primary-500 dark:text-primary-400 text-sm">
                      Join our Discord server for developer help.
                    </p>
                  </div>
                </div>

                <div class="flex items-start gap-4">
                  <div
                    class="w-10 h-10 rounded-lg bg-accent-500/10 flex items-center justify-center shrink-0"
                  >
                    <svg
                      class="w-5 h-5 text-accent-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                      ></path>
                    </svg>
                  </div>
                  <div>
                    <h3 class="font-semibold text-primary-900 dark:text-white mb-1">
                      Enterprise Sales
                    </h3>
                    <p class="text-primary-500 dark:text-primary-400 text-sm">
                      Interested in volume discounts? Select "Enterprise Sales" in Topic.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right: Form -->
            <div class="animate-slide-up stagger-1">
              <div
                class="bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 p-8 shadow-xl"
              >
                <form (ngSubmit)="onSubmit()" #contactForm="ngForm" class="space-y-6">
                  @if (success()) {
                    <div
                      class="p-4 bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-400 rounded-xl text-sm font-medium flex items-center gap-3 border border-emerald-200 dark:border-emerald-800/30"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        ></path>
                      </svg>
                      Thanks for reaching out! We'll get back to you shortly.
                    </div>
                  }

                  @if (error()) {
                    <div
                      class="p-4 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-xl text-sm font-medium border border-red-200 dark:border-red-800/30"
                    >
                      {{ error() }}
                    </div>
                  }

                  @if (!success()) {
                    <div class="space-y-5">
                      <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
                        <div>
                          <label
                            class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                            >First Name</label
                          >
                          <input
                            type="text"
                            name="firstName"
                            [(ngModel)]="formData.firstName"
                            required
                            placeholder="John"
                            class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                          />
                        </div>
                        <div>
                          <label
                            class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                            >Last Name</label
                          >
                          <input
                            type="text"
                            name="lastName"
                            [(ngModel)]="formData.lastName"
                            required
                            placeholder="Doe"
                            class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                          />
                        </div>
                      </div>
                      <div>
                        <label
                          class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                          >Email</label
                        >
                        <input
                          type="email"
                          name="email"
                          [(ngModel)]="formData.email"
                          required
                          email
                          placeholder="john@example.com"
                          class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all"
                        />
                      </div>
                      <div>
                        <label
                          class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                          >Topic</label
                        >
                        <app-custom-dropdown
                          [options]="topicOptions"
                          [(value)]="formData.topic"
                          placeholder="Select a topic"
                        ></app-custom-dropdown>
                      </div>
                      <div>
                        <label
                          class="block text-sm font-medium text-primary-700 dark:text-primary-300 mb-2"
                          >Message</label
                        >
                        <textarea
                          name="message"
                          [(ngModel)]="formData.message"
                          required
                          minlength="10"
                          rows="4"
                          placeholder="Tell us how we can help... (min. 10 characters)"
                          class="w-full px-4 py-3 rounded-xl bg-primary-50 dark:bg-primary-800 border border-primary-200 dark:border-primary-700 text-primary-900 dark:text-white placeholder-primary-400 focus:outline-none focus:ring-2 focus:ring-brand-blue/50 focus:border-brand-blue transition-all resize-none"
                        ></textarea>
                      </div>
                      <!-- Honeypot Field (Hidden from humans) -->
                      <div class="hidden" aria-hidden="true">
                        <input
                          type="text"
                          name="website"
                          [(ngModel)]="formData.website"
                          tabindex="-1"
                          autocomplete="off"
                        />
                      </div>
                      <button
                        type="submit"
                        [disabled]="!contactForm.valid || loading()"
                        class="w-full px-8 py-3.5 text-base font-semibold text-white bg-brand-blue hover:bg-brand-blue/90 disabled:opacity-50 disabled:cursor-not-allowed rounded-xl shadow-lg hover:shadow-xl active:scale-[0.98] transition-all flex items-center justify-center gap-2"
                      >
                        @if (loading()) {
                          <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle
                              class="opacity-25"
                              cx="12"
                              cy="12"
                              r="10"
                              stroke="currentColor"
                              stroke-width="4"
                            ></circle>
                            <path
                              class="opacity-75"
                              fill="currentColor"
                              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                            ></path>
                          </svg>
                        }
                        {{ loading() ? 'Sending...' : 'Send Message' }}
                      </button>
                    </div>
                  }
                </form>
              </div>
            </div>
          </div>
        </div>
      </main>

      <app-footer></app-footer>
    </div>
  `,
})
export class ContactUsComponent implements OnInit {
  private http = inject(HttpClient);
  private toast = inject(ToastService);
  private route = inject(ActivatedRoute);
  private authService = inject(AuthService);

  topicOptions: DropdownOption[] = [
    { value: 'support', label: 'Technical Support' },
    { value: 'billing', label: 'Billing' },
    { value: 'enterprise', label: 'Enterprise Sales' },
    { value: 'feedback', label: 'Product Feedback' },
  ];

  formData = {
    firstName: '',
    lastName: '',
    email: '',
    topic: 'enterprise',
    message: '',
    website: '',
  };

  loading = signal(false);
  success = signal(false);
  error = signal('');

  ngOnInit() {
    // 1. Auto-populate from session if logged in
    if (this.authService.isLoggedIn()) {
      this.formData.email = this.authService.currentUserEmail() || '';

      // Attempt to split full username/name into first and last if available
      const fullName = this.authService.currentUser() || '';
      if (fullName.includes(' ')) {
        const parts = fullName.split(' ');
        this.formData.firstName = parts[0];
        this.formData.lastName = parts.slice(1).join(' ');
      } else {
        this.formData.firstName = fullName;
      }
    }

    // 2. Support pre-selecting topic via query params (e.g. /contact?topic=support)
    this.route.queryParams.subscribe((params) => {
      const topic = params['topic'];
      if (topic && this.topicOptions.find((o) => o.value === topic)) {
        this.formData.topic = topic;
      }
    });
  }

  onSubmit() {
    this.loading.set(true);
    this.error.set('');

    // Generate unique Request ID for replay protection
    const requestId = crypto.randomUUID();
    const headers = { 'X-Request-ID': requestId };

    this.http
      .post<{ message: string }>(`${environment.apiUrl}/api/contact`, this.formData, { headers })
      .subscribe({
        next: (res) => {
          this.loading.set(false);
          this.success.set(true);
          this.toast.show(res.message, 'success');

          // Wait for 2 seconds then reset the form and state
          setTimeout(() => {
            this.success.set(false);
            this.formData = {
              firstName: '',
              lastName: '',
              email: '',
              topic: 'enterprise',
              message: '',
              website: '',
            };
          }, 2000);
        },
        error: (err) => {
          this.loading.set(false);
          // Security: Return generic message even for validation errors to prevent enumeration
          const errorMessage =
            err.error?.message || 'Failed to send message. Please try again later.';
          this.error.set(errorMessage);
          this.toast.show(errorMessage, 'error');
        },
      });
  }
}
