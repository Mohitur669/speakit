package com.speakit.billing.entity;

import lombok.Getter;

@Getter
public enum PlanType {
    FREE(0),
    PRO(1),
    PRO_PLUS(2),
    ENTERPRISE(3);

    private final int rank;

    PlanType(int rank) {
        this.rank = rank;
    }

    public boolean isHigherThan(PlanType other) {
        return this.rank > other.rank;
    }

    public boolean isLowerThan(PlanType other) {
        return this.rank < other.rank;
    }
}
