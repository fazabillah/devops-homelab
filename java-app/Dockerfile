# Stage 1: Build
# Use the full JDK to compile and package the application.
# The Maven wrapper downloads Maven automatically — no Maven installation needed in CI.
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /build

# Copy the Maven wrapper and pom.xml first.
# Docker caches this layer. If only source code changes, Maven dependencies
# are not re-downloaded — this makes builds significantly faster.
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN ./mvnw dependency:go-offline -q

# Now copy source and build the fat JAR
COPY src src
RUN ./mvnw package -DskipTests -q

# Stage 2: Runtime
# Use the JRE image (not JDK) — roughly 200MB smaller and has fewer CVEs
# because the compiler toolchain and javac are not present.
FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

# Create a non-root user. Running as root inside a container is a security
# risk — if the process is compromised, the attacker has root in the container.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only the fat JAR from the builder stage
COPY --from=builder /build/target/*.jar app.jar

# Switch to the non-root user before the final CMD
USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]