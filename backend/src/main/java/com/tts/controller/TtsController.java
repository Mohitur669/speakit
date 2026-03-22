package com.tts.controller;

import com.tts.aspect.RateLimited;
import com.tts.dto.TtsRequest;
import com.tts.service.PollyService;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.io.InputStream;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/tts")
public class TtsController {

    private final PollyService pollyService;

    public TtsController(PollyService pollyService) {
        this.pollyService = pollyService;
    }

    @RateLimited
    @PostMapping("/synthesize")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request) throws Exception {
        InputStream audioStream = pollyService.synthesizeSpeech(
                request.getText(), request.getVoiceId(), request.getOutputFormat()
        );

        byte[] audioBytes = audioStream.readAllBytes();

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("audio/mpeg"));
        headers.setContentDisposition(
                ContentDisposition.attachment().filename("speech.mp3").build()
        );

        return new ResponseEntity<>(audioBytes, headers, HttpStatus.OK);
    }

    @RateLimited
    @GetMapping("/voices")
    public ResponseEntity<List<Map<String, String>>> getVoices() {
        List<Map<String, String>> voices = pollyService.getAvailableVoices()
                .stream()
                .map(v -> Map.of(
                        "id", v.id().toString(),
                        "name", v.name(),
                        "gender", v.genderAsString()
                ))
                .collect(Collectors.toList());
        return ResponseEntity.ok(voices);
    }
}