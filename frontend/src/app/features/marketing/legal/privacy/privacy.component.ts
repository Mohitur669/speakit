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
            <p class="text-primary-500 dark:text-primary-400">Last updated: May 17, 2026</p>
          </div>

          <div class="prose prose-primary dark:prose-invert prose-lg max-w-none animate-slide-up stagger-1 text-primary-600 dark:text-primary-300">
            <p>At SpeakIT, we take your privacy seriously. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit our website or use our application.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">1. Information We Collect</h2>
            <p>We may collect information about you in a variety of ways. The information we may collect via the Application includes:</p>
            <ul class="list-disc pl-6 space-y-2 mt-4 mb-8">
              <li><strong>Personal Data:</strong> Personally identifiable information, such as your name and email address, that you voluntarily give to us when you register with the Application.</li>
              <li><strong>Derivative Data:</strong> Information our servers automatically collect when you access the Application, such as your IP address, your browser type, your operating system, your access times, and the pages you have viewed directly before and after accessing the Application.</li>
              <li><strong>Audio Processing Data:</strong> Text submitted for text-to-speech conversion. We only process this text to provide the service and do not use it to train our models or share it with third parties.</li>
            </ul>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">2. Use of Your Information</h2>
            <p>Having accurate information about you permits us to provide you with a smooth, efficient, and customized experience. Specifically, we may use information collected about you via the Application to:</p>
            <ul class="list-disc pl-6 space-y-2 mt-4 mb-8">
              <li>Create and manage your account.</li>
              <li>Process your text-to-speech requests.</li>
              <li>Email you regarding your account or order.</li>
              <li>Increase the efficiency and operation of the Application.</li>
              <li>Monitor and analyze usage and trends to improve your experience.</li>
            </ul>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">3. Security of Your Information</h2>
            <p>We use administrative, technical, and physical security measures to help protect your personal information. While we have taken reasonable steps to secure the personal information you provide to us, please be aware that despite our efforts, no security measures are perfect or impenetrable.</p>

            <h2 class="text-2xl font-bold text-primary-900 dark:text-white mt-12 mb-4">4. Contact Us</h2>
            <p>If you have questions or comments about this Privacy Policy, please contact us at:</p>
            <p class="mt-4 font-medium text-primary-900 dark:text-white">privacy&#64;speakit.ai</p>
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
