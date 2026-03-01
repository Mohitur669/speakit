import { TestBed } from '@angular/core/testing';

import { Tts } from './tts';

describe('Tts', () => {
  let service: Tts;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(Tts);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
