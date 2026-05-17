import { Injectable, isDevMode } from '@angular/core';
import { environment } from '../../../environments/environment';

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  OFF = 4
}

/**
 * Centralized, production-grade logging service.
 * 
 * Features:
 * - Environment-aware (suppresses logs based on configuration)
 * - Structured formatting
 * - Prevents sensitive data leakage
 * - Single point of control for frontend observability
 */
@Injectable({
  providedIn: 'root'
})
export class LoggerService {
  private readonly level: LogLevel;

  constructor() {
    // Default to DEBUG in dev, WARN in production unless overridden
    const envLevel = (window as any).__env?.LOG_LEVEL;
    if (envLevel !== undefined) {
      this.level = this.parseLogLevel(envLevel);
    } else {
      this.level = environment.production ? LogLevel.WARN : LogLevel.DEBUG;
    }
  }

  private parseLogLevel(value: string | number): LogLevel {
    if (typeof value === 'number') return value;
    switch (value.toUpperCase()) {
      case 'DEBUG': return LogLevel.DEBUG;
      case 'INFO': return LogLevel.INFO;
      case 'WARN': return LogLevel.WARN;
      case 'ERROR': return LogLevel.ERROR;
      case 'OFF': return LogLevel.OFF;
      default: return LogLevel.INFO;
    }
  }

  /**
   * Logs low-level debugging information. 
   * These are automatically stripped or suppressed in production.
   */
  debug(message: string, ...args: any[]): void {
    if (this.canLog(LogLevel.DEBUG)) {
      console.debug(`[DEBUG] ${message}`, ...this.sanitize(args));
    }
  }

  /**
   * Logs significant application milestones or workflow starts.
   */
  info(message: string, ...args: any[]): void {
    if (this.canLog(LogLevel.INFO)) {
      console.info(`[INFO] ${message}`, ...this.sanitize(args));
    }
  }

  /**
   * Logs recoverable issues or potential configuration problems.
   */
  warn(message: string, ...args: any[]): void {
    if (this.canLog(LogLevel.WARN)) {
      console.warn(`[WARN] ${message}`, ...this.sanitize(args));
    }
  }

  /**
   * Logs critical failures, exceptions, or broken workflows.
   */
  error(message: string, error?: any, ...args: any[]): void {
    if (this.canLog(LogLevel.ERROR)) {
      console.error(`[ERROR] ${message}`, error, ...this.sanitize(args));
    }
  }

  private canLog(targetLevel: LogLevel): boolean {
    return targetLevel >= this.level;
  }

  /**
   * Prevents accidental logging of sensitive fields like tokens or passwords.
   */
  private sanitize(args: any[]): any[] {
    const sensitiveKeys = ['token', 'password', 'jwt', 'secret', 'key'];
    
    return args.map(arg => {
      if (typeof arg !== 'object' || arg === null) return arg;
      
      const sanitized = { ...arg };
      sensitiveKeys.forEach(key => {
        if (key in sanitized) sanitized[key] = '[REDACTED]';
      });
      return sanitized;
    });
  }
}
