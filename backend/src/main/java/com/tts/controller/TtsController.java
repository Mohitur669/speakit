package com.tts.controller;

import com.tts.aspect.RateLimited;
import com.tts.dto.TtsRequest;
import com.tts.service.PollyService;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.Logger;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.io.InputStream;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/tts")
@Slf4j
public class TtsController {

    private final PollyService pollyService;

    public TtsController(PollyService pollyService) {
        this.pollyService = pollyService;
    }

    @RateLimited
    @PostMapping("/synthesize")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request) {

        try (InputStream audioStream = pollyService.synthesizeSpeech(
                request.getText(),
                request.getVoiceId(),
                request.getOutputFormat()
        )) {

            byte[] audioBytes = audioStream.readAllBytes();

            MediaType mediaType = getMediaType(request.getOutputFormat());

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(mediaType);
            headers.setContentDisposition(
                    ContentDisposition.attachment()
                            .filename("speech." + request.getOutputFormat())
                            .build()
            );

            return new ResponseEntity<>(audioBytes, headers, HttpStatus.OK);

        } catch (Exception e) {
            log.debug("TTS failed for voice={} format={}", request.getVoiceId(), request.getOutputFormat(), e);

            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(("TTS failed: " + e.getMessage()).getBytes());
        }
    }

    // helper method
    private MediaType getMediaType(String format) {
        return switch (format.toLowerCase()) {
            case "mp3" -> MediaType.parseMediaType("audio/mpeg");
            case "ogg" -> MediaType.parseMediaType("audio/ogg");
            case "pcm" -> MediaType.parseMediaType("audio/wave");
            default -> MediaType.APPLICATION_OCTET_STREAM;
        };
    }

    // speech synthesize without buffer
    @PostMapping("/synthesize-stream")
    public ResponseEntity<InputStreamResource> synthesizeStream(@Valid @RequestBody TtsRequest request) {

        InputStream stream = pollyService.synthesizeSpeech(
                request.getText(),
                request.getVoiceId(),
                request.getOutputFormat()
        );

        return ResponseEntity.ok()
                .contentType(getMediaType(request.getOutputFormat()))
                .body(new InputStreamResource(stream));
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