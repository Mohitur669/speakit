package com.tts.controller;

import com.tts.service.SystemParameterService;
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

    @GetMapping("/cached/{name}")
    public ResponseEntity<String> getCachedParameter(@PathVariable String name, @RequestParam(defaultValue = "") String defaultValue) {
        return ResponseEntity.ok(systemParameterService.getCachedParameter(name, defaultValue));
    }

    @GetMapping("/live/{name}")
    public ResponseEntity<String> getLiveParameter(@PathVariable String name, @RequestParam(defaultValue = "") String defaultValue) {
        return ResponseEntity.ok(systemParameterService.getLiveParameter(name, defaultValue));
    }

    @GetMapping("/bulk")
    public ResponseEntity<Map<String, String>> getBulkParameters(@RequestParam List<String> names) {
        return ResponseEntity.ok(systemParameterService.getBulkParameters(names));
    }
}
