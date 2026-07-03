package com.speakit.tts.repository;

/**
 * JPA repository for User entity providing data access
 * methods for authentication and user lookup operations.
 */
import com.speakit.tts.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    Optional<User> findByEmail(String email);
    Optional<User> findByPhoneNumber(String phoneNumber);
    
    @Query("SELECT u FROM User u WHERE REPLACE(REPLACE(u.phoneNumber, '+', ''), ' ', '') LIKE %:suffix")
    Optional<User> findByPhoneNumberSuffix(@Param("suffix") String suffix);
    
    Optional<User> findByUsernameOrEmail(String username, String email);

    @Query("SELECT u.id AS id, u.sessionVersion AS sessionVersion, u.planType AS planType, u.subscriptionStatus AS subscriptionStatus, u.planExpiry AS planExpiry FROM User u WHERE u.username = :username")
    Optional<UserSessionProjection> findSessionAndPlanByUsername(@Param("username") String username);

    @Modifying
    @Query("UPDATE User u SET u.sessionVersion = u.sessionVersion + 1 WHERE u.username = :username")
    int incrementSessionVersion(@Param("username") String username);
}
