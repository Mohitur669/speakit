package com.tts.entity;

/**
 * User entity representing authenticated users with
 * credentials, subscription tier, and access control fields.
 */
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String username;

    @Column(unique = true, nullable = false)
    private String email;

    @Column(nullable = false)
    private String password;

    @Column(name = "has_natural_voice_access", nullable = false)
    @Builder.Default
    private boolean hasNaturalVoiceAccess = false;

    @Column(name = "session_version", nullable = false, columnDefinition = "bigint default 1")
    @Builder.Default
    private Long sessionVersion = 1L;
}
