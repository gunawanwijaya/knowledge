docker-compose-monitoring-simple:
	@which docker >/dev/null 2>&1 || \
		{ echo "docker is not found in PATH"; exit 1; }

	@docker --version >/dev/null 2>&1 || \
		{ echo "docker is not running"; exit 1; }

	@cd ./monitoring/simple; ./.init.sh; cd -;

	@UID=${UID} GID=${GID} bash -c "trap '\
		docker compose -f ./monitoring/simple/docker-compose.yml \
		--profile simple down --remove-orphans --volumes;' EXIT;\
		docker compose -f ./monitoring/simple/docker-compose.yml \
		--profile simple up --remove-orphans --pull=always --build --force-recreate;";
