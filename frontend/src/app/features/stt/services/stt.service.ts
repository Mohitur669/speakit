import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../../environments/environment';
import { SttResult } from '../models/stt.models';

@Injectable({
  providedIn: 'root'
})
export class SttService {
  private http = inject(HttpClient);
  private apiUrl = `${environment.apiUrl}/api/stt`;

  /**
   * Transcribes an audio file using the backend API.
   * @param file The audio file to transcribe.
   * @param language Optional language code.
   * @param provider Optional preferred provider engine.
   */
  transcribe(file: File, language?: string, provider?: string): Observable<SttResult> {
    const formData = new FormData();
    formData.append('file', file);
    if (language) {
      formData.append('language', language);
    }
    if (provider) {
      formData.append('provider', provider);
    }
    return this.http.post<SttResult>(`${this.apiUrl}/transcribe`, formData);
  }

  /**
   * Transcribes a recorded live voice audio blob.
   * @param blob The recorded audio blob.
   * @param language Optional language code.
   * @param provider Optional preferred provider.
   */
  transcribeLive(blob: Blob, language?: string, provider?: string): Observable<SttResult> {
    const formData = new FormData();
    const filename = blob.type.includes('mp4') ? 'audio.m4a' : 'audio.webm';
    formData.append('file', blob, filename);
    if (language) {
      formData.append('language', language);
    }
    if (provider) {
      formData.append('provider', provider);
    }
    return this.http.post<SttResult>(`${this.apiUrl}/transcribe-live`, formData);
  }

  /**
   * Translates text to a target language.
   */
  translate(text: string, sourceLanguage: string, targetLanguage: string): Observable<{ translatedText: string; sourceLanguage: string }> {
    return this.http.post<{ translatedText: string; sourceLanguage: string }>(`${this.apiUrl}/translate`, {
      text,
      sourceLanguage,
      targetLanguage
    });
  }
}
