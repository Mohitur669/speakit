import { WritableSignal } from '@angular/core';

/**
 * Manages resend OTP button cooldown timer.
 */
export function runResendCooldown(
  cooldownSignal: WritableSignal<number>,
  getCurrentTimerId: () => any,
  setTimerId: (id: any) => void
): void {
  cooldownSignal.set(60);
  const currentId = getCurrentTimerId();
  if (currentId) clearInterval(currentId);
  
  const id = setInterval(() => {
    const val = cooldownSignal() - 1;
    cooldownSignal.set(val);
    if (val <= 0) {
      clearInterval(id);
    }
  }, 1000);
  setTimerId(id);
}
