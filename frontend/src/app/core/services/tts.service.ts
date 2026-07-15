/**
 * Handles text-to-speech API communication, voice metadata fetching,
 * audio synthesis streams, and client-side cache management.
 * 
 * Optimized for:
 * - Reduced API latency via 24-hour local caching of voice options
 * - Robust error handling and type validation
 * - Dynamic environment configuration
 */
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of, tap, catchError, map } from 'rxjs';
import { environment } from '../../../environments/environment';
import { LoggerService } from './logger.service';

export interface Voice {
  id: string;
  name: string;
  gender: string;
  isElevenLabs?: boolean;
  isSarvam?: boolean;
  languageCode?: string;
}

export interface TtsUsage {
  plan: string;
  dailyCount: number;
  dailyLimit: number;
}

interface CachedVoices {
  voices: Voice[];
  timestamp: number;
}

const VOICES_CACHE_KEY = 'tts_voices_cache';
const CACHE_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Type guard to safely validate raw API objects as valid Voice entities.
 */
function isVoice(obj: unknown): obj is Voice {
  return typeof obj === 'object' && obj !== null &&
    'id' in obj && typeof (obj as Voice).id === 'string' &&
    'name' in obj && typeof (obj as Voice).name === 'string';
}

/**
 * Type guard to validate arrays of Voice entities.
 */
function isVoiceArray(obj: unknown): obj is Voice[] {
  return Array.isArray(obj) && (obj.length === 0 || isVoice(obj[0]));
}

export interface TtsHistoryDto {
  id: number;
  voiceId: string;
  voiceName: string;
  voiceType: 'STANDARD' | 'NEURAL' | 'NATURAL' | 'INDIAN';
  outputFormat: string;
  characterCount: number;
  textSnippet: string;
  createdAt: string;
}

export interface PaginatedHistory {
  content: TtsHistoryDto[];
  page: {
    size: number;
    totalElements: number;
    totalPages: number;
    number: number;
  };
}

@Injectable({ providedIn: 'root' })
export class TtsService {
  private baseUrl: string;
  private historyUrl: string;
  private voicesCache: Voice[] | null = null;
  private logger = inject(LoggerService);

  constructor(private http: HttpClient) {
    const env = (window as { __env?: { API_URL?: string } }).__env;
    const apiRoot = (env?.API_URL || environment.apiUrl || 'http://localhost:8080').replace(/\/$/, '');
    this.baseUrl = `${apiRoot}/api/tts`;
    this.historyUrl = `${apiRoot}/api/history`;
    this.loadCachedVoices();
  }

  getHistory(page = 0, size = 20): Observable<PaginatedHistory> {
    return this.http.get<PaginatedHistory>(this.historyUrl, {
      params: { page: page.toString(), size: size.toString() }
    });
  }

  deleteHistoryEntries(ids: number[]): Observable<void> {
    return this.http.delete<void>(`${this.historyUrl}/delete`, { body: ids });
  }

  clearAllHistory(): Observable<void> {
    return this.http.delete<void>(`${this.historyUrl}/clear-all`);
  }

  /**
   * Fetches the list of available TTS voices.
   * Utilizes an in-memory and localStorage cache to prevent redundant API calls
   * across page reloads within the 24-hour window.
   * 
   * @returns Observable resolving to an array of validated Voice objects.
   */
  getVoices(): Observable<Voice[]> {
    const planType = localStorage.getItem('planType') || 'FREE';
    const cacheKey = `${VOICES_CACHE_KEY}_${planType}`;

    // If cache matches but in-memory is empty, try loading it first
    if (!this.voicesCache) {
      this.loadCachedVoices();
    }

    if (this.voicesCache && this.voicesCache.length > 0) {
      return of(this.voicesCache);
    }

    return this.http.get<Voice[]>(`${this.baseUrl}/voices`).pipe(
      map((voices: unknown[]) => {
        if (!isVoiceArray(voices)) {
          this.logger.error('Validation failed for voices', voices);
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
        localStorage.setItem(cacheKey, JSON.stringify(cached));
      }),
      catchError(error => {
        this.logger.error('Error fetching voices', error);
        throw error;
      })
    );
  }

  /**
   * Internal mechanism to hydrate the voice cache from localStorage on startup.
   */
  private loadCachedVoices(): void {
    const planType = localStorage.getItem('planType') || 'FREE';
    const cacheKey = `${VOICES_CACHE_KEY}_${planType}`;
    const cached = localStorage.getItem(cacheKey);
    if (cached) {
      try {
        const data = JSON.parse(cached) as CachedVoices;
        if (Date.now() - data.timestamp < CACHE_DURATION_MS) {
          if (isVoiceArray(data.voices)) {
            this.voicesCache = data.voices;
            return;
          }
        }
        // Purge if expired or malformed
        localStorage.removeItem(cacheKey);
      } catch {
        localStorage.removeItem(cacheKey);
      }
    }
    this.voicesCache = null;
  }

  /**
   * Submits a request to synthesize text into an audio file.
   * Streams the response back as a Blob for immediate playback in the browser.
   */
  synthesize(
    text: string, 
    voiceId: string, 
    voiceName: string, 
    voiceType: string, 
    isElevenLabs = false, 
    isSarvam = false,
    languageCode?: string,
    format = 'mp3'
  ): Observable<Blob> {
    return this.http.post(
      `${this.baseUrl}/synthesize`, 
      { text, voiceId, voiceName, voiceType, outputFormat: format, isElevenLabs, isSarvam, languageCode },
      { responseType: 'blob' }
    );
  }

  getUsage(): Observable<TtsUsage> {
    return this.http.get<TtsUsage>(`${this.baseUrl}/usage`);
  }

  /**
   * Forcibly clears the local cache. Called during user logout to ensure
   * the next session fetches the correct voices based on their specific plan constraints.
   */
  clearCache(): void {
    this.voicesCache = null;
    const planType = localStorage.getItem('planType') || 'FREE';
    const cacheKey = `${VOICES_CACHE_KEY}_${planType}`;
    localStorage.removeItem(cacheKey);
    localStorage.removeItem(VOICES_CACHE_KEY);
  }
}
