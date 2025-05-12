FROM openjdk:17 AS build
WORKDIR /opt/webbooks

COPY ./webbooks/mvnw .
COPY ./webbooks/.mvn .mvn
RUN sed -i 's/\r$//' mvnw && chmod +x mvnw

COPY ./webbooks/pom.xml .
COPY ./webbooks/src src

RUN ./mvnw clean package -DskipTests

FROM openjdk:17-jdk-slim
WORKDIR /opt/webbooks
COPY --from=build /opt/webbooks/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
