package com.speakit.parameter.entity;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.OffsetDateTime;

@Entity
@Table(name = "system_parameters")
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SystemParameter {

    @Id
    @Column(name = "parameter_name", length = 100)
    private String parameterName;

    @Column(name = "parameter_value", columnDefinition = "TEXT")
    private String parameterValue;

    @Column(length = 255)
    private String description;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @Column(name = "updated_by", nullable = false, length = 50)
    @Builder.Default
    private String updatedBy = "SYSTEM";

    @Version
    private Long version;
}
