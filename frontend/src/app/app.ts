import { Component } from '@angular/core';
import { TtsComponent } from './tts/tts';

@Component({
	selector: 'app-root',
	standalone: true,
	imports: [TtsComponent],
	template: `<app-tts></app-tts>`
})
export class App {}