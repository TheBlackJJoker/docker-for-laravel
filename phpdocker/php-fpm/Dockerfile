FROM phpdockerio/php:8.2-fpm
WORKDIR "/application"

ARG USER_NAME=host-user
ARG USER_ID=1000
ARG PHP_FPM_GROUP=www-data

RUN if getent passwd ${USER_ID} > /dev/null; then \
        EXISTING_USER=$(getent passwd ${USER_ID} | cut -d: -f1); \
        echo "UID ${USER_ID} already exists, using user ${EXISTING_USER}."; \
        USER_NAME=${EXISTING_USER}; \
    else \
        echo "UID ${USER_ID} not found, creating new user ${USER_NAME}."; \
        adduser --disabled-password --uid ${USER_ID} ${USER_NAME}; \
    fi && \
    if getent group ${USER_ID} > /dev/null; then \
        EXISTING_GROUP=$(getent group ${USER_ID} | cut -d: -f1); \
        echo "GID ${USER_ID} already exists for group ${EXISTING_GROUP}, skipping groupmod."; \
    else \
        echo "GID ${USER_ID} not found, modifying group ${PHP_FPM_GROUP}."; \
        groupmod --gid ${USER_ID} ${PHP_FPM_GROUP}; \
    fi && \
    echo "Adding user ${USER_NAME} to group ${PHP_FPM_GROUP}."; \
    usermod --append --groups ${PHP_FPM_GROUP} ${USER_NAME}

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        git \
        php8.2-bcmath \
        php8.2-gd \
        php8.2-mysql \
        php8.2-intl \
        php8.2-xdebug; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=composer/composer:latest-bin /composer /usr/bin/composer
