package com.speakit.tts.repository;

import com.speakit.tts.entity.SystemParameter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SystemParameterRepository extends JpaRepository<SystemParameter, String> {
    List<SystemParameter> findByParameterNameIn(List<String> names);
}
