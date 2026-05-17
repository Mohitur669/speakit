import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavbarComponent } from '../../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../../shared/components/footer/footer.component';

@Component({
  selector: 'app-terms',
  standalone: true,
  imports: [CommonModule, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 pt-20 pb-16 md:pt-32 md:pb-24">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          
          <div class="mb-12 animate-slide-up">
            <h1 class="text-4xl font-bold text-primary-900 dark:text-white tracking-tight mb-4">Terms of Service</h1>
            <p class="text-primary-500 dark:text-primary-400">Last updated: May 17, 2026</p>
          </div>

          <div class="prose prose-primary dark:prose-invert prose-lg max-w-none animate-slide-up stagger-1 text-primary-600 dark:text-primary-300">
            <p>Welcome to SpeakIT. These Terms of Service constitute a legally binding agreement made between you and SpeakIT concerning your access to and use of our application and services.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">1. Agreement to Terms</h2>
            <p>By accessing the Application, you agree that you have read, understood, and agree to be bound by all of these Terms of Service. If you do not agree with all of these Terms of Service, then you are expressly prohibited from using the Application and you must discontinue use immediately.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">2. Intellectual Property Rights</h2>
            <p>The text you submit to the Service remains your intellectual property. We claim no ownership rights over your input text or the resulting generated audio files. The Application itself, including all source code, databases, functionality, software, website designs, audio, video, text, photographs, and graphics on the Application are owned or controlled by us.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">3. Prohibited Activities</h2>
            <p>You may not access or use the Application for any purpose other than that for which we make the Application available. The Application may not be used in connection with any commercial endeavors except those that are specifically endorsed or approved by us. You agree not to:</p>
            <ul class="list-disc pl-6 space-y-2 mt-4 mb-8">
              <li>Use the Service to generate hate speech, defamatory content, or content that promotes violence.</li>
              <li>Circumvent, disable, or otherwise interfere with security-related features of the Application.</li>
              <li>Attempt to bypass any measures of the Application designed to prevent or restrict access to the Application, or any portion of the Application.</li>
              <li>Use the Service in any automated manner via scripts or unauthorized API access to mass-generate content without an Enterprise agreement.</li>
            </ul>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">4. Subscriptions and Billing</h2>
            <p>If you purchase a Pro subscription, you agree to provide current, complete, and accurate purchase and account information. You agree to promptly update account and payment information, including email address, payment method, and payment card expiration date, so that we can complete your transactions and contact you as needed. We bill you through an online billing account for purchases made via the Application.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">5. Contact Us</h2>
            <p>In order to resolve a complaint regarding the Application or to receive further information regarding use of the Application, please contact us at:</p>
            <p class="mt-4 font-medium text-primary-900 dark:text-white">legal&#64;speakit.ai</p>
          </div>
        </div>
      </main>

      <app-footer></app-footer>
    </div>
  `
})
export class TermsComponent {}
