package com.speakit.tts.controller;

import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import com.speakit.tts.service.SystemParameterService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/system-parameters")
@RequiredArgsConstructor
public class SystemParameterController {

    private final SystemParameterService systemParameterService;
    
    // Safety Whitelist: Only these parameters can be queried via the public API
    private static final java.util.Set<String> PUBLIC_WHITELIST = java.util.Set.of(
        "SYSTEM_STATUS", 
        "FREE_PLAN_SYNTHESIZE_LIMIT",
        "PRO_PLAN_PRICE_INR",
        "PRO_PLUS_PLAN_PRICE_INR",
        "ENTERPRISE_PLAN_PRICE_INR",
        "MAX_FREE_CHARACTERS",
        "MAX_PRO_CHARACTERS",
        "MAX_PRO_PLUS_CHARACTERS",
        "MAX_ENTERPRISE_CHARACTERS",
        "ENABLE_RAZORPAY",
        "SHOW_BETA_FEATURES",
        "FREE_PLAN_FEATURES",
        "PRO_PLAN_FEATURES",
        "PRO_PLUS_PLAN_FEATURES",
        "ENTERPRISE_PLAN_FEATURES"
    );

    @RateLimited(action = RateLimitAction.LIVE_PARAM)
    @GetMapping("/cached/{name}")
    public ResponseEntity<String> getCachedParameter(@PathVariable String name, @RequestParam(defaultValue = "") String defaultValue) {
        if (!PUBLIC_WHITELIST.contains(name)) {
            return ResponseEntity.status(403).build();
        }
        return ResponseEntity.ok(systemParameterService.getCachedParameter(name, defaultValue));
    }

    @RateLimited(action = RateLimitAction.LIVE_PARAM)
    @GetMapping("/live/{name}")
    public ResponseEntity<String> getLiveParameter(@PathVariable String name, @RequestParam(defaultValue = "") String defaultValue) {
        if (!PUBLIC_WHITELIST.contains(name)) {
            return ResponseEntity.status(403).build();
        }
        return ResponseEntity.ok(systemParameterService.getLiveParameter(name, defaultValue));
    }

    @RateLimited(action = RateLimitAction.LIVE_PARAM)
    @GetMapping("/bulk")
    public ResponseEntity<Map<String, String>> getBulkParameters(@RequestParam List<String> names) {
        List<String> filteredNames = names.stream()
                .filter(PUBLIC_WHITELIST::contains)
                .collect(java.util.stream.Collectors.toList());
        
        return ResponseEntity.ok(systemParameterService.getBulkParameters(filteredNames));
    }
}
