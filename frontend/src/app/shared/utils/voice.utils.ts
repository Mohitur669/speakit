import { Voice } from '../../core/services/tts.service';

export type VoiceFilter = 'Standard' | 'Neural' | 'Natural' | 'All';

export function getVoiceTypeLabel(voice: Voice | undefined, activeFilter: string): string {
  if (!voice) return '';
  if (activeFilter === 'Standard') return 'Standard';
  if (voice.isElevenLabs) return 'Natural AI';
  if (voice.isNeural) return 'Neural';
  return 'Standard';
}

export function getVoiceTypeClass(voice: Voice | undefined, activeFilter: string): string {
  if (!voice) return '';
  if (activeFilter === 'Standard') return 'text-primary-400';
  if (voice.isElevenLabs) return 'text-purple-500';
  if (voice.isNeural) return 'text-accent-500';
  return 'text-primary-400';
}

/**
 * Derives the classification string used for historical logging.
 */
export function deriveVoiceType(voice: Voice | undefined, activeFilter: string): string {
  if (!voice) return 'STANDARD';
  const label = getVoiceTypeLabel(voice, activeFilter);
  if (label === 'Natural AI') return 'NATURAL';
  if (label === 'Neural') return 'NEURAL';
  return 'STANDARD';
}
