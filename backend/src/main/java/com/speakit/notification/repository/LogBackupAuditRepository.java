package com.speakit.notification.repository;

import com.speakit.notification.entity.LogBackupAudit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LogBackupAuditRepository extends JpaRepository<LogBackupAudit, Long> {

    List<LogBackupAudit> findTop10ByOrderByCreatedAtDesc();

    Page<LogBackupAudit> findByStatus(String status, Pageable pageable);
}
