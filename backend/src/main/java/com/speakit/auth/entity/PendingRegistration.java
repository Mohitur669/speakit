package com.speakit.auth.entity;

import com.speakit.shared.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.SuperBuilder;

import java.time.LocalDateTime;

/**
 * Staging entity representing pre-verification registration requests.
 * Quarantines unverified signup attempts away from the primary users table
 * until 6-digit OTP email verification completes successfully.
 */
@Entity
@Table(name = "pending_registrations", indexes = {
    @Index(name = "idx_pending_reg_email", columnList = "email"),
    @Index(name = "idx_pending_reg_username", columnList = "username"),
    @Index(name = "idx_pending_reg_status", columnList = "status"),
    @Index(name = "idx_pending_reg_expires_at", columnList = "expires_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class PendingRegistration extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "pending_registrations_seq")
    @SequenceGenerator(
        name = "pending_registrations_seq",
        sequenceName = "pending_registrations_seq",
        allocationSize = 50
    )
    private Long id;

    @Column(nullable = false, length = 50)
    private String username;

    @Column(nullable = false, length = 100)
    private String email;

    @Column(name = "full_name", length = 100)
    private String fullName;

    @Column(name = "phone_number", length = 15)
    private String phoneNumber;

    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;

    @Column(name = "otp_hash", nullable = false, length = 255)
    private String otpHash;

    @Column(name = "attempts_remaining", nullable = false)
    @Builder.Default
    private int attemptsRemaining = 5;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "PENDING"; // PENDING, VERIFIED, EXPIRED

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;
}
