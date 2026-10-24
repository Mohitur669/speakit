package com.speakit.user.repository;

import com.speakit.user.entity.UserAvatarHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface UserAvatarHistoryRepository extends JpaRepository<UserAvatarHistory, Long> {

    @Query("SELECT COUNT(h) FROM UserAvatarHistory h WHERE h.user.id = :userId AND h.action = :action AND h.createdAt >= :since")
    long countByUserIdAndActionAndCreatedAtGreaterThanEqual(
            @Param("userId") Long userId,
            @Param("action") String action,
            @Param("since") LocalDateTime since
    );

    List<UserAvatarHistory> findTop10ByUserIdOrderByCreatedAtDesc(Long userId);
}
