package com.speakit.tts.entity;
import com.shared.entity.BaseEntity;

import jakarta.persistence.*;
import lombok.*;

import lombok.experimental.SuperBuilder;

@Entity
@Table(name = "tts_history", indexes = {
    @Index(name = "idx_tts_history_user_id", columnList = "user_id"),
    @Index(name = "idx_tts_history_created_at", columnList = "created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class TtsHistory extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "tts_history_seq")
    @SequenceGenerator(
        name = "tts_history_seq",
        sequenceName = "tts_history_seq",
        allocationSize = 50
    )
    private Long id;

    // LAZY fetch avoids loading User unless explicitly requested
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "voice_id", nullable = false, length = 50)
    private String voiceId;

    @Column(name = "voice_name", length = 100)
    private String voiceName;

    @Column(name = "voice_type", nullable = false, length = 20, columnDefinition = "VARCHAR(20) DEFAULT 'STANDARD'")
    private String voiceType; // STANDARD, NEURAL, NATURAL

    @Column(name = "output_format", nullable = false, length = 10)
    private String outputFormat;

    @Column(name = "character_count", nullable = false)
    private int characterCount;
    
    // We only store a snippet or hash for privacy, not full text in DB
    @Column(name = "text_snippet", length = 100)
    private String textSnippet;
}
