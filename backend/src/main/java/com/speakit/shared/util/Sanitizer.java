package com.speakit.shared.util;

import com.speakit.tts.exception.SpeechConversionException;
import org.jsoup.Jsoup;
import org.jsoup.safety.Safelist;
import org.springframework.lang.Nullable;
import java.util.regex.Pattern;

public class Sanitizer {
    
    // Pattern to detect common LLM prompt injection attempts or system instruction overrides
    private static final Pattern ABUSE_PATTERN = Pattern.compile(
            "(?i)(ignore previous instructions|act as a|system prompt|you are now|developer mode|override instructions)"
    );

    /**
     * Sanitizes a string by removing all HTML tags and trimming whitespace.
     * Also performs heuristic checks for abuse patterns.
     */
    @Nullable
    public static String sanitize(@Nullable String input) {
        if (input == null) return null;
        
        String cleaned = Jsoup.clean(input, Safelist.none()).trim();
        
        // Security: Block common meta-prompt injection vectors
        // Even though Polly isn't an LLM, this acts as a honeypot/filter for bots 
        // scraping the internet for vulnerable AI endpoints.
        if (ABUSE_PATTERN.matcher(cleaned).find()) {
            throw new SpeechConversionException("Request blocked: Suspicious input pattern detected.");
        }

        return cleaned;
    }
}
