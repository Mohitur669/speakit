package com.speakit.stt.controller;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;

import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.billing.service.SubscriptionService;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.stt.dto.SpeechToTextResult;
import com.speakit.stt.service.SttService;
import com.speakit.stt.validator.AudioFileValidator;
import com.speakit.stt.dto.TranslationRequest;
import com.speakit.stt.dto.TranslationResponse;
import com.speakit.stt.dto.TransliterationRequest;
import com.speakit.stt.dto.TransliterationResponse;
import com.speakit.stt.service.TranslationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;

@RestController
@RequestMapping("/api/stt")
@RequiredArgsConstructor
@Slf4j
public class SttController {

    private final SttService sttService;
    private final SubscriptionService subscriptionService;
    private final AudioFileValidator fileValidator;
    private final SystemParameterService systemParameterService;
    private final TranslationService translationService;
    private final UserRepository userRepository;
    private final com.speakit.stt.repository.SpeechToTextRequestRepository speechToTextRequestRepository;
    private final com.speakit.stt.repository.LiveSessionTurnRepository liveSessionTurnRepository;

    /**
      * Secure endpoint for audio transcription.
      * Restricted to PRO, PRO_PLUS, and ENTERPRISE users.
      */
    @RateLimited(action = RateLimitAction.STT)
    @PostMapping(value = "/transcribe", consumes = "multipart/form-data")
    public ResponseEntity<SpeechToTextResult> transcribe(
            @RequestPart("file") MultipartFile file,
            @RequestPart(value = "language", required = false) String language,
            @RequestPart(value = "provider", required = false) String preferredProvider,
            @RequestPart(value = "mode", required = false) String mode,
            HttpServletRequest httpRequest
    ) {
        // 1. Sanitize & validate request parts
        if (language != null && !language.isEmpty() && !language.matches("^[a-zA-Z0-9\\-]+$")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }
        if (preferredProvider != null && !preferredProvider.isEmpty() && !preferredProvider.matches("^[a-zA-Z0-9_]+$")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }
        if (mode != null && !mode.isEmpty() && !mode.matches("^[a-zA-Z0-9_\\-]+$")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }

        // 2. Global Feature Flag Check (Governed Parameter)
        boolean sttEnabled = systemParameterService.isFeatureEnabled("STT_ENABLED", true);
        if (!sttEnabled) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }

        // 3. Extract Security Context from Filter attributes with database fallback
        UserSecurityContext context = resolveSecurityContext(httpRequest);
        Long userId = context.userId();
        PlanType planType = context.planType();
        SubscriptionStatus status = context.status();
        LocalDateTime expiry = context.expiry();

        // 4. Plan Authorization (Zero-Trust)
        if (!subscriptionService.hasSpeechToText(planType, status, expiry)) {
            log.warn("Access denied for STT transcription: userId={}, planType={}, status={}, expiry={}",
                    userId, planType, status, expiry);
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // 5. File Validation (MIME, Extension, Malware)
        fileValidator.validate(file);

        // 6. Upload Size Validation (Dynamic per Plan)
        long limitBytes = subscriptionService.getSttUploadLimitBytes(planType);
        if (file.getSize() > limitBytes) {
            String limitMb = systemParameterService.getParameter("STT_MAX_FILE_SIZE_MB_" + planType.name(), "0");
            throw new RuntimeException("File size exceeds your plan limit of " + limitMb + "MB.");
        }

        // 7. Engine Entitlement Check
        // Only PRO_PLUS and above can choose ElevenLabs
        String authorizedProvider = preferredProvider;
        if ("ELEVEN_LABS".equalsIgnoreCase(preferredProvider) && planType == PlanType.PRO) {
            log.warn("User {} (PRO) attempted to use ElevenLabs STT. Forcing Sarvam.", userId);
            authorizedProvider = "SARVAM";
        }

        // 8. Orchestrate Transcription
        SpeechToTextResult result = sttService.transcribe(file, language, userId, authorizedProvider, mode);
        
        return ResponseEntity.ok(result);
    }

