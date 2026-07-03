package com.speakit.tts.service;

import com.speakit.tts.entity.SystemParameter;
import com.speakit.tts.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class SystemParameterService {

    private final SystemParameterRepository repository;
    public static final String CACHE_NAME = "systemParameters";

    // --- 1. CACHED REPOSITORY CALLS (For stable UI Toggles, Feature Flags) ---

    @Cacheable(value = CACHE_NAME, key = "#name")
    public String getCachedParameter(String name, String defaultValue) {
        log.debug("Cache-enabled fetch for: {}", name);
        return repository.findById(name)
                .map(SystemParameter::getParameterValue)
                .filter(val -> val != null && !val.trim().isEmpty())
                .orElseGet(() -> {
                    log.warn("Cached parameter {} missing or empty, using default: {}", name, defaultValue);
                    return defaultValue;
                });
    }

    public boolean isFeatureEnabled(String name) {
        return Boolean.parseBoolean(getCachedParameter(name, "false"));
    }

    // --- 2. NON-CACHED REPOSITORY CALLS (For Prices, Payments, Rapid Changes) ---

    public String getLiveParameter(String name, String defaultValue) {
        log.debug("Live DB fetch for: {}", name);
        return repository.findById(name)
                .map(SystemParameter::getParameterValue)
                .filter(val -> val != null && !val.trim().isEmpty())
                .orElseGet(() -> {
                    log.warn("Live parameter {} missing or empty, using default: {}", name, defaultValue);
                    return defaultValue;
                });
    }

    public BigDecimal getLivePrice(String name, BigDecimal defaultPrice) {
        try {
            String value = getLiveParameter(name, defaultPrice.toString());
            return new BigDecimal(value);
        } catch (Exception e) {
            log.error("Error parsing price for parameter: {}", name);
            return defaultPrice;
        }
    }

    // --- 3. BULK FETCH (Frontend Optimization) ---

    public Map<String, String> getBulkParameters(List<String> names) {
        return repository.findByParameterNameIn(names).stream()
                .collect(Collectors.toMap(
                        SystemParameter::getParameterName,
                        SystemParameter::getParameterValue
                ));
    }

    // --- 4. WRITE OPERATIONS (With Cache Invalidation) ---

    @Transactional
    @CacheEvict(value = CACHE_NAME, key = "#name")
    public void updateParameter(String name, String value, String updatedBy) {
        SystemParameter param = repository.findById(name)
                .orElse(SystemParameter.builder().parameterName(name).build());
        
        param.setParameterValue(value);
        param.setUpdatedBy(updatedBy);
        repository.save(param);
        
        log.info("System parameter {} updated to {} by {}", name, value, updatedBy);
    }
}
