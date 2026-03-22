package com.tts;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.EnableAspectJAutoProxy;

@SpringBootApplication
@EnableAspectJAutoProxy
public class TextToSpeechApplication {

    public static void main(String[] args) {
        SpringApplication.run(TextToSpeechApplication.class, args);
    }

}