    /**
      * Dedicated secure endpoint for live microphone recording transcription.
      * Restricted to PRO_PLUS and ENTERPRISE users.
      */
    @RateLimited(action = RateLimitAction.STT)
    @PostMapping(value = "/transcribe-live", consumes = "multipart/form-data")
    public ResponseEntity<SpeechToTextResult> transcribeLive(
            @RequestPart("file") MultipartFile file,
            @RequestPart(value = "language", required = false) String language,
            @RequestPart(value = "provider", required = false) String preferredProvider,
            @RequestPart(value = "mode", required = false) String mode,
            HttpServletRequest httpRequest
    ) {
        // 1. Sanitize & validate request parts
        if (language != null && !language.isEmpty() && !language.matches("^[a-zA-Z0-9\\-]+$")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }
        if (preferredProvider != null && !preferredProvider.isEmpty() && !preferredProvider.matches("^[a-zA-Z0-9_]+$")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }
        if (mode != null && !mode.isEmpty() && !mode.matches("^[a-zA-Z0-9_\\-]+$")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }

        // 2. Global Feature Flag Check (Governed Parameter)
        boolean sttEnabled = systemParameterService.isFeatureEnabled("STT_ENABLED", true);
        boolean liveRecordingEnabled = systemParameterService.isFeatureEnabled("LIVE_RECORDING_ENABLED", true);
        if (!sttEnabled || !liveRecordingEnabled) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }

        // 3. Extract Security Context with database fallback
        UserSecurityContext context = resolveSecurityContext(httpRequest);
        Long userId = context.userId();
        PlanType planType = context.planType();
        SubscriptionStatus status = context.status();
        LocalDateTime expiry = context.expiry();

        // 4. Plan Authorization (Zero-Trust)
        if (!subscriptionService.hasLiveRecording(planType, status, expiry)) {
            log.warn("Access denied for live recording: userId={}, planType={}, status={}, expiry={}",
                    userId, planType, status, expiry);
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // 5. File Validation (MIME, Extension, Malware)
        fileValidator.validate(file);

        // 6. Size Validation (Strict 10MB limit for live recording streams)
        if (file.getSize() > 10 * 1024 * 1024) {
            throw new RuntimeException("Live recording size exceeds limit of 10MB.");
        }

        // 7. Engine Entitlement Check
        String authorizedProvider = preferredProvider;
        if ("ELEVEN_LABS".equalsIgnoreCase(preferredProvider) && planType == PlanType.PRO) {
            log.warn("User {} (PRO) attempted to use ElevenLabs STT. Forcing Sarvam.", userId);
            authorizedProvider = "SARVAM";
        }

        // 8. Orchestrate Transcription
        SpeechToTextResult result = sttService.transcribe(file, language, userId, authorizedProvider, mode);
        
        return ResponseEntity.ok(result);
    }

    /**
      * Dedicated translation endpoint for transcribing Speech-to-Text results.
      */
    @Transactional
    @RateLimited(action = RateLimitAction.STT)
    @PostMapping("/translate")
    public ResponseEntity<TranslationResponse> translate(
            @Valid @RequestBody TranslationRequest request,
            HttpServletRequest httpRequest
    ) {
        // 1. Global Feature Flag Check (Governed Parameter)
        boolean sttEnabled = systemParameterService.isFeatureEnabled("STT_ENABLED", true);
        if (!sttEnabled) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }

        // 2. Extract and authorize plan with database fallback
        UserSecurityContext context = resolveSecurityContext(httpRequest);
        PlanType planType = context.planType();
        SubscriptionStatus status = context.status();
        LocalDateTime expiry = context.expiry();

        if (!subscriptionService.hasSpeechToText(planType, status, expiry)) {
            log.warn("Access denied for translation: userId={}, planType={}, status={}, expiry={}",
                    context.userId(), planType, status, expiry);
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // 3. Translate
        TranslationResponse result = translationService.translate(request);

        // 4. Atomically record translated character usage in user ledger
        if (result != null && result.getTranslatedText() != null && !result.getTranslatedText().isBlank()) {
            userRepository.incrementSttCharsUsed(context.userId(), result.getTranslatedText().length(), java.time.LocalDate.now().withDayOfMonth(1));
        }

        return ResponseEntity.ok(result);
    }

    /**
      * Dedicated transliteration endpoint for converting text across Indian language scripts and Roman/Latin.
      */
    @RateLimited(action = RateLimitAction.STT)
    @PostMapping("/transliterate")
    public ResponseEntity<TransliterationResponse> transliterate(
            @Valid @RequestBody TransliterationRequest request,
            HttpServletRequest httpRequest
    ) {
        // 1. Global Feature Flag Check (Governed Parameter)
        boolean sttEnabled = systemParameterService.isFeatureEnabled("STT_ENABLED", true);
        if (!sttEnabled) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }

        // 2. Extract and authorize plan with database fallback
        UserSecurityContext context = resolveSecurityContext(httpRequest);
        PlanType planType = context.planType();
        SubscriptionStatus status = context.status();
        LocalDateTime expiry = context.expiry();

