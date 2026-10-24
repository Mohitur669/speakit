package com.speakit.parameter.service;

import com.speakit.parameter.entity.SystemParameter;
import com.speakit.parameter.repository.SystemParameterRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SystemParameterServiceTest {

    @Mock
    private SystemParameterRepository repository;

    @InjectMocks
    private SystemParameterService service;

    @BeforeEach
    void setUp() {
        reset(repository);
    }

    @Test
    @DisplayName("getParameter: Always fetches via cached parameter path regardless of DYNAMIC_PLAN_FEATURES_LIVE")
    void getParameter_alwaysUsesCache() {
        when(repository.findById("STT_ENABLED"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("STT_ENABLED").parameterValue("true").build()));

        String value = service.getParameter("STT_ENABLED", "false");

        assertEquals("true", value);
        // Second call should come strictly from in-memory cache without hitting repository again
        String cachedValue = service.getParameter("STT_ENABLED", "false");
        assertEquals("true", cachedValue);
        verify(repository, times(1)).findById("STT_ENABLED");
    }

    @Test
    @DisplayName("getPlanFeatureParameter: When DYNAMIC_PLAN_FEATURES_LIVE is Y, fetches live from repository")
    void getPlanFeatureParameter_whenDynamicLiveIsY_fetchesLive() {
        when(repository.findById("DYNAMIC_PLAN_FEATURES_LIVE"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("DYNAMIC_PLAN_FEATURES_LIVE").parameterValue("Y").build()));
        when(repository.findById("FREE_PLAN_SYNTHESIZE_LIMIT"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("FREE_PLAN_SYNTHESIZE_LIMIT").parameterValue("15").build()));

        String value = service.getPlanFeatureParameter("FREE_PLAN_SYNTHESIZE_LIMIT", "5");

        assertEquals("15", value);
        // Verify live fetch occurred
        verify(repository, atLeastOnce()).findById("FREE_PLAN_SYNTHESIZE_LIMIT");
    }

    @Test
    @DisplayName("getPlanFeatureParameter: When DYNAMIC_PLAN_FEATURES_LIVE is N, fetches via cached parameter path")
    void getPlanFeatureParameter_whenDynamicLiveIsN_fetchesCached() {
        when(repository.findById("DYNAMIC_PLAN_FEATURES_LIVE"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("DYNAMIC_PLAN_FEATURES_LIVE").parameterValue("N").build()));
        when(repository.findById("FREE_PLAN_SYNTHESIZE_LIMIT"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("FREE_PLAN_SYNTHESIZE_LIMIT").parameterValue("20").build()));

        String value = service.getPlanFeatureParameter("FREE_PLAN_SYNTHESIZE_LIMIT", "5");

        assertEquals("20", value);
    }

    @Test
    @DisplayName("getParameter: When parameter is missing, returns safe default")
    void getParameter_whenMissing_returnsDefault() {
        when(repository.findById("NON_EXISTENT_PARAM"))
                .thenReturn(Optional.empty());

        String value = service.getParameter("NON_EXISTENT_PARAM", "fallback_val");

        assertEquals("fallback_val", value);
    }

    @Test
    @DisplayName("getIntParameter: Correctly parses integer or returns default on parse error")
    void getIntParameter_parsesCorrectly() {
        when(repository.findById("FREE_PLAN_SYNTHESIZE_LIMIT"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("FREE_PLAN_SYNTHESIZE_LIMIT").parameterValue("10").build()));
        when(repository.findById("INVALID_INT"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("INVALID_INT").parameterValue("not_a_number").build()));

        assertEquals(10, service.getIntParameter("FREE_PLAN_SYNTHESIZE_LIMIT", 5));
        assertEquals(5, service.getIntParameter("INVALID_INT", 5));
    }

    @Test
    @DisplayName("getLongParameter: Correctly parses long or returns default")
    void getLongParameter_parsesCorrectly() {
        when(repository.findById("STT_DEDUPE_WINDOW_MS"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("STT_DEDUPE_WINDOW_MS").parameterValue("120000").build()));

        assertEquals(120000L, service.getLongParameter("STT_DEDUPE_WINDOW_MS", 60000L));
    }

    @Test
    @DisplayName("isFeatureEnabled: Respects boolean string values")
    void isFeatureEnabled_respectsBoolean() {
        when(repository.findById("STT_ENABLED"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("STT_ENABLED").parameterValue("true").build()));
        when(repository.findById("MAINTENANCE_MODE"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("MAINTENANCE_MODE").parameterValue("false").build()));

        assertTrue(service.isFeatureEnabled("STT_ENABLED", false));
        assertFalse(service.isFeatureEnabled("MAINTENANCE_MODE", true));
    }

    @Test
    @DisplayName("getPrice: Correctly parses BigDecimal prices")
    void getPrice_parsesBigDecimal() {
        when(repository.findById("DYNAMIC_PLAN_FEATURES_LIVE"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("DYNAMIC_PLAN_FEATURES_LIVE").parameterValue("Y").build()));
        when(repository.findById("PRO_PLAN_PRICE_INR"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("PRO_PLAN_PRICE_INR").parameterValue("499.00").build()));

        BigDecimal price = service.getPrice("PRO_PLAN_PRICE_INR", new BigDecimal("100"));
        assertEquals(new BigDecimal("499.00"), price);
    }

    @Test
    @DisplayName("getBulkParameters: Live mode queries findByParameterNameIn")
    void getBulkParameters_liveMode() {
        when(repository.findById("DYNAMIC_PLAN_FEATURES_LIVE"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("DYNAMIC_PLAN_FEATURES_LIVE").parameterValue("Y").build()));
        when(repository.findByParameterNameIn(List.of("PARAM_A", "PARAM_B")))
                .thenReturn(List.of(
                        SystemParameter.builder().parameterName("PARAM_A").parameterValue("valA").build(),
                        SystemParameter.builder().parameterName("PARAM_B").parameterValue("valB").build()
                ));

        Map<String, String> result = service.getBulkParameters(List.of("PARAM_A", "PARAM_B"));

        assertEquals(2, result.size());
        assertEquals("valA", result.get("PARAM_A"));
        assertEquals("valB", result.get("PARAM_B"));
    }

    @Test
    @DisplayName("updateParameter: Updates entity and saves to repository")
    void updateParameter_savesEntity() {
        when(repository.findById("FREE_PLAN_SYNTHESIZE_LIMIT"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("FREE_PLAN_SYNTHESIZE_LIMIT").parameterValue("5").build()));

        service.updateParameter("FREE_PLAN_SYNTHESIZE_LIMIT", "15", "admin");

        verify(repository, times(1)).save(any(SystemParameter.class));
    }

    @Test
    @DisplayName("isVoiceBridgeEnabled: Returns true for Y and false for N with cache eviction")
    void isVoiceBridgeEnabled_flagEvaluation() {
        when(repository.findById("VOICE_BRIDGE_FLAG"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("VOICE_BRIDGE_FLAG").parameterValue("N").build()));
        assertFalse(service.isVoiceBridgeEnabled());

        service.evictCache();

        when(repository.findById("VOICE_BRIDGE_FLAG"))
                .thenReturn(Optional.of(SystemParameter.builder().parameterName("VOICE_BRIDGE_FLAG").parameterValue("Y").build()));
        assertTrue(service.isVoiceBridgeEnabled());
    }
}
