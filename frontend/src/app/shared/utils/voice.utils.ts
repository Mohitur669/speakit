import { Voice } from '../../core/services/tts.service';

export type VoiceFilter = 'Standard' | 'Natural' | 'All';

export function getVoiceTypeLabel(voice: Voice | undefined, activeFilter: string): string {
  if (!voice) return '';
  if (voice.isElevenLabs) return 'Natural';
  return 'Standard';
}

export function getVoiceTypeClass(voice: Voice | undefined, activeFilter: string): string {
  if (!voice) return '';
  if (voice.isElevenLabs) return 'text-purple-500';
  return 'text-primary-400';
}

/**
 * Derives the classification string used for historical logging.
 * Simplified for frontend; backend now performs detailed derivation.
 */
export function deriveVoiceType(voice: Voice | undefined): string {
  if (!voice) return 'STANDARD';
  if (voice.isElevenLabs) return 'NATURAL';
  return 'STANDARD';
}
