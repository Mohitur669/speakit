/**
 * Handles text-to-speech API communication, voice fetching,
 * audio synthesis requests, and 24-hour voice cache management.
 */
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of, tap, catchError, map } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Voice {
  id: string;
  name: string;
  gender: string;
  isNeural: boolean;
  isStandard: boolean;
}

interface CachedVoices {
  voices: Voice[];
  timestamp: number;
}

const VOICES_CACHE_KEY = 'tts_voices_cache';
const CACHE_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

function isVoice(obj: unknown): obj is Voice {
  return typeof obj === 'object' && obj !== null &&
    'id' in obj && typeof (obj as Voice).id === 'string' &&
    'name' in obj && typeof (obj as Voice).name === 'string';
}

function isVoiceArray(obj: unknown): obj is Voice[] {
  return Array.isArray(obj) && (obj.length === 0 || isVoice(obj[0]));
}

@Injectable({ providedIn: 'root' })
export class TtsService {
  private baseUrl: string;
  private voicesCache: Voice[] | null = null;

  constructor(private http: HttpClient) {
    const env = (window as { __env?: { API_URL?: string } }).__env;
    const apiRoot = (env?.API_URL || environment.apiUrl || 'http://localhost:8080').replace(/\/$/, '');
    this.baseUrl = `${apiRoot}/api/tts`;
    this.loadCachedVoices();
  }

  getVoices(): Observable<Voice[]> {
    if (this.voicesCache && this.voicesCache.length > 0) {
      return of(this.voicesCache);
    }

    return this.http.get<Voice[]>(`${this.baseUrl}/voices`).pipe(
      map((voices: unknown[]) => {
        if (!isVoiceArray(voices)) {
          console.error('Validation failed for voices:', voices);
          throw new Error('Invalid voices data received from API');
        }
        return voices as Voice[];
      }),
      tap((voices: Voice[]) => {
        this.voicesCache = voices;

        const cached: CachedVoices = {
          voices: this.voicesCache,
          timestamp: Date.now(),
        };
        localStorage.setItem(VOICES_CACHE_KEY, JSON.stringify(cached));
      }),
      catchError(error => {
        console.error('Error fetching voices:', error);
        throw error;
      })
    );
  }

  private loadCachedVoices(): void {
    const cached = localStorage.getItem(VOICES_CACHE_KEY);
    if (cached) {
      try {
        const data = JSON.parse(cached) as CachedVoices;
        if (Date.now() - data.timestamp < CACHE_DURATION_MS) {
          if (isVoiceArray(data.voices)) {
            this.voicesCache = data.voices;
            return;
          }
        }
        localStorage.removeItem(VOICES_CACHE_KEY);
      } catch {
        localStorage.removeItem(VOICES_CACHE_KEY);
      }
    }
  }

  synthesize(text: string, voiceId: string, format = 'mp3'): Observable<Blob> {
    return this.http.post(
      `${this.baseUrl}/synthesize-stream`,
      { text, voiceId, outputFormat: format },
      { responseType: 'blob' }
    );
  }

  clearCache(): void {
    this.voicesCache = null;
    localStorage.removeItem(VOICES_CACHE_KEY);
  }
}