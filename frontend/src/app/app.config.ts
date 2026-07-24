/**
 * Root application configuration defining global providers,
 * route structure, and lazy-loaded feature modules.
 */
import { ApplicationConfig, provideZoneChangeDetection, ErrorHandler } from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter, withInMemoryScrolling, withRouterConfig } from '@angular/router';
import { authInterceptor } from './core/interceptors/auth.interceptor';
import { authGuard } from './core/guards/auth.guard';
import * as Sentry from "@sentry/angular";


const routes = [
  {
    path: '',
    loadComponent: () => import('./features/home/landing').then(m => m.LandingComponent)
  },
  {
    path: 'about',
    loadComponent: () => import('./features/marketing/about/about.component').then(m => m.AboutComponent)
  },
  {
   path: 'contact',
   loadComponent: () => import('./features/marketing/contact/contact.component').then(m => m.ContactUsComponent)
  },
  {
    path: 'blog',
    loadComponent: () => import('./features/marketing/blog/blog-list/blog-list.component').then(m => m.BlogListComponent)
  },
  {
    path: 'blog/:slug',
    loadComponent: () => import('./features/marketing/blog/blog-detail/blog-detail.component').then(m => m.BlogDetailComponent)
  },
  {
    path: 'privacy',
    loadComponent: () => import('./features/marketing/legal/privacy/privacy.component').then(m => m.PrivacyComponent)
  },
  {
    path: 'terms',
    loadComponent: () => import('./features/marketing/legal/terms/terms.component').then(m => m.TermsComponent)
  },
  {
    path: 'login',
    loadComponent: () => import('./features/auth/login').then(m => m.LoginComponent)
  },
  {
    path: 'signup',
    loadComponent: () => import('./features/auth/signup').then(m => m.SignupComponent)
  },
  {
    path: 'verify-email',
    loadComponent: () => import('./features/auth/verify-email/verify-email.component').then(m => m.VerifyEmailComponent)
  },
  {
    path: 'forgot-password',
    loadComponent: () => import('./features/auth/forgot-password/forgot-password.component').then(m => m.ForgotPasswordComponent)
  },
  {
    path: 'reset-password',
    loadComponent: () => import('./features/auth/reset-password/reset-password.component').then(m => m.ResetPasswordComponent)
  },
  {
    path: 'tts',
    loadComponent: () => import('./features/tts').then(m => m.TtsComponent),
    canActivate: [authGuard]
  },
  {
    path: 'stt',
    loadComponent: () => import('./features/stt/pages/stt-page/stt-page.component').then(m => m.SttPageComponent),
    canActivate: [authGuard]
  },
  {
    path: 'settings/profile',
    loadComponent: () => import('./features/user/profile-settings/profile-settings.component').then(m => m.ProfileSettingsComponent),
    canActivate: [authGuard]
  },
  {
    path: 'settings/profile/verify',
    loadComponent: () => import('./features/user/profile-settings/components/verify-profile/verify-profile.component').then(m => m.VerifyProfileComponent),
    canActivate: [authGuard]
  },
  {
    path: 'settings/history',
    loadComponent: () => import('./features/user/chat-history/chat-history.component').then(m => m.ChatHistoryComponent),
    canActivate: [authGuard]
  },
  {
    path: 'settings/payments',
    loadComponent: () => import('./features/user/payment-history/payment-history.component').then(m => m.PaymentHistoryComponent),
    canActivate: [authGuard]
  },
  {
    path: '**',
    redirectTo: ''
  }
];

const env = (window as any).__env || {};
const sentryDsn = env.SENTRY_DSN_FRONTEND;

if (sentryDsn) {
  Sentry.init({
    dsn: sentryDsn,
    environment: env.SENTRY_ENVIRONMENT || 'production',
    release: env.SENTRY_RELEASE || undefined,
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.replayIntegration({
        maskAllText: true,
        maskAllInputs: true,
        blockAllMedia: true
      }),
    ],
    tracesSampleRate: 0.1,
    replaysSessionSampleRate: 0.1,
    replaysOnErrorSampleRate: 1.0,
  });
}

const sentryProvider = sentryDsn ? [
  {
    provide: ErrorHandler,
    useValue: Sentry.createErrorHandler({
      showDialog: false,
    }),
  }
] : [];

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideRouter(
      routes,
      withInMemoryScrolling({
        anchorScrolling: 'enabled',
        scrollPositionRestoration: 'enabled'
      }),
      withRouterConfig({
        onSameUrlNavigation: 'reload'
      })
    ),
    ...sentryProvider
  ]
};
