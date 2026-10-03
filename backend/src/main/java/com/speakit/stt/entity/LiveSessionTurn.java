package com.speakit.stt.entity;

import com.speakit.shared.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.SuperBuilder;

@Entity
@Table(name = "live_session_turns")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class LiveSessionTurn extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "live_session_turn_seq")
    @SequenceGenerator(
        name = "live_session_turn_seq",
        sequenceName = "live_session_turn_seq",
        allocationSize = 50
    )
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "request_id", nullable = false)
    private SpeechToTextRequest request;

    @Column(name = "turn_index", nullable = false)
    private Integer turnIndex;

    @Column(name = "speaker_role", nullable = false, length = 16)
    private String speakerRole; // "PERSON_A", "PERSON_B", "SOLO"

    @Column(name = "speaker_name", nullable = false, length = 64)
    private String speakerName;

    @Column(name = "source_language", nullable = false, length = 16)
    private String sourceLanguage;

    @Column(name = "original_text", nullable = false, columnDefinition = "TEXT")
    private String originalText;

    @Column(name = "target_language", length = 16)
    private String targetLanguage;

    @Column(name = "translated_text", columnDefinition = "TEXT")
    private String translatedText;

    @Column(name = "character_count", nullable = false)
    private Integer characterCount;
}
