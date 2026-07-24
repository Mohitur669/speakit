package com.speakit.shared.util;

import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.Appender;
import ch.qos.logback.core.AppenderBase;
import ch.qos.logback.core.spi.AppenderAttachable;
import ch.qos.logback.core.spi.AppenderAttachableImpl;

import java.util.Iterator;
import java.util.regex.Pattern;

/**
 * Logback Appender wrapper that intercepts logging events,
 * redacts any sensitive fields in the message string, and
 * delegates the wrapped event to child appenders.
 */
public class LogMaskingAppender extends AppenderBase<ILoggingEvent> implements AppenderAttachable<ILoggingEvent> {

    private final AppenderAttachableImpl<ILoggingEvent> aai = new AppenderAttachableImpl<>();

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
            "[a-zA-Z0-9_+&*-]+(?:\\.[a-zA-Z0-9_+&*-]+)*@(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,7}"
    );

    private static final Pattern SENSITIVE_KEY_PATTERN = Pattern.compile(
            "(?i)\"(password|otp|token|jwt|secret|key|authorization|credential)\"\\s*:\\s*\"[^\"]+\""
    );

    private static final Pattern QUERY_PARAM_PATTERN = Pattern.compile(
            "(?i)(password|otp|token|jwt|secret|key|authorization|credential)=[^&\\s]+"
    );

    @Override
    public void start() {
        super.start();
    }

    @Override
    public void stop() {
        aai.detachAndStopAllAppenders();
        super.stop();
    }

    @Override
    protected void append(ILoggingEvent event) {
        if (event == null) return;

        String originalMsg = event.getMessage();
        String originalFormattedMsg = event.getFormattedMessage();

        String maskedMsg = scrub(originalMsg);
        String maskedFormattedMsg = scrub(originalFormattedMsg);

        MaskedLoggingEvent maskedEvent = new MaskedLoggingEvent(event, maskedMsg, maskedFormattedMsg);
        aai.appendLoopOnAppenders(maskedEvent);
    }

    private String scrub(String input) {
        if (input == null || input.isBlank()) {
            return input;
        }
        String scrubbed = EMAIL_PATTERN.matcher(input).replaceAll("[EMAIL_REDACTED]");
        scrubbed = SENSITIVE_KEY_PATTERN.matcher(scrubbed).replaceAll("\"$1\":\"[REDACTED]\"");
        scrubbed = QUERY_PARAM_PATTERN.matcher(scrubbed).replaceAll("$1=[REDACTED]");
        return scrubbed;
    }

    @Override
    public void addAppender(Appender<ILoggingEvent> newAppender) {
        aai.addAppender(newAppender);
    }

    @Override
    public Iterator<Appender<ILoggingEvent>> iteratorForAppenders() {
        return aai.iteratorForAppenders();
    }

    @Override
    public Appender<ILoggingEvent> getAppender(String name) {
        return aai.getAppender(name);
    }

    @Override
    public boolean isAttached(Appender<ILoggingEvent> appender) {
        return aai.isAttached(appender);
    }

    @Override
    public void detachAndStopAllAppenders() {
        aai.detachAndStopAllAppenders();
    }

    @Override
    public boolean detachAppender(Appender<ILoggingEvent> appender) {
        return aai.detachAppender(appender);
    }

    @Override
    public boolean detachAppender(String name) {
        return aai.detachAppender(name);
    }
}
