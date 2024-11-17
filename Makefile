build-secret:
	@./sh.util.sh build_secret;
# ----------------------------------------------------------------------------------------------------------------------
__docker-prerequisite:
	@which docker >/dev/null 2>&1 || \
		{ echo "docker is not found in PATH"; exit 1; }

	@docker --version >/dev/null 2>&1 || \
		{ echo "docker is not running"; exit 1; }
# ----------------------------------------------------------------------------------------------------------------------
host := $(shell ip -4 -json addr show eth0 | jq '.[] | .addr_info[] | .local')
minio_endpoint := ${host}:9000
minio_region := $(shell cat ./.secret/minio_region)
loki_access := $(shell cat ./.secret/loki_access)
loki_secret := $(shell cat ./.secret/loki_secret)
loki__bucket_blocks := $(shell cat ./.secret/loki__bucket_blocks)
loki__bucket_ruler := $(shell cat ./.secret/loki__bucket_ruler)
mimir_access := $(shell cat ./.secret/mimir_access)
mimir_secret := $(shell cat ./.secret/mimir_secret)
mimir__bucket_blocks := $(shell cat ./.secret/mimir__bucket_blocks)
mimir__bucket_ruler := $(shell cat ./.secret/mimir__bucket_ruler)
mimir__bucket_alertmanager := $(shell cat ./.secret/mimir__bucket_alertmanager)
tempo_access := $(shell cat ./.secret/tempo_access)
tempo_secret := $(shell cat ./.secret/tempo_secret)
tempo__bucket_blocks := $(shell cat ./.secret/tempo__bucket_blocks)
pyroscope_access := $(shell cat ./.secret/pyroscope_access)
pyroscope_secret := $(shell cat ./.secret/pyroscope_secret)
pyroscope__bucket_blocks := $(shell cat ./.secret/pyroscope__bucket_blocks)
sonar_database := $(shell cat ./.secret/sonar_database)
sonar_username := $(shell cat ./.secret/sonar_username)
sonar_password := $(shell cat ./.secret/sonar_password)
# ----------------------------------------------------------------------------------------------------------------------
docker-compose-monitoring-monolithic: __docker-prerequisite
	@cd ./monitoring/monolithic; \
		true; \
		UID="${UID}" \
		GID="${GID}" \
		S3_ENDPOINT="${minio_endpoint}" \
		S3_REGION="${minio_region}" \
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
docker-compose-objectstore-minio: __docker-prerequisite
	@cd ./objectstore/minio; \
		true; \
		UID="${UID}" \
		GID="${GID}" \
		MINIO_REGION="${minio_region}" \
		LOKI_ACCESS="${loki_access}" \
		LOKI_SECRET="${loki_secret}" \
		LOKI_BUCKET_BLOCKS="${loki__bucket_blocks}" \
		LOKI_BUCKET_RULER="${loki__bucket_ruler}" \
		MIMIR_ACCESS="${mimir_access}" \
		MIMIR_SECRET="${mimir_secret}" \
		MIMIR_BUCKET_BLOCKS="${mimir__bucket_blocks}" \
		MIMIR_BUCKET_RULER="${mimir__bucket_ruler}" \
		MIMIR_BUCKET_ALERTMANAGER="${mimir__bucket_alertmanager}" \
		TEMPO_ACCESS="${tempo_access}" \
		TEMPO_SECRET="${tempo_secret}" \
		TEMPO_BUCKET_BLOCKS="${tempo__bucket_blocks}" \
		PYROSCOPE_ACCESS="${pyroscope_access}" \
		PYROSCOPE_SECRET="${pyroscope_secret}" \
		PYROSCOPE_BUCKET_BLOCKS="${pyroscope__bucket_blocks}" \
		bash -c "trap ' \
			docker compose -f ./docker-compose.yml down --remove-orphans --volumes;' EXIT; \
			docker compose -f ./docker-compose.yml up --remove-orphans --pull=always --build --force-recreate --abort-on-container-exit;"; \
	cd -;
# ----------------------------------------------------------------------------------------------------------------------
docker-compose-cicd-sonarqube: __docker-prerequisite
	@cd ./cicd/sonarqube; \
		true; \
		UID="${UID}" \
		GID="${GID}" \
		SONAR_JDBC_URL="jdbc:postgresql://${host}:5432/${sonar_database}?sslmode=disable" \
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
