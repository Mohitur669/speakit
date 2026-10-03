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
                    stmt.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS notes VARCHAR(500);");
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
