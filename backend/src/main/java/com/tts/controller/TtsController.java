package com.tts.controller;

import com.tts.aspect.RateLimited;
import com.tts.dto.TtsRequest;
import com.tts.service.PollyService;
import com.tts.repository.UserRepository;
import com.tts.entity.User;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.*;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.services.polly.model.Engine;

import jakarta.validation.Valid;
import java.io.InputStream;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/tts")
@Slf4j
public class TtsController {

    private final PollyService pollyService;
    private final UserRepository userRepository;

    public TtsController(PollyService pollyService, UserRepository userRepository) {
        this.pollyService = pollyService;
        this.userRepository = userRepository;
    }

    @RateLimited
    @PostMapping("/synthesize")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request) {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        boolean hasNaturalAccess = userRepository.findByUsername(username)
                .map(User::isHasNaturalVoiceAccess)
                .orElse(false);

        try (InputStream audioStream = pollyService.synthesizeSpeech(
                request.getText(),
                request.getVoiceId(),
                request.getOutputFormat(),
                hasNaturalAccess
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

    private MediaType getMediaType(String format) {
        return switch (format.toLowerCase()) {
            case "mp3" -> MediaType.parseMediaType("audio/mpeg");
            case "ogg" -> MediaType.parseMediaType("audio/ogg");
            case "pcm" -> MediaType.parseMediaType("audio/wave");
            default -> MediaType.APPLICATION_OCTET_STREAM;
        };
    }

    @PostMapping("/synthesize-stream")
    public ResponseEntity<InputStreamResource> synthesizeStream(@Valid @RequestBody TtsRequest request) {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        boolean hasNaturalAccess = userRepository.findByUsername(username)
                .map(User::isHasNaturalVoiceAccess)
                .orElse(false);

        InputStream stream = pollyService.synthesizeSpeech(
                request.getText(),
                request.getVoiceId(),
                request.getOutputFormat(),
                hasNaturalAccess
        );

        return ResponseEntity.ok()
                .contentType(getMediaType(request.getOutputFormat()))
                .body(new InputStreamResource(stream));
    }

    @RateLimited
    @GetMapping("/voices")
    public ResponseEntity<List<Map<String, Object>>> getVoices() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        boolean hasNaturalAccess = userRepository.findByUsername(username)
                .map(User::isHasNaturalVoiceAccess)
                .orElse(false);

        List<Map<String, Object>> voices = pollyService.getAvailableVoices()
                .stream()
                .map(v -> {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id", v.id().toString());
                    map.put("name", v.name());
                    map.put("gender", v.genderAsString());
                    map.put("isNeural", v.supportedEngines().contains(Engine.NEURAL));
                    map.put("isStandard", v.supportedEngines().contains(Engine.STANDARD));
                    return map;
                })
                .filter(v -> {
                    // Regular users ONLY see voices that support Standard
                    if (!hasNaturalAccess) {
                        return (boolean) v.get("isStandard");
                    }
                    // Premium users see everything
                    return true;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(voices);
    }
}
