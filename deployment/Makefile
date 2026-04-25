SHELL:=/bin/bash
VERSION:=1.0.0
MODE:=dev
RUN_ENV:=local
KEYCLOAK_HOSTNAME:=keycloak.leduynhan1201.dev
MAKEFILE_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT:=$(abspath $(MAKEFILE_DIR)/..)
SCRIPT_DIR:=$(PROJECT_ROOT)/scripts/$(RUN_ENV)

dev-auth:
	docker exec -it -uroot auth-service bash -c 'cd /app && ./gradlew quarkusDev -DdebugHost=0.0.0.0 -DskipTests';

build-images:
	docker build -f ../../src/auth/src/main/docker/Dockerfile.builder -t quarkus/auth-builder ../..
	docker build -f ../../src/concert/src/main/docker/Dockerfile.builder -t quarkus/concert-builder ../..
	docker build -f ../../src/booking/src/main/docker/Dockerfile.builder -t quarkus/booking-builder ../..

remove-images:
	docker rmi quarkus/auth-builder
	docker rmi quarkus/concert-builder
	docker rmi quarkus/booking-builder

export-realm:
	@if [ -z "$(REALM)" ]; then \
		echo "REALM is required. Use: make export-realm REALM=myrealm"; \
		exit 1; \
	fi
	@echo "Exporting realm $(REALM)..."
	@docker exec keycloak0 /opt/keycloak/bin/kc.sh export \
		--realm $(REALM) \
		--dir /opt/keycloak/data/export \
		--users realm_file
	@echo "Done."

.PHONY: prepare
prepare:
	@echo "Preparing environment..."
	@sudo apt-get update -y
	@sudo apt-get install -y make openjdk-17-jdk
	@find $(SCRIPT_DIR) -type f -name "*.sh" -exec chmod +x {} \;

renew-certs:
	@if [ -z "$(SERVER_NAME)" ]; then \
		echo "SERVER_NAME is required. Use: make renew-certs SERVER_NAME=kafka"; \
		exit 1; \
	fi
	@echo "Generating $(SERVER_NAME) certificates..."
	@$(SCRIPT_DIR)/renew_certs.sh $(MODE) $(SERVER_NAME)

rebuild-images:
	@echo "Rebuild local images..."
	@$(SCRIPT_DIR)/rebuild_images.sh $(MODE)

.PHONY: init
init:
	@echo "Initializing environment..."
	@$(SCRIPT_DIR)/init.sh $(MODE)
	@sudo cp $(PROJECT_ROOT)/secrets/certs/ca/ca.crt /usr/local/share/ca-certificates/ldnhanCA.crt
	@sudo update-ca-certificates

.PHONY: clean
clean:
	@echo "Cleaning all..."
	@$(SCRIPT_DIR)/clean.sh $(MODE)

.PHONY: start
start:
	@echo "Starting containers..."
	@$(SCRIPT_DIR)/start.sh $(MODE)

.PHONY: stop
stop:
	@echo "Stopping containers..."
	@$(SCRIPT_DIR)/stop.sh $(MODE)

check-connect:
	@openssl s_client -connect $(KEYCLOAK_HOSTNAME):443 -servername $(KEYCLOAK_HOSTNAME)
