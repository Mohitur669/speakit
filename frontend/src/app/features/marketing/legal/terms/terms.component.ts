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
            <p class="text-primary-500 dark:text-primary-400">Last updated: 31/05/2026</p>
          </div>

          <div class="prose prose-primary dark:prose-invert prose-lg max-w-none animate-slide-up stagger-1 text-primary-600 dark:text-primary-300">
            <p>These Terms constitute a "Record" under the <strong>Information Technology Act, 2000</strong> and a legally binding contract under the <strong>Indian Contract Act, 1872</strong>.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">1. User Account Responsibility</h2>
            <p>You are responsible for maintaining the confidentiality of your password. You agree to notify us immediately of any unauthorized use of your account. We reserve the right to suspend accounts that provide false information during signup.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">2. Prohibited Content (Rule 3(1)(b) Compliance)</h2>
            <p>In accordance with <strong>Rule 3(1)(b) of the IT Rules, 2021</strong>, you shall not host, display, or upload any text that:</p>
            <ul class="list-disc pl-6 space-y-2 mt-4 mb-8">
              <li>Belongs to another person without right.</li>
              <li>Is defamatory, obscene, pornographic, or invasive of another's privacy.</li>
              <li>Is harmful to minors or threatens the unity and integrity of India.</li>
              <li>Violates any law currently in force in India.</li>
            </ul>
            <p>Any violation will result in immediate termination of service and reporting to relevant authorities if required by law.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">3. Rate Limiting and Service Fair Use</h2>
            <p>SpeakIT employs <strong>Bucket4j</strong> to enforce rate limits per IP/User. Attempting to bypass these limits via scripts or multiple accounts is a breach of these Terms. For Free Plan users, the daily limit is dynamically set via our system parameters (currently 3 syntheses per day).</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">4. Payments and Refunds</h2>
            <p>Payments for Pro plans are handled via <strong>Razorpay</strong>. All transactions are in <strong>Indian Rupees (INR)</strong>. Since this is a digital SaaS product with an immediate consumption nature, refunds are generally not provided once a synthesis has been performed, as per the <strong>Consumer Protection (e-Commerce) Rules, 2020</strong>.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">5. Governing Law</h2>
            <p>These Terms shall be governed by and constructed in accordance with the laws of India. Any disputes shall be subject to the exclusive jurisdiction of the courts in <strong>[VERIFY WITH COUNSEL: INSERT CITY]</strong>.</p>
          </div>
        </div>
      </main>

      <app-footer></app-footer>
    </div>
  `
})
export class TermsComponent {}
