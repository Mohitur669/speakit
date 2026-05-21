import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ViewportScroller } from '@angular/common';
import { ToastComponent } from './shared/components/toast/toast.component';

@Component({
	selector: 'app-root',
	standalone: true,
	imports: [RouterOutlet, ToastComponent],
	template: `
    <router-outlet></router-outlet>
    <app-toast></app-toast>
  `
})
export class App {
  private scroller = inject(ViewportScroller);

  constructor() {
    this.scroller.setOffset([0, 64]);
  }
}
