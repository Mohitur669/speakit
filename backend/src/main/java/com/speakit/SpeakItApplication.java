package com.speakit;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.EnableAspectJAutoProxy;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableAspectJAutoProxy
@EnableScheduling
@org.springframework.scheduling.annotation.EnableAsync
@EnableJpaAuditing
@EnableCaching
public class SpeakItApplication {

    public static void main(String[] args) {
        SpringApplication.run(SpeakItApplication.class, args);
    }

}
