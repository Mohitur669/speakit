package com.tts.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "tts_history", indexes = {
    @Index(name = "idx_tts_history_user_id", columnList = "user_id"),
    @Index(name = "idx_tts_history_created_at", columnList = "created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TtsHistory extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // LAZY fetch avoids loading User unless explicitly requested
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "voice_id", nullable = false, length = 50)
    private String voiceId;

    @Column(name = "output_format", nullable = false, length = 10)
    private String outputFormat;

    @Column(name = "character_count", nullable = false)
    private int characterCount;

    @Column(name = "is_neural", nullable = false)
    private boolean isNeural;
    
    // We only store a snippet or hash for privacy, not full text in DB
    @Column(name = "text_snippet", length = 100)
    private String textSnippet;
}