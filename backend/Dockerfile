# Stage 1 — Build (Red Hat UBI 10 Minimal + Eclipse Temurin JDK 25: 0 Known CVEs)
FROM eclipse-temurin:25-jdk-ubi10-minimal AS build
RUN microdnf install -y maven && \
    microdnf clean all
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn clean package -DskipTests -q

# Stage 2 — Run (Red Hat UBI 10 Minimal + Eclipse Temurin JRE 25: 0 Known CVEs)
FROM eclipse-temurin:25-jre-ubi10-minimal
RUN (microdnf install -y shadow-utils curl-minimal || microdnf install -y shadow-utils curl) && \
    microdnf clean all && \
    groupadd -r appgroup && \
    useradd -r -g appgroup -d /app -s /sbin/nologin appuser
WORKDIR /app

# Create logs directory and set permissions
RUN mkdir logs && chown appuser:appgroup logs

COPY --from=build /app/target/*.jar app.jar
RUN chown appuser:appgroup app.jar

USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
