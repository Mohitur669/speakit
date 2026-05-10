import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter, Routes } from '@angular/router';
import { LandingComponent } from './landing/landing';
import { LoginComponent } from './auth/login';
import { SignupComponent } from './auth/signup';
import { TtsComponent } from './tts/tts';
import { authGuard } from './services/auth.guard';
import { authInterceptor } from './services/auth.interceptor';

const routes: Routes = [
  { path: '', component: LandingComponent },
  { path: 'login', component: LoginComponent },
  { path: 'signup', component: SignupComponent },
  { path: 'tts', component: TtsComponent, canActivate: [authGuard] },
  { path: '**', redirectTo: '' }
];

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideRouter(routes)
  ]
};
