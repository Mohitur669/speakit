export interface SarvamVoiceConfig {
  speakers: string[];
  languages: { code: string; name: string }[];
  female_speakers: string[];
}

export const SARVAM_VOICES: SarvamVoiceConfig = {
  speakers: [
    "aditya", "ritu", "ashutosh", "priya", "neha", "rahul", "pooja", "rohan", 
    "simran", "kavya", "amit", "dev", "ishita", "shreya", "ratan", "varun", 
    "manan", "sumit", "roopa", "kabir", "aayan", "shubh", "advait", "anand", 
    "tanya", "tarun", "sunny", "mani", "gokul", "vijay", "shruti", "suhani", 
    "mohit", "kavitha", "rehan", "soham", "rupali", "niharika"
  ],
  languages: [
    { code: "hi-IN", name: "Hindi" },
    { code: "bn-IN", name: "Bengali" },
    { code: "mr-IN", name: "Marathi" },
    { code: "ta-IN", name: "Tamil" },
    { code: "te-IN", name: "Telugu" },
    { code: "kn-IN", name: "Kannada" },
    { code: "ml-IN", name: "Malayalam" },
    { code: "gu-IN", name: "Gujarati" },
    { code: "pa-IN", name: "Punjabi" },
    { code: "or-IN", name: "Odia" }
  ],
  female_speakers: [
    "ritu", "priya", "neha", "pooja", "simran", "kavya", "ishita", "shreya", 
    "roopa", "tanya", "shruti", "suhani", "kavitha", "rupali", "niharika"
  ]
};

export const DEFAULT_SPEAKERS: Record<string, string> = {
  'hi-IN': 'aditya',
  'bn-IN': 'ritu',
  'mr-IN': 'ashutosh',
  'ta-IN': 'priya',
  'te-IN': 'neha',
  'kn-IN': 'kavya',
  'ml-IN': 'rohan',
  'gu-IN': 'amit',
  'pa-IN': 'simran',
  'or-IN': 'ishita'
};

export function capitalize(str: string): string {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}

export function isFemale(speaker: string): boolean {
  return SARVAM_VOICES.female_speakers.includes(speaker.toLowerCase());
}

export function normalizeLanguageCode(langCode: string): string {
  if (!langCode) return '';
  const clean = langCode.trim().toLowerCase();
  if (clean === 'hi' || clean.startsWith('hi-')) return 'hi-IN';
  if (clean === 'bn' || clean.startsWith('bn-') || clean.startsWith('ben')) return 'bn-IN';
  if (clean === 'mr' || clean.startsWith('mr-') || clean.startsWith('mar')) return 'mr-IN';
  if (clean === 'ta' || clean.startsWith('ta-') || clean.startsWith('tam')) return 'ta-IN';
  if (clean === 'te' || clean.startsWith('te-') || clean.startsWith('tel')) return 'te-IN';
  if (clean === 'kn' || clean.startsWith('kn-') || clean.startsWith('kan')) return 'kn-IN';
  if (clean === 'ml' || clean.startsWith('ml-') || clean.startsWith('mal')) return 'ml-IN';
  if (clean === 'gu' || clean.startsWith('gu-') || clean.startsWith('guj')) return 'gu-IN';
  if (clean === 'pa' || clean.startsWith('pa-') || clean.startsWith('pan')) return 'pa-IN';
  if (clean === 'or' || clean.startsWith('or-') || clean.startsWith('odi')) return 'or-IN';
  if (clean === 'en' || clean.startsWith('en-')) return 'en-IN';
  return langCode;
}

export function getSpeakersForLanguage(langCode: string) {
  if (!langCode) return [];
  const normalized = normalizeLanguageCode(langCode);
  
  // Find match in languages
  const supported = SARVAM_VOICES.languages.find(l => l.code.toLowerCase() === normalized.toLowerCase());
  if (!supported) return [];
  
  return SARVAM_VOICES.speakers.map(speaker => ({
    value: speaker,
    label: `${capitalize(speaker)} (${isFemale(speaker) ? 'Female' : 'Male'})`
  }));
}