        if (!subscriptionService.hasSpeechToText(planType, status, expiry)) {
            log.warn("Access denied for transliteration: userId={}, planType={}, status={}, expiry={}",
                    context.userId(), planType, status, expiry);
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // 3. Transliterate
        TransliterationResponse result = translationService.transliterate(request);
        return ResponseEntity.ok(result);
    }

    /**
      * Saves a complete live session history record (Solo dictation or Face-to-Face conversation)
      * containing all speaker turns, original transcripts, and translations under a single cohesive session.
      */
    @Transactional
    @PostMapping("/live/session")
    public ResponseEntity<?> saveLiveSession(
            @Valid @RequestBody com.speakit.stt.dto.SaveLiveSessionRequest sessionRequest,
            HttpServletRequest httpRequest
    ) {
        UserSecurityContext context = resolveSecurityContext(httpRequest);
        Long userId = context.userId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        log.info("saveLiveSession incoming payload: id={}, sessionId={}, sessionType={}, title={}, chars={}",
                sessionRequest.getId(), sessionRequest.getSessionId(), sessionRequest.getSessionType(), sessionRequest.getTitle(), sessionRequest.getCharacterCount());

        String transcript = sessionRequest.getTranscript() != null ? sessionRequest.getTranscript().trim() : "";
        if (transcript.isEmpty()) {
            return ResponseEntity.badRequest().body("Transcript cannot be empty");
        }

        User user = userRepository.getReferenceById(userId);

        String title = sessionRequest.getTitle();
        if (title == null || title.isBlank()) {
            title = "CONVERSATION".equalsIgnoreCase(sessionRequest.getSessionType())
                    ? "Live Conversation"
                    : "Live Dictation";
        }

        int charCount = sessionRequest.getCharacterCount() != null && sessionRequest.getCharacterCount() > 0
                ? sessionRequest.getCharacterCount()
                : transcript.length();

        String lang = sessionRequest.getLanguage() != null ? sessionRequest.getLanguage().trim() : "auto";
        if (lang.length() > 50) {
            lang = lang.substring(0, 50);
        }

        com.speakit.stt.entity.SpeechToTextRequest record = null;
        LocalDateTime now = LocalDateTime.now();

        // 1. Primary Idempotency Key: Lookup by client-generated session UUID
        if (sessionRequest.getSessionId() != null && !sessionRequest.getSessionId().isBlank()) {
            var existingByUuid = speechToTextRequestRepository.findBySessionIdAndUserId(sessionRequest.getSessionId().trim(), userId);
            if (existingByUuid.isPresent()) {
                record = existingByUuid.get();
            }
        }

        // 2. Secondary fallback: Lookup by numeric ID (for legacy sessions)
        if (record == null && sessionRequest.getId() != null) {
            var existingOpt = speechToTextRequestRepository.findByIdAndUserId(sessionRequest.getId(), userId);
            if (existingOpt.isPresent()) {
                record = existingOpt.get();
            }
        }

        if (record != null) {
            record.setTranscript(transcript);
            record.setTranscriptLength(charCount);
            if (sessionRequest.getDurationSeconds() != null && sessionRequest.getDurationSeconds() > 0) {
                record.setAudioDurationSeconds(sessionRequest.getDurationSeconds());
            }
            record.setOriginalFilename(title);
            record.setLanguage(lang);
            if (sessionRequest.getMode() != null) {
                record.setProcessingMode(sessionRequest.getMode());
            }
            if (sessionRequest.getSessionId() != null && !sessionRequest.getSessionId().isBlank()) {
                record.setSessionId(sessionRequest.getSessionId().trim());
            }
            // Update timestamps so this continued session ranks at the top of activity history
            record.setCreatedAt(now);
            record.setUpdatedAt(now);
            record.setCompletedAt(now);
            speechToTextRequestRepository.save(record);
            log.info("Updated existing Live Session in history: id={}, sessionId={}, user={}, title={}, chars={}",
                    record.getId(), record.getSessionId(), userId, title, charCount);
        } else {
            record = com.speakit.stt.entity.SpeechToTextRequest.builder()
                    .user(user)
                    .sessionId(sessionRequest.getSessionId() != null && !sessionRequest.getSessionId().isBlank() ? sessionRequest.getSessionId().trim() : null)
                    .provider("SARVAM")
                    .audioDurationSeconds(sessionRequest.getDurationSeconds() != null ? sessionRequest.getDurationSeconds() : 0)
                    .language(lang)
                    .processingMode(sessionRequest.getMode() != null ? sessionRequest.getMode() : "transcribe")
                    .transcript(transcript)
                    .transcriptLength(charCount)
                    .originalFilename(title)
                    .status("SUCCESS")
                    .completedAt(now)
                    .build();

            speechToTextRequestRepository.save(record);
            log.info("Saved new Live Session in history: id={}, sessionId={}, user={}, title={}, chars={}",
                    record.getId(), record.getSessionId(), userId, title, charCount);
        }

        // 3. Persist Structured Dialogue Turns (Parent-Child Model)
        final com.speakit.stt.entity.SpeechToTextRequest savedRecord = record;
        if (sessionRequest.getTurns() != null && !sessionRequest.getTurns().isEmpty()) {
            liveSessionTurnRepository.deleteByRequestId(savedRecord.getId());
            var entities = sessionRequest.getTurns().stream().map(dto ->
                com.speakit.stt.entity.LiveSessionTurn.builder()
                        .request(savedRecord)
                        .turnIndex(dto.getTurnIndex() != null ? dto.getTurnIndex() : 0)
                        .speakerRole(dto.getSpeakerRole() != null ? dto.getSpeakerRole() : "SOLO")
                        .speakerName(dto.getSpeakerName() != null ? dto.getSpeakerName() : "Speaker")
                        .sourceLanguage(dto.getSourceLanguage() != null ? dto.getSourceLanguage() : "auto")
                        .originalText(dto.getOriginalText() != null ? dto.getOriginalText() : "")
                        .targetLanguage(dto.getTargetLanguage())
                        .translatedText(dto.getTranslatedText())
                        .characterCount(dto.getCharacterCount() != null ? dto.getCharacterCount() : 0)
                        .build()
            ).toList();
            liveSessionTurnRepository.saveAll(entities);
            log.info("Persisted {} structured turns for live session id={}", entities.size(), savedRecord.getId());
        }

        java.util.Map<String, Object> respMap = new java.util.HashMap<>();
        respMap.put("id", record.getId());
        if (record.getSessionId() != null) {
            respMap.put("sessionId", record.getSessionId());
        }
        respMap.put("message", "Session saved successfully");
        return ResponseEntity.ok(respMap);
    }

