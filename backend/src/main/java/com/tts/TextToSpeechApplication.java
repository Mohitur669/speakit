package com.tts;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.EnableAspectJAutoProxy;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication(scanBasePackages = {"com.tts", "com.stt"})
@EntityScan(basePackages = {"com.tts.entity", "com.stt.entity"})
@EnableJpaRepositories(basePackages = {"com.tts.repository", "com.stt.repository"})
@EnableAspectJAutoProxy
@EnableScheduling
@org.springframework.scheduling.annotation.EnableAsync
@EnableJpaAuditing
@EnableCaching
public class TextToSpeechApplication {

    public static void main(String[] args) {
        SpringApplication.run(TextToSpeechApplication.class, args);
    }

}
