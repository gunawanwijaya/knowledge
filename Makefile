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