    /**
      * Retrieves ordered, structured dialogue turns for a specific live session.
      */
    @GetMapping("/live/session/{id}/turns")
    public ResponseEntity<java.util.List<com.speakit.stt.dto.LiveSessionTurnDto>> getSessionTurns(
            @PathVariable("id") Long id,
            HttpServletRequest httpRequest
    ) {
        UserSecurityContext context = resolveSecurityContext(httpRequest);
        Long userId = context.userId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        var opt = speechToTextRequestRepository.findByIdAndUserId(id, userId);
        if (opt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        var turns = liveSessionTurnRepository.findByRequestIdOrderByTurnIndexAsc(id).stream()
                .map(t -> com.speakit.stt.dto.LiveSessionTurnDto.builder()
                        .turnIndex(t.getTurnIndex())
                        .speakerRole(t.getSpeakerRole())
                        .speakerName(t.getSpeakerName())
                        .sourceLanguage(t.getSourceLanguage())
                        .originalText(t.getOriginalText())
                        .targetLanguage(t.getTargetLanguage())
                        .translatedText(t.getTranslatedText())
                        .characterCount(t.getCharacterCount())
                        .build()
                ).toList();

        return ResponseEntity.ok(turns);
    }

    private UserSecurityContext resolveSecurityContext(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        PlanType planType = (PlanType) request.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) request.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) request.getAttribute("planExpiry");

        if (userId == null || planType == null) {
            java.security.Principal principal = request.getUserPrincipal();
            if (principal != null && principal.getName() != null) {
                var userOpt = userRepository.findByUsername(principal.getName());
                if (userOpt.isPresent()) {
                    var user = userOpt.get();
                    userId = user.getId();
                    planType = user.getPlanType();
                    status = user.getSubscriptionStatus();
                    expiry = user.getPlanExpiry();
                    request.setAttribute("userId", userId);
                    request.setAttribute("planType", planType);
                    request.setAttribute("subscriptionStatus", status);
                    request.setAttribute("planExpiry", expiry);
                }
            }
        }
        return new UserSecurityContext(userId, planType, status, expiry);
    }

    private record UserSecurityContext(Long userId, PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {}
}
