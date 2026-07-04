import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom, Observable } from 'rxjs';
import { environment } from '../config/environment';
import { ToastService } from './toast.service';
import { Router } from '@angular/router';
import { AuthService } from '../auth/auth.service';
import { parsePhoneNumberFromString } from 'libphonenumber-js';

export interface PaymentHistoryDto {
  id: number;
  planName: string;
  amount: number;
  currency: string;
  status: string;
  razorpayOrderId: string;
  createdAt: string;
}

export interface PaginatedPaymentHistory {
  content: PaymentHistoryDto[];
  page: {
    size: number;
    totalElements: number;
    totalPages: number;
    number: number;
  };
}

declare var Razorpay: any;

@Injectable({
  providedIn: 'root'
})
export class RazorpayService {
  private http = inject(HttpClient);
  private toast = inject(ToastService);
  private router = inject(Router);
  private authService = inject(AuthService);

  private loadScript(src: string): Promise<boolean> {

    return new Promise((resolve) => {
      if ((window as any).Razorpay) {
        resolve(true);
        return;
      }
      const script = document.createElement('script');
      script.src = src;
      script.onload = () => resolve(true);
      script.onerror = () => resolve(false);
      document.body.appendChild(script);
    });
  }

  async initiatePayment(planType: string, amount: number) {
    if (!this.authService.isLoggedIn()) {
      this.toast.show('Please create an account to upgrade to ' + planType, 'info');
      this.router.navigate(['/signup'], { queryParams: { plan: planType } });
      return;
    }

    const isScriptLoaded = await this.loadScript('https://checkout.razorpay.com/v1/checkout.js');
    if (!isScriptLoaded) {
      this.toast.show('Failed to load payment gateway. Please check your connection.', 'error');
      return;
    }

    try {
      // 1. Create Order on Backend
      const orderRes: any = await firstValueFrom(
        this.http.post(`${environment.apiUrl}/api/v1/payments/create-order`, {
          planType,
          amount,
          currency: 'INR'
        })
      );

      // 2. Open Razorpay Checkout (Standard Integration Step 1)
      const options = this.buildOrderOptions(planType, orderRes);
      const rzp = new Razorpay(options);
      
      rzp.on('payment.failed', (response: any) => this.handlePaymentFailure(response));
      rzp.open();

    } catch (error) {
      this.handlePaymentFailure(error);
    }
  }

  private buildOrderOptions(planType: string, orderRes: any): any {
    const user = this.authService.currentUser();
    const email = this.authService.currentUserEmail();
    const phoneRaw = this.authService.currentUserPhone() || '';
    
    /**
     * PRECISION PRE-FILL LOGIC (Based on Official Razorpay Docs)
     * For Indian merchant accounts:
     * 1. India (+91): Pass ONLY the 10-digit local number.
     * 2. International: Pass full E.164 (+CCXXXXXXXXXX).
     */
    let phone = phoneRaw.replace(/\D/g, ''); 
    
    try {
      const parsed = parsePhoneNumberFromString(phoneRaw);
      if (parsed) {
        if (parsed.country === 'IN') {
          // Passing 10 digits is most stable for Indian merchants
          phone = parsed.nationalNumber as string;
        } else {
          // Full E.164 required for International auto-detection
          phone = parsed.format('E.164');
        }
      }
    } catch (e) {
      console.warn('[Razorpay] Phone parsing failed, falling back to raw digits');
    }

    return {
      key: orderRes.keyId,
      subscription_id: orderRes.subscriptionId,
      name: 'SpeakIT',
      description: `${planType} Plan Subscription`,
      handler: async (response: any) => {
        await this.handlePaymentSuccess(response);
      },
      prefill: {
        name: user || '',
        email: email || '',
        contact: phone || ''
      },
      theme: {
        color: '#3B82F6'
      },
      modal: {
        confirm_close: true
      }
    };
  }

  private async handlePaymentSuccess(response: any): Promise<void> {
    await this.verifyPayment(response);
  }

  private handlePaymentFailure(error: any): void {
    console.error('Payment error', error);
    const description = error?.error?.description || 'Failed to process payment. Please try again.';
    this.toast.show(description, 'error');
  }


  private async verifyPayment(razorpayResponse: any) {
    try {
      await firstValueFrom(
        this.http.post(`${environment.apiUrl}/api/v1/payments/verify`, {
          razorpayOrderId: razorpayResponse.razorpay_order_id,
          razorpaySubscriptionId: razorpayResponse.razorpay_subscription_id,
          razorpayPaymentId: razorpayResponse.razorpay_payment_id,
          razorpaySignature: razorpayResponse.razorpay_signature
        }, { responseType: 'text' })
      );

      this.toast.show('Payment successful! Your subscription is now active.', 'success');
      
      // Wait for status refresh (clears voice cache) before navigating to studio
      await firstValueFrom(this.authService.refreshStatus());
      
      this.router.navigate(['/tts']);
      
    } catch (error) {
      console.error('Payment verification error', error);
      this.toast.show('Payment verification failed. Please contact support.', 'error');
    }
  }

  getPaymentHistory(page = 0, size = 20): Observable<PaginatedPaymentHistory> {
    const env = (window as { __env?: { API_URL?: string } }).__env;
    const apiRoot = (env?.API_URL || environment.apiUrl || 'http://localhost:8080').replace(/\/$/, '');
    return this.http.get<PaginatedPaymentHistory>(`${apiRoot}/api/v1/payments/history`, {
      params: { page: page.toString(), size: size.toString() }
    });
  }
}
