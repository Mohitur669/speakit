package com.speakit.user.entity;

import com.speakit.shared.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.SuperBuilder;

@Entity
@Table(name = "user_avatar_history", indexes = {
    @Index(name = "idx_avatar_history_user_date", columnList = "user_id, action, created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class UserAvatarHistory extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "user_avatar_history_seq")
    @SequenceGenerator(
        name = "user_avatar_history_seq",
        sequenceName = "user_avatar_history_seq",
        allocationSize = 50
    )
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "avatar_url", length = 512)
    private String avatarUrl;

    @Column(name = "storage_key", length = 255)
    private String storageKey;

    @Column(name = "action", nullable = false, length = 20)
    private String action; // "UPLOAD" or "DELETE"

    @Column(name = "file_size_bytes")
    private Long fileSizeBytes;

    @Column(name = "mime_type", length = 50)
    private String mimeType;
}
