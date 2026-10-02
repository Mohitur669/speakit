package com.speakit.stt.repository;

import com.speakit.stt.entity.SpeechToTextRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Repository
public interface SpeechToTextRequestRepository extends JpaRepository<SpeechToTextRequest, Long> {

    @Query("SELECT r FROM SpeechToTextRequest r WHERE r.user.id = :userId ORDER BY r.createdAt DESC")
    Page<SpeechToTextRequest> findByUserIdOrderByCreatedAtDesc(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT r FROM SpeechToTextRequest r WHERE r.id IN :ids AND r.user.id = :userId")
    List<SpeechToTextRequest> findAllByIdInAndUserId(@Param("ids") List<Long> ids, @Param("userId") Long userId);

    @Query("SELECT r FROM SpeechToTextRequest r WHERE r.user.id = :userId")
    List<SpeechToTextRequest> findAllByUserId(@Param("userId") Long userId);

    @Modifying
    @Transactional
    @Query("DELETE FROM SpeechToTextRequest r WHERE r.id IN :ids AND r.user.id = :userId")
    void deleteAllByIdInAndUserId(@Param("ids") List<Long> ids, @Param("userId") Long userId);

    @Modifying
    @Transactional
    @Query("DELETE FROM SpeechToTextRequest r WHERE r.user.id = :userId")
    void deleteAllByUserId(@Param("userId") Long userId);
}
