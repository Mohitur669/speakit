package com.speakit.stt.repository;

import com.speakit.stt.entity.LiveSessionTurn;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface LiveSessionTurnRepository extends JpaRepository<LiveSessionTurn, Long> {

    List<LiveSessionTurn> findByRequestIdOrderByTurnIndexAsc(Long requestId);

    @Modifying
    @Query("DELETE FROM LiveSessionTurn t WHERE t.request.id = :requestId")
    void deleteByRequestId(@Param("requestId") Long requestId);

    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("DELETE FROM LiveSessionTurn t WHERE t.request.user.id = :userId")
    void deleteAllByUserId(@Param("userId") Long userId);
}
