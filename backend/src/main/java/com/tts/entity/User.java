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

    @Column(name = "plan_type", nullable = false, length = 20)
    @ColumnDefault("'FREE'")
    @Builder.Default
    private String planType = "FREE";

    @Column(name = "role", nullable = false, length = 20)
    @ColumnDefault("'USER'")
    @Builder.Default
    private String role = "USER";

    @Column(name = "session_version", nullable = false, columnDefinition = "bigint default 1")
    @Builder.Default
    private Long sessionVersion = 1L;
}
