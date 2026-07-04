import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ProfileFormComponent } from './profile-form.component';
import { FormsModule } from '@angular/forms';
import { Subject } from 'rxjs';
import { Country } from '../../../../../shared/models/country.model';

describe('ProfileFormComponent', () => {
  let component: ProfileFormComponent;
  let fixture: ComponentFixture<ProfileFormComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ProfileFormComponent, FormsModule]
    }).compileComponents();

    fixture = TestBed.createComponent(ProfileFormComponent);
    component = fixture.componentInstance;
    
    // Provide required Inputs to avoid null injection/binding errors
    component.usernameSubject = new Subject<string>();
    component.emailSubject = new Subject<string>();
    component.phoneSubject = new Subject<string>();
    component.selectedCountry = { name: 'India', code: 'IN', flag: '🇮🇳' };

    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should emit selectedCountryChange when country changes', () => {
    const newCountry: Country = { name: 'United States', code: 'US', flag: '🇺🇸' };
    let emitted: Country | undefined;
    
    component.selectedCountryChange.subscribe(c => emitted = c);
    component.onCountryChange(newCountry);
    
    expect(emitted).toEqual(newCountry);
    expect(component.selectedCountry).toEqual(newCountry);
  });
});
