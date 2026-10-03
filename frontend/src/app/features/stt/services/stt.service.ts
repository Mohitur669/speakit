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
   * @param mode Optional processing mode ('transcribe', 'translate', 'codemix', 'translit').
   */
  transcribe(file: File, language?: string, provider?: string, mode?: string): Observable<SttResult> {
    const formData = new FormData();
    formData.append('file', file);
    if (language) {
      formData.append('language', language);
    }
    if (provider) {
      formData.append('provider', provider);
    }
    if (mode) {
      formData.append('mode', mode);
    }
    return this.http.post<SttResult>(`${this.apiUrl}/transcribe`, formData);
  }

  /**
   * Transcribes a recorded live voice audio blob.
   * @param blob The recorded audio blob.
   * @param language Optional language code.
   * @param provider Optional preferred provider.
   * @param mode Optional processing mode ('transcribe', 'translate', 'codemix', 'translit').
   */
  transcribeLive(blob: Blob, language?: string, provider?: string, mode?: string): Observable<SttResult> {
    const formData = new FormData();
    const filename = blob.type.includes('mp4') ? 'audio.m4a' : 'audio.webm';
    formData.append('file', blob, filename);
    if (language) {
      formData.append('language', language);
    }
    if (provider) {
      formData.append('provider', provider);
    }
    if (mode) {
      formData.append('mode', mode);
    }
    return this.http.post<SttResult>(`${this.apiUrl}/transcribe-live`, formData);
  }

  /**
   * Translates text to a target language.
   */
  translate(text: string, sourceLanguage: string, targetLanguage: string, mode?: string): Observable<{ translatedText: string; sourceLanguage: string }> {
    return this.http.post<{ translatedText: string; sourceLanguage: string }>(`${this.apiUrl}/translate`, {
      text,
      sourceLanguage,
      targetLanguage,
      mode
    });
  }

  /**
   * Transliterates text across scripts.
   */
  transliterate(text: string, sourceLanguage?: string, targetLanguage?: string): Observable<{ transliteratedText: string; sourceLanguage: string; targetLanguage: string }> {
    return this.http.post<{ transliteratedText: string; sourceLanguage: string; targetLanguage: string }>(`${this.apiUrl}/transliterate`, {
      text,
      sourceLanguage,
      targetLanguage
    });
  }
}
