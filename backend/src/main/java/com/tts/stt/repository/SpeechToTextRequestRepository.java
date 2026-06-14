package com.tts.stt.repository;

import com.tts.stt.entity.SpeechToTextRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SpeechToTextRequestRepository extends JpaRepository<SpeechToTextRequest, Long> {
}
