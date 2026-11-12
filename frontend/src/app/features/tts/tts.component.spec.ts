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
    getUsage: () => of({ dailyLimit: 10, dailyCount: 0 }),
    analyzeDocument: (file: File) => of({
      documentToken: 'test-token-123',
      fileName: 'test.pdf',
      fileSizeBytes: 1024,
      pageCount: 3,
      wordCount: 150,
      characterCount: 900,
      estimatedDurationSeconds: 60,
      estimatedDurationFormatted: '1m',
      validationStatus: 'READY',
      warnings: []
    }),
    submitJob: (payload: any) => of({
      jobId: 'job-xyz-123',
      status: 'PROCESSING',
      progressPercent: 0,
      totalChunks: 2,
      completedChunks: 0
    }),
    getJobStatus: (id: string) => of({
      jobId: id,
      status: 'COMPLETED',
      progressPercent: 100,
      totalChunks: 2,
      completedChunks: 2,
      audioUrl: 'https://cdn.speakit.com/audio/book.mp3'
    })
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
    expect(component.mode()).toBe('text');
  });

  it('should switch between text and document mode', () => {
    component.switchMode('document');
    expect(component.mode()).toBe('document');
    component.switchMode('text');
    expect(component.mode()).toBe('text');
  });

  it('should reject non-PDF files during processFile', () => {
    const fakeFile = new File(['hello'], 'document.docx', { type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' });
    component.processFile(fakeFile);
    expect(component.documentError()).toContain('Only PDF documents');
    expect(component.selectedFile()).toBeNull();
  });

  it('should analyze valid PDF document and store analysis', () => {
    const validFile = new File(['%PDF-1.4 test'], 'sample.pdf', { type: 'application/pdf' });
    component.processFile(validFile);
    expect(component.selectedFile()).toBe(validFile);
    expect(component.documentAnalysis()).toBeTruthy();
    expect(component.documentAnalysis()?.fileName).toBe('test.pdf');
    expect(component.documentAnalysis()?.pageCount).toBe(3);
  });

  it('should reset document state on clearDocument', () => {
    const validFile = new File(['%PDF-1.4 test'], 'sample.pdf', { type: 'application/pdf' });
    component.processFile(validFile);
    component.clearDocument();
    expect(component.selectedFile()).toBeNull();
    expect(component.documentAnalysis()).toBeNull();
    expect(component.documentError()).toBeNull();
  });
});
