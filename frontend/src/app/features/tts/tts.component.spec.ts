import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TtsComponent } from './tts.component';

describe('TtsComponent', () => {
  let component: TtsComponent;
  let fixture: ComponentFixture<TtsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TtsComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(TtsComponent);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});