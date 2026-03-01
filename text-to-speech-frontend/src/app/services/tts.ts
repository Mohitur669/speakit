import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Voice {
  id: string;
  name: string;
  gender: string;
}

@Injectable({ providedIn: 'root' })
export class TtsService {
  private baseUrl = 'http://localhost:8080/api/tts';

  constructor(private http: HttpClient) {}

  synthesize(text: string, voiceId: string): Observable<Blob> {
    return this.http.post(
      `${this.baseUrl}/synthesize`,
      { text, voiceId, outputFormat: 'mp3' },
      { responseType: 'blob' }
    );
  }

  getVoices(): Observable<Voice[]> {
    return this.http.get<Voice[]>(`${this.baseUrl}/voices`);
  }
}