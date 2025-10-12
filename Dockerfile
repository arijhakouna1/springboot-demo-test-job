# Utiliser l'image de base OpenJDK 17 JRE slim
FROM eclipse-temurin:17-jre-slim

# Définir le répertoire de travail dans le conteneur
WORKDIR /app

# Copier le fichier JAR de l'application dans le conteneur
COPY target/springboot-demo-*.jar app.jar

# Exposer le port 8081 (au lieu de 8080 pour éviter le conflit avec Jenkins)
EXPOSE 8085

# Configurer le port de l'application Spring Boot
ENV SERVER_PORT=8085

# Commande pour démarrer l'application
ENTRYPOINT ["java", "-jar", "app.jar"]
