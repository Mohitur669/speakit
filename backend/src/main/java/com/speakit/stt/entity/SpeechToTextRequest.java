package com.speakit.stt.entity;

import com.speakit.shared.entity.BaseEntity;
import com.speakit.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.SuperBuilder;

import java.time.LocalDateTime;

@Entity
@Table(name = "speech_to_text_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class SpeechToTextRequest extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "stt_seq")
    @SequenceGenerator(
        name = "stt_seq",
        sequenceName = "stt_seq",
        allocationSize = 50
    )
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 20)
    private String provider;

    @Column(name = "audio_duration_seconds")
    private Integer audioDurationSeconds;

    @Column(name = "audio_size_bytes")
    private Long audioSizeBytes;

    @Column(length = 10)
    private String language;

    @Column(name = "transcript_length")
    private Integer transcriptLength;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "failure_reason", length = 255)
    private String failureReason;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;
}
