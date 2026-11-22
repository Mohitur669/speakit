package com.speakit.notification.repository;

import com.speakit.notification.entity.LogBackupAudit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LogBackupAuditRepository extends JpaRepository<LogBackupAudit, Long> {

    List<LogBackupAudit> findTop10ByOrderByCreatedAtDesc();

    Page<LogBackupAudit> findByStatus(String status, Pageable pageable);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @org.springframework.data.jpa.repository.Query("UPDATE LogBackupAudit a SET a.user = null WHERE a.user.id = :userId")
    int disassociateUserFromAudits(@org.springframework.data.repository.query.Param("userId") Long userId);
}
