package com.tts.entity;

/**
 * User entity representing authenticated users with
 * credentials, subscription tier, and access control fields.
 */
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;
import lombok.experimental.SuperBuilder;

@Entity
@Table(name = "users", indexes = {
    @Index(name = "idx_users_username", columnList = "username"),
    @Index(name = "idx_users_email", columnList = "email")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class User extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "users_seq")
    @SequenceGenerator(
        name = "users_seq",
        sequenceName = "users_seq",
        allocationSize = 50
    )
    private Long id;

    @Column(unique = true, nullable = false, length = 50)
    private String username;

    @Column(unique = true, nullable = false, length = 100)
    private String email;

    @Column(name = "phone_number", unique = true, nullable = false, length = 15, columnDefinition = "varchar(15) default '0000000000'")
    private String phoneNumber;

    @Column(nullable = false)
    private String password;

    @Column(name = "is_active")
    @Builder.Default
    private boolean isActive = true;

    @Enumerated(EnumType.STRING)
    @Column(name = "plan_type", nullable = false, length = 20)
    @ColumnDefault("'FREE'")
    @Builder.Default
    private PlanType planType = PlanType.FREE;

    @Enumerated(EnumType.STRING)
    @Column(name = "subscription_status", nullable = false, length = 20)
    @ColumnDefault("'ACTIVE'")
    @Builder.Default
    private SubscriptionStatus subscriptionStatus = SubscriptionStatus.ACTIVE;

    @Column(name = "plan_expiry")
    private java.time.LocalDateTime planExpiry;

    @Column(name = "role", nullable = false, length = 20)
    @ColumnDefault("'USER'")
    @Builder.Default
    private String role = "USER";

    @Column(name = "session_version", nullable = false, columnDefinition = "bigint default 1")
    @Builder.Default
    private Long sessionVersion = 1L;

    @Column(name = "email_verified", nullable = false, columnDefinition = "boolean default false")
    @Builder.Default
    private boolean emailVerified = false;

    @Column(name = "account_status", nullable = false, length = 30)
    @ColumnDefault("'PENDING_VERIFICATION'")
    @Builder.Default
    private String accountStatus = "PENDING_VERIFICATION";

    @Column(name = "pending_email", length = 100)
    private String pendingEmail;

    @Column(name = "pending_username", length = 50)
    private String pendingUsername;

    @Column(name = "pending_phone_number", length = 15)
    private String pendingPhoneNumber;

    @Column(name = "pending_password", length = 255)
    private String pendingPassword;
}
