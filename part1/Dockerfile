FROM openjdk:17 AS build
WORKDIR /opt/webbooks

# 1. Копируем wrapper и исправляем формат 
COPY ./webbooks/mvnw .
COPY ./webbooks/.mvn .mvn
RUN sed -i 's/\r$//' mvnw && chmod +x mvnw

# 2. Копируем остальные файлы
COPY ./webbooks/pom.xml .
COPY ./webbooks/src src

# 3. Собираем проект
RUN ./mvnw clean package -DskipTests

FROM openjdk:17-jdk-slim
WORKDIR /opt/webbooks
COPY --from=build /opt/webbooks/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
