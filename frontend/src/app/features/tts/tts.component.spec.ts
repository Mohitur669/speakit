import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { TtsComponent } from './tts.component';
import { ActivatedRoute, Router } from '@angular/router';
import { of } from 'rxjs';
import { TtsService } from '../../core/services/tts.service';
import { AuthService } from '../../core/auth/auth.service';
import { FeatureFlagService } from '../../core/services/feature-flag.service';
import { RazorpayService } from '../../core/services/razorpay.service';
import { ToastService } from '../../core/services/toast.service';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';

describe('TtsComponent', () => {
  let component: TtsComponent;
  let fixture: ComponentFixture<TtsComponent>;

  const mockActivatedRoute = {
    queryParams: of({}),
    snapshot: { queryParams: {} }
  };

  const mockRouter = {
    navigate: () => {},
    events: of()
  };

  const mockTtsService = {
    getVoices: () => of([]),
    getUsage: () => of({ dailyLimit: 10, dailyCount: 0 })
  };

  const mockAuthService = {
    isLoggedIn: () => false,
    currentPlanType: () => 'FREE',
    refreshStatus: () => of(null),
    currentUser: () => 'Test User',
    currentUserEmail: () => 'test@example.com',
    currentUserPhone: () => '+919999999999'
  };

  const mockFeatureFlagService = {
    getLiveNumber: () => Promise.resolve(100),
    getCached: () => '5'
  };

  const mockRazorpayService = {
    initiatePayment: () => {}
  };

  const mockToastService = {
    show: () => {},
    toastState: signal({ visible: false, type: 'info', message: '' })
  };

  beforeEach(async () => {
    Object.defineProperty(window, 'matchMedia', {
      writable: true,
      value: (query: string) => ({
        matches: false,
        media: query,
        onchange: null,
        addListener: () => {},
        removeListener: () => {},
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => false,
      }),
    });

    await TestBed.configureTestingModule({
      imports: [TtsComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: Router, useValue: mockRouter },
        { provide: TtsService, useValue: mockTtsService },
        { provide: AuthService, useValue: mockAuthService },
        { provide: FeatureFlagService, useValue: mockFeatureFlagService },
        { provide: RazorpayService, useValue: mockRazorpayService },
        { provide: ToastService, useValue: mockToastService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(TtsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});