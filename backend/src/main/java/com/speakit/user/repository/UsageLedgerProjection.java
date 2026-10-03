package com.speakit.user.repository;

import java.time.LocalDate;

/**
 * Lightweight JPA projection for reading the usage ledger fields from the
 * users table without loading the full User entity.
 *
 * <p>Fields:
 * <ul>
 *   <li>{@code ttsChars}   — cumulative TTS characters consumed this billing month</li>
 *   <li>{@code sttChars}   — cumulative STT characters consumed this billing month</li>
 *   <li>{@code usageMonth} — the first day of the billing month these counters cover</li>
 * </ul>
 */
public interface UsageLedgerProjection {
    long getTtsChars();
    long getSttChars();
    LocalDate getUsageMonth();
}
