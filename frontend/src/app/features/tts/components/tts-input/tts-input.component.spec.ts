import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TtsInputComponent } from './tts-input.component';
import { FormsModule } from '@angular/forms';

describe('TtsInputComponent', () => {
  let component: TtsInputComponent;
  let fixture: ComponentFixture<TtsInputComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TtsInputComponent, FormsModule]
    }).compileComponents();

    fixture = TestBed.createComponent(TtsInputComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
