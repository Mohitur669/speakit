/**
 * Root application configuration defining global providers,
 * route structure, and lazy-loaded feature modules.
 */
import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter, withInMemoryScrolling, withRouterConfig } from '@angular/router';
import { authInterceptor } from './core/interceptors/auth.interceptor';
import { authGuard } from './core/guards/auth.guard';
import { provideAnimations } from '@angular/platform-browser/animations';

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
    loadComponent: () => import('./features/marketing/contact/contact.component').then(m => m.ContactComponent)
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
    path: 'tts',
    loadComponent: () => import('./features/tts').then(m => m.TtsComponent),
    canActivate: [authGuard]
  },
  {
    path: '**',
    redirectTo: ''
  }
];

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideAnimations(),
    provideRouter(
      routes,
      withInMemoryScrolling({
        anchorScrolling: 'enabled',
        scrollPositionRestoration: 'enabled'
      }),
      withRouterConfig({
        onSameUrlNavigation: 'reload'
      })
    )
  ]
};
