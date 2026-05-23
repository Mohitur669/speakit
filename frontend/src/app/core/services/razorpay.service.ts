import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { environment } from '../config/environment';
import { ToastService } from './toast.service';
import { Router } from '@angular/router';
import { AuthService } from '../auth/auth.service';
import { parsePhoneNumberFromString } from 'libphonenumber-js';

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
    // INDUSTRY STANDARD: Handle guest users by redirecting to signup
    if (!this.authService.isLoggedIn()) {
      this.toast.show('Please create an account to upgrade to ' + planType, 'info');
      // Store intent in session storage or just redirect with query param
      this.router.navigate(['/signup'], { queryParams: { plan: planType } });
      return;
    }

    const isScriptLoaded = await this.loadScript('https://checkout.razorpay.com/v1/checkout.js');
    if (!isScriptLoaded) {
      this.toast.show('Failed to load payment gateway. Please check your connection.', 'error');
      return;
    }

    try {
      const user = this.authService.currentUser();
      const email = this.authService.currentUserEmail();
      const phoneRaw = this.authService.currentUserPhone() || '';
      
      // Smart Phone Cleaning for Razorpay
      let phone = phoneRaw.replace(/\D/g, ''); // Digits only by default
      
      try {
        const parsed = parsePhoneNumberFromString(phoneRaw);
        if (parsed) {
          // ALWAYS include the '+' prefix for Razorpay.
          // This allows the modal to correctly auto-select the country flag
          // and populate the local number field.
          phone = parsed.format('E.164');
        } else if (phoneRaw && !phoneRaw.startsWith('+')) {
          // Fallback if parsing fails but it's a numeric string
          phone = '+' + phoneRaw.replace(/\D/g, '');
        }
      } catch (e) {
        console.warn('[Razorpay] Phone parsing failed, using raw digits:', e);
      }

      console.log('[Razorpay] Initiating payment for:', { user, email, phone });

      // 1. Create Order on Backend
      const orderRes: any = await firstValueFrom(
        this.http.post(`${environment.apiUrl}/api/v1/payments/create-order`, {
          planType,
          amount,
          currency: 'INR'
        })
      );

      // 2. Open Razorpay Checkout
      const options = {
        key: orderRes.keyId,
        amount: orderRes.amount,
        currency: orderRes.currency,
        name: 'SpeakIT',
        description: `${planType} Plan Subscription`,
        order_id: orderRes.orderId,
        handler: async (response: any) => {
          await this.verifyPayment(response);
        },
        prefill: {
          name: user || '',
          email: email || '',
          contact: phone || ''
        },
        theme: {
          color: '#3B82F6'
        }
      };

      const rzp = new Razorpay(options);
      rzp.on('payment.failed', (response: any) => {
        this.toast.show('Payment failed: ' + response.error.description, 'error');
      });
      rzp.open();

    } catch (error) {
      console.error('Payment initiation error', error);
      this.toast.show('Failed to initiate payment. Please try again.', 'error');
    }
  }

  private async verifyPayment(razorpayResponse: any) {
    try {
      await firstValueFrom(
        this.http.post(`${environment.apiUrl}/api/v1/payments/verify`, {
          razorpayOrderId: razorpayResponse.razorpay_order_id,
          razorpayPaymentId: razorpayResponse.razorpay_payment_id,
          razorpaySignature: razorpayResponse.razorpay_signature
        }, { responseType: 'text' })
      );

      this.toast.show('Payment successful! Your subscription is now active.', 'success');
      
      // Refresh user status to show "Pro" badge immediately
      this.authService.refreshStatus();

      // Redirect or refresh user state
      this.router.navigate(['/tts']);
      
    } catch (error) {
      console.error('Payment verification error', error);
      this.toast.show('Payment verification failed. Please contact support.', 'error');
    }
  }
}
