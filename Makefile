docker-compose-monitoring-simple:
	@cd ./monitoring/simple; ./.init.sh; cd -;
	@UID=${UID} GID=${GID} bash -c "trap '\
		docker compose -f ./monitoring/simple/docker-compose.yml \
		--profile simple down --remove-orphans --volumes;' EXIT;\
		docker compose -f ./monitoring/simple/docker-compose.yml pull --parallel;\
		docker compose -f ./monitoring/simple/docker-compose.yml \
		--profile simple up --remove-orphans --build --force-recreate;";
