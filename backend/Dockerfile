# ===== Stage 1: 编译（镜像内自动 Maven 编译，不再依赖宿主机）=====
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build

# 使用阿里云镜像加速 Maven 依赖下载
COPY .mvn-settings.xml /tmp/mvn-settings.xml
COPY pom.xml .
RUN mvn -s /tmp/mvn-settings.xml dependency:go-offline -B -q || true

COPY src ./src
RUN mvn -s /tmp/mvn-settings.xml clean package -DskipTests -B -q

# ===== Stage 2: 运行镜像 =====
FROM eclipse-temurin:17-jdk-alpine
WORKDIR /app
COPY --from=builder /build/target/zhiyu-backend.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]