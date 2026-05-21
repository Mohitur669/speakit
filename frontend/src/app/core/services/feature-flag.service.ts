import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../config/environment';
import { firstValueFrom } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class FeatureFlagService {
  private http = inject(HttpClient);
  private apiUrl = `${environment.apiUrl}/api/system-parameters`;

  // Reactive state for flags (cached for UI toggles)
  private flags = signal<Map<string, string>>(new Map());

  /**
   * Initializes common UI flags. Use this for stable features.
   */
  async init(names: string[]) {
    try {
      const res = await firstValueFrom(
        this.http.get<Record<string, string>>(`${this.apiUrl}/bulk`, {
          params: { names: names.join(',') }
        })
      );
      
      const newFlags = new Map(Object.entries(res));
      this.flags.set(newFlags);
    } catch (error) {
      console.error('Failed to load feature flags', error);
    }
  }

  /**
   * Synchronously checks if a feature is enabled from the initialized state.
   */
  isEnabled(name: string): boolean {
    return this.flags().get(name) === 'true';
  }

  /**
   * Fetches a parameter LIVE from the database. 
   * Use this for critical items like prices and limits to avoid stale cache.
   */
  async getLive(name: string, defaultValue: string = ''): Promise<string> {
    try {
      return await firstValueFrom(
        this.http.get(`${this.apiUrl}/live/${name}`, { 
          params: { defaultValue }, 
          responseType: 'text' 
        })
      );
    } catch (error) {
      return defaultValue;
    }
  }

  async getLiveNumber(name: string, defaultValue: number = 0): Promise<number> {
    const val = await this.getLive(name, String(defaultValue));
    return Number(val) || defaultValue;
  }

  /**
   * Returns a cached parameter value.
   */
  getCached(name: string, defaultValue: string = ''): string {
    return this.flags().get(name) || defaultValue;
  }
}
