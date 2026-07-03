package com.speakit.stt.repository;

import com.speakit.stt.entity.SpeechToTextRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SpeechToTextRequestRepository extends JpaRepository<SpeechToTextRequest, Long> {
}
