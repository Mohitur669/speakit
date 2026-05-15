/**
 * HTTP interceptor injecting JWT Bearer token into
 * outgoing API requests for authenticated endpoints.
 */
import { HttpInterceptorFn, HttpErrorResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { catchError, throwError } from 'rxjs';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const token = authService.token();

  let authReq = req;
  if (token) {
    authReq = req.clone({
      setHeaders: { Authorization: `Bearer ${token}` }
    });
  }

  return next(authReq).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401 || error.status === 403) {
        const reason = error.headers.get('X-Logout-Reason');
        const message = reason === 'MULTI_LOGIN' 
          ? 'Another login detected' 
          : 'Session expired';
        authService.logout(message);
      }
      return throwError(() => error);
    })
  );
};