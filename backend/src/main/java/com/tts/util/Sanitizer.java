package com.tts.util;

import org.jsoup.Jsoup;
import org.jsoup.safety.Safelist;

public class Sanitizer {
    
    /**
     * Sanitizes a string by removing all HTML tags and trimming whitespace.
     */
    public static String sanitize(String input) {
        if (input == null) return null;
        return Jsoup.clean(input, Safelist.none()).trim();
    }
}
