ifneq ("$(wildcard .env)", "")
    include .env
endif

# Domyślne nazwy kontenerów — można nadpisać w .env
DOCKER_PHP_FPM ?= php-fpm
DOCKER_NODE ?= node
DOCKER_WEBSERVER ?= webserver
DOCKER_MYSQL ?= mysql

CURRENT_USER_ID = $(shell id --user)
CURRENT_USER_GROUP_ID = $(shell id --group)

.PHONY: init set-app-name

check-env:
	@if [ ! -f .env ]; then \
		echo ".env nie istnieje. Użyj make init przed wykonaniem tego kroku."; \
		exit 1; \
	fi

check-laravel:
	@if [ -f artisan ]; then \
		echo "Laravel jest już zainstalowany."; \
		exit 1; \
	fi

check-is-laravel:
	@if [ ! -f artisan ]; then \
		echo "Laravel nie jest zainstalowany. Użyj make laravel."; \
		exit 1; \
	fi

init:
	@if [ -f .env ]; then \
    	read -p ".env już istnieje. Nadpisać? (t/n): " CONFIRM; \
    	if [ "$$CONFIRM" = "t" ]; then \
    		cp .env.example .env; \
    		echo "Utworzono .env"; \
    		make set-app-name; \
    	else \
    		echo "Anulowano."; \
    	fi; \
    else \
    	cp .env.example .env; \
    	echo "Utworzono .env"; \
    	make set-app-name; \
    fi

set-app-name: check-env
	@if [ -f .env ]; then \
		read -p "Podaj nazwę aplikacji: " APP_NAME2; \
		APP_NAME2=$$(echo "$$APP_NAME2" | sed 's/ /_/g'); \
		if grep -q "^APP_NAME=" .env; then \
			sed -i "s/^APP_NAME=.*/APP_NAME=$$APP_NAME2/" .env \
		else \
			echo "APP_NAME=$$APP_NAME2" >> .env; \
		fi; \
		echo "Zmieniono nazwę aplikacji na $$APP_NAME2 w pliku .env"; \
	fi

up: check-env
	docker-compose up -d

rebuild: check-env
	docker-compose rm -vsf
	docker-compose down -v --remove-orphans
	docker-compose build
	docker-compose up -d
	docker exec --user root ${DOCKER_PHP_FPM} bash -c "chmod -R 777 /application/storage /application/bootstrap/cache"

down: check-env
	docker-compose down

laravel: check-env check-laravel up
	echo "Instalowanie Laravel w kontenerze ${DOCKER_PHP_FPM}..."
	# tworzymy projekt w katalogu tymczasowym i przenosimy zawartość bez przerywania, obsługując brak plików
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "composer create-project --prefer-dist laravel/laravel Laravel"
	# usuwamy kilka plików jeśli istnieją (bez przerywania make)
	[ -f ./Laravel/vite.config.js ] && rm -f ./Laravel/vite.config.js || true
	[ -f ./Laravel/.env ] && rm -f ./Laravel/.env || true
	[ -f ./Laravel/README.md ] && rm -f ./Laravel/README.md || true
	[ -f ./Laravel/.env.example ] && rm -f ./Laravel/.env.example || true
	[ -f ./Laravel/.gitignore ] && rm -f ./Laravel/.gitignore || true
	# przenosimy pliki (ignorujemy brak ukrytych plików jeśli żadne nie istnieją)
	mv -v ./Laravel/* ./ || true
	mv -v ./Laravel/.[!.]* ./ || true
	rm -rf ./Laravel || true
	# ustawianie uprawnień przez kontener (bez sudo) — wykonujemy jako root wewnątrz kontenera
	docker exec --user root ${DOCKER_PHP_FPM} bash -c "chown -R ${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID} /application/storage /application/bootstrap/cache || true"
	docker exec --user root ${DOCKER_PHP_FPM} bash -c "chmod -R ug+rwX /application/storage /application/bootstrap/cache || true"
	mv  ./welcome.blade.php ./resources/views/ || true
	mkdir -p public/assets/css
	touch public/assets/css/style.css
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan key:generate"
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan storage:link"
	sleep 5
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan migrate --force"
	# ponownie napraw uprawnienia (na wypadek, gdyby artisan utworzył pliki)
	docker exec --user root ${DOCKER_PHP_FPM} bash -c "chown -R ${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID} /application/storage /application/bootstrap/cache || true"
	docker exec --user root ${DOCKER_PHP_FPM} bash -c "chmod -R ug+rwX /application/storage /application/bootstrap/cache || true"
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan config:clear"
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan route:clear"
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan view:clear"
	make node-install
	echo "Instalacja Laravel zakończona."
	make dev

php: check-env
	docker exec -it --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} /bin/bash

node-install: up
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_NODE} npm install
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_NODE} npm install tailwindcss @tailwindcss/vite

dev: up
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_NODE} npm run dev

build: up
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_NODE} npm run build

filament-install: check-env check-is-laravel up
	# bezpieczniejsze cytowanie dla composer require
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c 'composer require "filament/filament:^4.0" -W'
	docker exec -it --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan filament:install --panels"
	docker exec -it --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan make:filament-user"
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan optimize"

clear: check-env check-is-laravel up
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan config:clear"
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan route:clear"
	docker exec --user "${CURRENT_USER_ID}:${CURRENT_USER_GROUP_ID}" ${DOCKER_PHP_FPM} bash -c "php artisan view:clear"