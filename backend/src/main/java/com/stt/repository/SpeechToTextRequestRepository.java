package com.stt.repository;

import com.stt.entity.SpeechToTextRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SpeechToTextRequestRepository extends JpaRepository<SpeechToTextRequest, Long> {
}
