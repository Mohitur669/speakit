package com.speakit.stt.repository;

import com.speakit.stt.entity.LiveSessionTurn;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LiveSessionTurnRepository extends JpaRepository<LiveSessionTurn, Long> {

    List<LiveSessionTurn> findByRequestIdOrderByTurnIndexAsc(Long requestId);

    @Modifying
    @Query("DELETE FROM LiveSessionTurn t WHERE t.request.id = :requestId")
    void deleteByRequestId(@Param("requestId") Long requestId);
}
