import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { environment } from '../config/environment';
import { ToastService } from './toast.service';
import { Router } from '@angular/router';
import { AuthService } from '../auth/auth.service';

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
          name: '', // Optional: Fill from user profile
          email: '',
          contact: ''
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
