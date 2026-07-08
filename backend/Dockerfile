# ===== Stage 1: 构建 =====
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build

# 国内镜像加速
RUN mkdir -p /root/.m2 && \
    echo '<?xml version="1.0" encoding="UTF-8"?><settings><mirrors><mirror><id>aliyun</id><mirrorOf>*</mirrorOf><url>https://maven.aliyun.com/repository/public</url></mirror></mirrors></settings>' \
    > /root/.m2/settings.xml

COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ===== Stage 2: 运行 =====
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /build/target/zhiyu-backend.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
