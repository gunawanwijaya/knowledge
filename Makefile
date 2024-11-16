build-secret:
	@./sh.util.sh build_secret;
# ----------------------------------------------------------------------------------------------------------------------
__docker-prerequisite:
	@which docker >/dev/null 2>&1 || \
		{ echo "docker is not found in PATH"; exit 1; }

	@docker --version >/dev/null 2>&1 || \
		{ echo "docker is not running"; exit 1; }
# ----------------------------------------------------------------------------------------------------------------------
docker-compose-monitoring-monolithic: __docker-prerequisite
	@cd ./monitoring/monolithic; \
		true; \
		UID="${UID}" \
		GID="${GID}" \
		bash -c "trap ' \
			docker compose -f ./docker-compose.yml --profile monolithic down --remove-orphans --volumes;' EXIT; \
			docker compose -f ./docker-compose.yml --profile monolithic up --remove-orphans --pull=always --build --force-recreate --abort-on-container-exit;"; \
	cd -;
# ----------------------------------------------------------------------------------------------------------------------
docker-compose-database-postgresql: __docker-prerequisite
	@cd ./database/postgresql; \
		true; \
		UID="${UID}" \
		GID="${GID}" \
		bash -c "trap ' \
			docker compose -f ./docker-compose.yml --profile ha down --remove-orphans --volumes;' EXIT; \
			docker compose -f ./docker-compose.yml --profile ha up --remove-orphans --pull=always --build --force-recreate --abort-on-container-exit;"; \
	cd -;
# ----------------------------------------------------------------------------------------------------------------------
sonar_database := $(shell cat ./.secret/sonar_database)
sonar_username := $(shell cat ./.secret/sonar_username)
sonar_password := $(shell cat ./.secret/sonar_password)
docker-compose-cicd-sonarqube: __docker-prerequisite
	@cd ./cicd/sonarqube; \
		true; \
		UID="${UID}" \
		GID="${GID}" \
		SONAR_JDBC_URL="jdbc:postgresql://172.30.179.70:5432/${sonar_database}?sslmode=disable" \
		SONAR_JDBC_USERNAME="${sonar_username}" \
		SONAR_JDBC_PASSWORD="${sonar_password}" \
		bash -c "trap ' \
			docker compose -f ./docker-compose.yml --profile ha down --remove-orphans --volumes;' EXIT; \
			docker compose -f ./docker-compose.yml --profile ha up --remove-orphans --pull=always --build --force-recreate --abort-on-container-exit;"; \
	cd -;
# ----------------------------------------------------------------------------------------------------------------------
# docker-sonarqube: __docker-prerequisite
# 	@docker volume create --name sonarqube_data;
# 	@docker volume create --name sonarqube_logs;
# 	@docker volume create --name sonarqube_extensions;
# 	@docker run -d --name sonarqube \
# 		-p 9000:9000 \
# 		-e SONAR_JDBC_URL=... \
# 		-e SONAR_JDBC_USERNAME=... \
# 		-e SONAR_JDBC_PASSWORD=... \
# 		-v sonarqube_data:/opt/sonarqube/data \
# 		-v sonarqube_extensions:/opt/sonarqube/extensions \
# 		-v sonarqube_logs:/opt/sonarqube/logs \
# 		sonarqube:10.7.0-community
# ----------------------------------------------------------------------------------------------------------------------
