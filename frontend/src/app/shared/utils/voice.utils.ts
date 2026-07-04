import { Voice } from '../../core/services/tts.service';


export function getVoiceTypeLabel(voice: Voice | undefined, activeFilter: string): string {
  if (!voice) return '';
  if (voice.isElevenLabs) return 'Natural';
  if (voice.isSarvam) return 'Indian';
  return 'Standard';
}

export function getVoiceLabelFromType(voiceType: string): string {
  switch (voiceType) {
    case 'NATURAL': return 'Natural';
    case 'INDIAN': return 'Indian';
    case 'NEURAL': return 'Neural';
    default: return 'Standard';
  }
}

export function getVoiceTypeClass(voice: Voice | undefined, activeFilter: string): string {
  if (!voice) return '';
  if (voice.isElevenLabs) return 'text-purple-500';
  if (voice.isSarvam) return 'text-orange-500';
  return 'text-primary-400';
}

export function getVoiceClassFromType(voiceType: string): string {
  switch (voiceType) {
    case 'NATURAL': return 'text-purple-500';
    case 'INDIAN': return 'text-orange-500';
    case 'NEURAL': return 'text-blue-500';
    default: return 'text-primary-400';
  }
}

/**
 * Derives the classification string used for historical logging.
 * Simplified for frontend; backend now performs detailed derivation.
 */
export function deriveVoiceType(voice: Voice | undefined): string {
  if (!voice) return 'STANDARD';
  if (voice.isElevenLabs) return 'NATURAL';
  if (voice.isSarvam) return 'INDIAN';
  return 'STANDARD';
}
