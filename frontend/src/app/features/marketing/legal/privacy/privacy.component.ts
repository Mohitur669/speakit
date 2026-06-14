import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavbarComponent } from '../../../../shared/components/navbar/navbar.component';
import { FooterComponent } from '../../../../shared/components/footer/footer.component';

@Component({
  selector: 'app-privacy',
  standalone: true,
  imports: [CommonModule, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-primary-50 dark:bg-primary-950 flex flex-col">
      <app-navbar></app-navbar>

      <main class="flex-1 pt-20 pb-16 md:pt-32 md:pb-24">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          
          <div class="mb-12 animate-slide-up">
            <h1 class="text-4xl font-bold text-primary-900 dark:text-white tracking-tight mb-4">Privacy Policy</h1>
            <p class="text-primary-500 dark:text-primary-400">Last updated: 31/05/2026</p>
          </div>

          <div class="prose prose-primary dark:prose-invert prose-lg max-w-none animate-slide-up stagger-1 text-primary-600 dark:text-primary-300">
            <p>SpeakIT (mohitur-speakit.vercel.app) values your trust. This Privacy Policy explains how we handle your personal data in accordance with the <strong>Digital Personal Data Protection Act, 2023 (DPDP Act)</strong> and the <strong>Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011</strong>.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">1. Consent and Data Collection</h2>
            <p>By creating an account or using our service, you provide your free, specific, informed, and unambiguous consent for us to process your data as required under <strong>Section 6 of the DPDP Act</strong>. We collect:</p>
            <ul class="list-disc pl-6 space-y-2 mt-4 mb-8">
              <li><strong>Account Information:</strong> Your username, email address, and phone number (stored securely in our PostgreSQL database).</li>
              <li><strong>Input Content:</strong> The text you submit for Text-to-Speech conversion.</li>
              <li><strong>Usage Data:</strong> IP addresses and technical logs recorded by our Spring Boot backend for rate limiting (Bucket4j) and security monitoring.</li>
            </ul>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">2. Purpose of Processing</h2>
            <p>In line with "Purpose Limitation" requirements, your data is used strictly for:</p>
            <ul class="list-disc pl-6 space-y-2 mt-4 mb-8">
              <li>Authenticating your access to the SpeakIT dashboard.</li>
              <li>Generating audio files via AWS Polly.</li>
              <li>Enforcing daily synthesis limits based on your plan (Free/Pro).</li>
              <li>Maintaining cybersecurity as per <strong>Section 43A of the IT Act, 2000</strong>.</li>
            </ul>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">3. Data Residency and Third-Party Transfer</h2>
            <p>We process your data through <strong>Amazon Web Services (AWS)</strong>. To ensure compliance with Indian data sovereignty preferences, we utilize the <strong>ap-south-1 (Mumbai)</strong> region. Your input text is processed by AWS Polly to generate speech but is not used to train global AI models without separate consent.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">4. Data Security and Retention</h2>
            <p>We implement "Reasonable Security Practices" including password hashing and JWT-based session management. We retain your account data only as long as your account is active. You may request deletion of your data at any time by visiting your Profile Settings.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">5. Grievance Redressal</h2>
            <p>As mandated by <strong>Rule 3(11) of the IT Rules, 2021</strong>, if you have any complaints regarding data processing, please contact our Grievance Officer:</p>
            <p class="mt-4 font-medium text-primary-900 dark:text-white">
              Name: Mohd Mohitur Rahaman<br>
              Email: grievance&#64;mohitur.com<br>
              Jurisdiction: India
            </p>
          </div>
        </div>
      </main>

      <app-footer></app-footer>
    </div>
  `,
  styles: [`
    .prose h2 { scroll-margin-top: 6rem; }
  `]
})
export class PrivacyComponent {}
