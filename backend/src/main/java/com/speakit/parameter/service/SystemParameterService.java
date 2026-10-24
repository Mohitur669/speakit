package com.speakit.parameter.service;

import com.speakit.parameter.entity.SystemParameter;
import com.speakit.parameter.repository.SystemParameterRepository;
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
@Slf4j
public class SystemParameterService {

    private final SystemParameterRepository repository;
    public static final String CACHE_NAME = "systemParameters";
    private final Map<String, String> localCache = new java.util.concurrent.ConcurrentHashMap<>();

    public SystemParameterService(SystemParameterRepository repository) {
        this.repository = repository;
    }

    // --- 1. DYNAMICALLY GOVERNED PARAMETER ACCESS (Governed by DYNAMIC_PLAN_FEATURES_LIVE flag) ---

    /**
     * Generic parameter fetcher governed by DYNAMIC_PLAN_FEATURES_LIVE flag.
     * If DYNAMIC_PLAN_FEATURES_LIVE is 'Y' (case-insensitive), performs a live DB fetch.
     * If other than 'Y', retrieves the parameter from the in-memory cache.
     *
     * @param name The system parameter key (e.g., FREE_PLAN_SYNTHESIZE_LIMIT, STT_ENABLED)
     * @param defaultValue Fallback value if missing from database
     * @return The parameter value
     */
    public String getParameter(String name, String defaultValue) {
        String dynamicLiveFlag = getCachedParameter("DYNAMIC_PLAN_FEATURES_LIVE", "N");
        if ("Y".equalsIgnoreCase(dynamicLiveFlag)) {
            return getLiveParameter(name, defaultValue);
        } else {
            return getCachedParameter(name, defaultValue);
        }
    }

    /**
     * Backward-compatible alias for getParameter.
     */
    public String getPlanFeatureParameter(String name, String defaultValue) {
        return getParameter(name, defaultValue);
    }

    public int getIntParameter(String name, int defaultValue) {
        try {
            return Integer.parseInt(getParameter(name, String.valueOf(defaultValue)));
        } catch (NumberFormatException e) {
            log.warn("Invalid integer value for parameter {}: using default {}", name, defaultValue);
            return defaultValue;
        }
    }

    public long getLongParameter(String name, long defaultValue) {
        try {
            return Long.parseLong(getParameter(name, String.valueOf(defaultValue)));
        } catch (NumberFormatException e) {
            log.warn("Invalid long value for parameter {}: using default {}", name, defaultValue);
            return defaultValue;
        }
    }

    public boolean getBooleanParameter(String name, boolean defaultValue) {
        String val = getParameter(name, String.valueOf(defaultValue));
        if (val == null) {
            return defaultValue;
        }
        String trimmed = val.trim();
        if ("Y".equalsIgnoreCase(trimmed) || "YES".equalsIgnoreCase(trimmed) || "TRUE".equalsIgnoreCase(trimmed) || "1".equals(trimmed)) {
            return true;
        }
        if ("N".equalsIgnoreCase(trimmed) || "NO".equalsIgnoreCase(trimmed) || "FALSE".equalsIgnoreCase(trimmed) || "0".equals(trimmed)) {
            return false;
        }
        return Boolean.parseBoolean(trimmed);
    }

    public boolean isFeatureEnabled(String name) {
        return getBooleanParameter(name, false);
    }

    public boolean isFeatureEnabled(String name, boolean defaultValue) {
        return getBooleanParameter(name, defaultValue);
    }

    /**
     * Checks if the Voice Bridge feature is enabled via VOICE_BRIDGE_FLAG system parameter.
     * Default is disabled (N/false).
     */
    public boolean isVoiceBridgeEnabled() {
        return getBooleanParameter("VOICE_BRIDGE_FLAG", false);
    }

    public BigDecimal getPrice(String name, BigDecimal defaultPrice) {
        try {
            String value = getParameter(name, defaultPrice.toString());
            return new BigDecimal(value);
        } catch (Exception e) {
            log.error("Error parsing price for parameter: {}", name);
            return defaultPrice;
        }
    }

    // --- 2. CACHED REPOSITORY CALLS (For stable UI Toggles, Feature Flags) ---

    @Cacheable(value = CACHE_NAME, key = "#name")
    public String getCachedParameter(String name, String defaultValue) {
        String cached = localCache.get(name);
        if (cached != null) {
            return cached;
        }
        log.debug("Cache-enabled fetch for: {}", name);
        String val = repository.findById(name)
                .map(SystemParameter::getParameterValue)
                .filter(v -> v != null && !v.trim().isEmpty())
                .orElse(defaultValue);
        localCache.put(name, val);
        return val;
    }

    // --- 3. NON-CACHED REPOSITORY CALLS (For Prices, Payments, Rapid Changes) ---

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

    // --- 4. BULK FETCH (Frontend Optimization) ---

    public Map<String, String> getBulkParameters(List<String> names) {
        String dynamicLiveFlag = getCachedParameter("DYNAMIC_PLAN_FEATURES_LIVE", "N");
        if ("Y".equalsIgnoreCase(dynamicLiveFlag)) {
            return repository.findByParameterNameIn(names).stream()
                    .collect(Collectors.toMap(
                            SystemParameter::getParameterName,
                            SystemParameter::getParameterValue,
                            (v1, v2) -> v1
                    ));
        } else {
            return names.stream()
                    .collect(Collectors.toMap(
                            name -> name,
                            name -> getCachedParameter(name, ""),
                            (v1, v2) -> v1
                    ));
        }
    }

    // --- 5. WRITE OPERATIONS (With Cache Invalidation) ---

    @Transactional
    @CacheEvict(value = CACHE_NAME, key = "#name")
    public void updateParameter(String name, String value, String updatedBy) {
        localCache.remove(name);
        SystemParameter param = repository.findById(name)
                .orElse(SystemParameter.builder().parameterName(name).build());
        
        param.setParameterValue(value);
        param.setUpdatedBy(updatedBy);
        repository.save(param);
        
        log.info("System parameter {} updated to {} by {}", name, value, updatedBy);
    }

    @CacheEvict(value = CACHE_NAME, allEntries = true)
    public void evictCache() {
        localCache.clear();
        log.info("SystemParameter cache cleared completely.");
    }
}
