import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { tap, catchError } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface Voice {
  id: string;
  name: string;
  gender: string;
}

interface CachedVoices {
  voices: Voice[];
  timestamp: number;
}

const VOICES_CACHE_KEY = 'tts_voices_cache';
const CACHE_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

// Type guards for safe deserialization
function isVoice(obj: any): obj is Voice {
  return obj && typeof obj.id === 'string' && typeof obj.name === 'string' && typeof obj.gender === 'string';
}

function isVoiceArray(obj: any): obj is Voice[] {
  return Array.isArray(obj) && obj.every(isVoice);
}

@Injectable({ providedIn: 'root' })
export class TtsService {
  // Prefer runtime-injected API URL set by public/runtime-env.js (generated at build)
  private baseUrl: string;
  private voicesCache: Voice[] | null = null;

  constructor(private http: HttpClient) {
    const env = (window as any).__env;
    const apiRoot = (env?.API_URL || environment.apiUrl || 'http://localhost:8080').replace(/\/$/, '');
    this.baseUrl = `${apiRoot}/api/tts`;
    this.loadCachedVoices();
  }

  /**
   * Load voices from cache first, then fetch from API if not cached
   */
  getVoices(): Observable<Voice[]> {
    // Return in-memory cache if available
    if (this.voicesCache) {
      return of(this.voicesCache);
    }

    // Fetch from API and cache
    return this.http.get<Voice[]>(`${this.baseUrl}/voices`).pipe(
      tap(voices => {
        // Validate response
        if (!isVoiceArray(voices)) {
          throw new Error('Invalid voices data received from API');
        }
        // Store in-memory
        this.voicesCache = voices;
        // Persist to localStorage
        const cached: CachedVoices = {
          voices,
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

  /**
   * Load voices from localStorage cache on service initialization
   */
  private loadCachedVoices(): void {
    const cached = localStorage.getItem(VOICES_CACHE_KEY);
    if (cached) {
      try {
        const data = JSON.parse(cached) as CachedVoices;
        // Validate cache is not expired
        if (Date.now() - data.timestamp < CACHE_DURATION_MS) {
          // Validate data structure
          if (isVoiceArray(data.voices)) {
            this.voicesCache = data.voices;
            return;
          }
        }
        // Invalid or expired cache, clear it
        localStorage.removeItem(VOICES_CACHE_KEY);
      } catch (error) {
        console.warn('Failed to load cached voices:', error);
        localStorage.removeItem(VOICES_CACHE_KEY);
      }
    }
  }

  synthesize(text: string, voiceId: string, format: string = 'mp3'): Observable<Blob> {
    return this.http.post(
      `${this.baseUrl}/synthesize-stream`,
      { text, voiceId, outputFormat: format },
      { responseType: 'blob' }
    );
  }
}
