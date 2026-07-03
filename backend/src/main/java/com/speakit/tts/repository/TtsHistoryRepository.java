package com.speakit.tts.repository;

import com.speakit.tts.entity.TtsHistory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

public interface TtsHistoryRepository extends JpaRepository<TtsHistory, Long> {
    
    // Optimized paginated fetch for user dashboard avoiding N+1
    @Query("SELECT t FROM TtsHistory t WHERE t.user.id = :userId ORDER BY t.createdAt DESC")
    Page<TtsHistory> findRecentHistoryByUserId(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT COUNT(t) FROM TtsHistory t WHERE t.user.id = :userId AND t.createdAt >= :since")
    long countRecentByUserId(@Param("userId") Long userId, @Param("since") LocalDateTime since);

    @Modifying
    @Transactional
    @Query("DELETE FROM TtsHistory t WHERE t.user.id = :userId")
    void deleteAllByUserId(@Param("userId") Long userId);

    @Modifying
    @Transactional
    @Query("DELETE FROM TtsHistory t WHERE t.id IN :ids AND t.user.id = :userId")
    void deleteAllByIdInAndUserId(@Param("ids") List<Long> ids, @Param("userId") Long userId);
}