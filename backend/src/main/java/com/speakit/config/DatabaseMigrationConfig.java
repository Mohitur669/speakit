package com.speakit.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.config.ConfigurableListableBeanFactory;
import org.springframework.context.EnvironmentAware;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;

/**
 * Executes critical backward-compatible idempotent DDL migrations
 * before Hibernate EntityManagerFactory schema validation executes.
 */
@Configuration
@Slf4j
public class DatabaseMigrationConfig implements BeanFactoryPostProcessor, EnvironmentAware {

    private Environment environment;

    @Override
    public void setEnvironment(Environment environment) {
        this.environment = environment;
    }

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        try {
            String url = environment.getProperty("spring.datasource.url");
            String user = environment.getProperty("spring.datasource.username");
            String pass = environment.getProperty("spring.datasource.password");
            if (url != null && !url.isBlank()) {
                try (Connection conn = DriverManager.getConnection(url, user, pass);
                     Statement stmt = conn.createStatement()) {
                    stmt.execute("ALTER TABLE speech_to_text_requests ADD COLUMN IF NOT EXISTS session_id VARCHAR(64);");
                    stmt.execute("CREATE SEQUENCE IF NOT EXISTS live_session_turn_seq START WITH 1 INCREMENT BY 50;");
                    stmt.execute("""
                        CREATE TABLE IF NOT EXISTS live_session_turns (
                            id BIGINT PRIMARY KEY,
                            request_id BIGINT NOT NULL REFERENCES speech_to_text_requests(id) ON DELETE CASCADE,
                            turn_index INTEGER NOT NULL,
                            speaker_role VARCHAR(16) NOT NULL,
                            speaker_name VARCHAR(64) NOT NULL,
                            source_language VARCHAR(16) NOT NULL,
                            original_text TEXT NOT NULL,
                            target_language VARCHAR(16),
                            translated_text TEXT,
                            character_count INTEGER NOT NULL DEFAULT 0,
                            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            version BIGINT NOT NULL DEFAULT 0
                        );
                    """);
                    stmt.execute("CREATE INDEX IF NOT EXISTS idx_live_turn_request_id ON live_session_turns(request_id, turn_index);");
                    stmt.execute("CREATE INDEX IF NOT EXISTS idx_tts_history_user_created ON tts_history(user_id, created_at);");
                    stmt.execute("CREATE INDEX IF NOT EXISTS idx_stt_user_created ON speech_to_text_requests(user_id, created_at);");
                    stmt.execute("CREATE INDEX IF NOT EXISTS idx_payments_user_created ON payments(user_id, created_at DESC);");
                    stmt.execute("UPDATE system_parameters SET parameter_value = 'N' WHERE parameter_name = 'DYNAMIC_PLAN_FEATURES_LIVE';");
                    log.info("Database optimization migration completed successfully.");
                }
            }
        } catch (Exception e) {
            log.debug("Database migration notice: {}", e.getMessage());
        }
    }
}
