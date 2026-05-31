package com.tts.repository;

import com.tts.entity.TtsHistory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;

public interface TtsHistoryRepository extends JpaRepository<TtsHistory, Long> {
    
    // Optimized paginated fetch for user dashboard avoiding N+1
    @Query("SELECT t FROM TtsHistory t WHERE t.user.id = :userId ORDER BY t.createdAt DESC")
    Page<TtsHistory> findRecentHistoryByUserId(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT COUNT(t) FROM TtsHistory t WHERE t.user.id = :userId AND t.createdAt >= :since")
    long countRecentByUserId(@Param("userId") Long userId, @Param("since") LocalDateTime since);
}