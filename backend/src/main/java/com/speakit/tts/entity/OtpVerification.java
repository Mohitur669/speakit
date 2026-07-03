package com.speakit.tts.entity;

import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.SuperBuilder;
import java.time.LocalDateTime;

/**
 * Entity representing an OTP token used for email verification,
 * password reset, or email changes.
 */
@Entity
@Table(name = "otp_verifications", indexes = {
    @Index(name = "idx_otp_email", columnList = "email"),
    @Index(name = "idx_otp_expires_at", columnList = "expires_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class OtpVerification extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "otp_verifications_seq")
    @SequenceGenerator(
        name = "otp_verifications_seq",
        sequenceName = "otp_verifications_seq",
        allocationSize = 50
    )
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(nullable = false, length = 100)
    private String email;

    @Column(name = "otp_hash", nullable = false, length = 255)
    private String otpHash;

    @Column(nullable = false, length = 30)
    private String purpose; // SIGNUP_VERIFICATION, PASSWORD_RESET, EMAIL_CHANGE

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "attempts_remaining", nullable = false)
    @Builder.Default
    private int attemptsRemaining = 5;

    @Column(nullable = false)
    @Builder.Default
    private boolean consumed = false;
}
