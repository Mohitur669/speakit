import { Component } from '@angular/core';

import { NavbarComponent } from '../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../shared/components/footer/footer.component';

@Component({
  selector: 'app-about',
  standalone: true,
  imports: [NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1">
        <!-- Hero -->
        <section class="relative pt-20 pb-16 md:pt-32 md:pb-24 overflow-hidden">
          <div
            class="absolute inset-0 bg-gradient-to-b from-primary-100/50 dark:from-primary-900/50 to-transparent -z-10"
          ></div>
          <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
            <h1
              class="text-4xl sm:text-5xl md:text-6xl font-bold text-primary-900 dark:text-white tracking-tight mb-6 animate-slide-up"
            >
              Giving voice to the
              <span
                class="text-transparent bg-clip-text bg-gradient-to-r from-brand-blue to-brand-purple"
                >internet</span
              >
            </h1>
            <p
              class="text-xl text-primary-500 dark:text-primary-400 leading-relaxed animate-slide-up stagger-1"
            >
              We're a team of engineers and audio researchers building the infrastructure for the
              next generation of auditory experiences.
            </p>
          </div>
        </section>

        <!-- Mission -->
        <section
          class="py-16 md:py-24 bg-white dark:bg-primary-900 border-y border-primary-200 dark:border-primary-800"
        >
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="grid md:grid-cols-2 gap-12 lg:gap-24 items-center">
              <div>
                <div
                  class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-brand-blue/10 text-brand-blue text-sm font-semibold mb-6"
                >
                  Our Mission
                </div>
                <h2 class="text-3xl sm:text-4xl font-bold text-primary-900 dark:text-white mb-6">
                  Democratizing studio-quality speech.
                </h2>
                <p class="text-lg text-primary-500 dark:text-primary-400 mb-6 leading-relaxed">
                  Historically, high-quality voiceovers required expensive studio time, professional
                  voice actors, and hours of post-production. We believe everyone should have access
                  to world-class audio.
                </p>
                <p class="text-lg text-primary-500 dark:text-primary-400 leading-relaxed">
                  By leveraging state-of-the-art neural networks, SpeakIT transforms text into
                  natural, emotional, and highly expressive speech in milliseconds. We are building
                  the tools that will power the audiobooks, podcasts, and digital avatars of
                  tomorrow.
                </p>
              </div>
              <div class="relative">
                <div
                  class="aspect-square rounded-2xl bg-gradient-to-tr from-brand-blue/20 to-brand-purple/20 p-8 flex items-center justify-center border border-primary-200 dark:border-primary-700 shadow-2xl"
                >
                  <div class="grid grid-cols-2 gap-4 w-full h-full">
                    <div
                      class="bg-white dark:bg-primary-800 rounded-xl shadow-sm border border-primary-100 dark:border-primary-700"
                    ></div>
                    <div class="bg-brand-blue rounded-xl shadow-sm"></div>
                    <div class="bg-accent-500 rounded-xl shadow-sm"></div>
                    <div
                      class="bg-white dark:bg-primary-800 rounded-xl shadow-sm border border-primary-100 dark:border-primary-700"
                    ></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- Values -->
        <section class="py-20 md:py-32">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="text-center max-w-2xl mx-auto mb-16">
              <h2 class="text-3xl font-bold text-primary-900 dark:text-white mb-4">
                Our Core Values
              </h2>
              <p class="text-lg text-primary-500 dark:text-primary-400">
                The principles that guide how we build product and treat our customers.
              </p>
            </div>
            <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-8">
              <div
                class="p-8 bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-sm"
              >
                <div
                  class="w-12 h-12 rounded-xl bg-brand-blue/10 flex items-center justify-center mb-6"
                >
                  <svg
                    class="w-6 h-6 text-brand-blue"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M13 10V3L4 14h7v7l9-11h-7z"
                    ></path>
                  </svg>
                </div>
                <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">
                  Speed matters
                </h3>
                <p class="text-primary-500 dark:text-primary-400">
                  We optimize every millisecond of our generation pipeline. Fast feedback loops lead
                  to better content creation.
                </p>
              </div>
              <div
                class="p-8 bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-sm"
              >
                <div
                  class="w-12 h-12 rounded-xl bg-brand-purple/10 flex items-center justify-center mb-6"
                >
                  <svg
                    class="w-6 h-6 text-brand-purple"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                    ></path>
                  </svg>
                </div>
                <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">
                  Privacy first
                </h3>
                <p class="text-primary-500 dark:text-primary-400">
                  We don't train on your scripts. Your intellectual property remains yours, securely
                  processed and immediately discarded.
                </p>
              </div>
              <div
                class="p-8 bg-white dark:bg-primary-900 rounded-2xl border border-primary-200 dark:border-primary-700 shadow-sm"
              >
                <div
                  class="w-12 h-12 rounded-xl bg-accent-500/10 flex items-center justify-center mb-6"
                >
                  <svg
                    class="w-6 h-6 text-accent-500"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5"
                    ></path>
                  </svg>
                </div>
                <h3 class="text-xl font-semibold text-primary-900 dark:text-white mb-3">
                  Relentless quality
                </h3>
                <p class="text-primary-500 dark:text-primary-400">
                  If a voice sounds robotic, we don't ship it. We only deploy models that pass
                  strict human Turing tests for emotion.
                </p>
              </div>
            </div>
          </div>
        </section>
      </main>

      <app-footer></app-footer>
    </div>
  `,
})
export class AboutComponent {}
