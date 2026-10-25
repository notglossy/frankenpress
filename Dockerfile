# =============================================================================
# FrankenPress - WordPress on FrankenPHP and Docker Hardened Images
# =============================================================================
# This Dockerfile creates a production-ready WordPress container using:
# - FrankenPHP: A modern PHP application server written in Go
# - Caddy: An automatic HTTPS server with integrated reverse proxy
# - WordPress: The world's most popular CMS
#
# Base images come from frankenpress-src, which builds PHP and FrankenPHP on
# Docker Hardened Images (dhi.io):
# - The -dev image is a full build environment (apt, compilers, PIE). PHP
#   extensions are compiled there, and fp-collect-runtime gathers /usr/local
#   plus every Debian package the result needs into /rootfs.
# - The runtime image is a clean dhi.io/debian-base with no package manager,
#   running as the nonroot user (UID 65532). /rootfs is copied onto it.
# =============================================================================

# -----------------------------------------------------------------------------
# Build Arguments
# -----------------------------------------------------------------------------
# These can be overridden at build time using --build-arg
# Example: docker build --build-arg PHP_VERSION=8.2 .
ARG WORDPRESS_VERSION=latest
ARG PHP_VERSION=8.4
# Only trixie is built.
ARG DEBIAN_VERSION=trixie
ARG SRC_IMAGE=ghcr.io/notglossy/frankenpress-src
# Override these to build against locally built frankenpress-src images, e.g.
# --build-arg BUILD_IMAGE=frankenpress-src:dhi-dev --build-arg RUNTIME_IMAGE=frankenpress-src:dhi
ARG BUILD_IMAGE=${SRC_IMAGE}:php${PHP_VERSION}-${DEBIAN_VERSION}-dev
ARG RUNTIME_IMAGE=${SRC_IMAGE}:php${PHP_VERSION}-${DEBIAN_VERSION}

# -----------------------------------------------------------------------------
# Stage 1: WordPress Source Files
# -----------------------------------------------------------------------------
# Pull WordPress core files from the official WordPress Docker image
# This stage is used only to extract files, not run WordPress
FROM wordpress:$WORDPRESS_VERSION AS wp

# -----------------------------------------------------------------------------
# Stage 2: Build PHP Extensions and Collect the Runtime Filesystem
# -----------------------------------------------------------------------------
FROM ${BUILD_IMAGE} AS build

# memcache has no PIE package, so it is built from its PECL release.
ARG MEMCACHE_VERSION=8.2

# -----------------------------------------------------------------------------
# PHP Extensions
# -----------------------------------------------------------------------------
# Bundled extensions (built as shared modules by the base image, enabled here):
# - bcmath: Arbitrary precision mathematics (WooCommerce, etc.)
# - exif: Image metadata extraction
# - gd: Image manipulation library
# - intl: Internationalization support
# - mysqli: MySQL database driver
# - zip: Archive handling
# OPcache is already enabled by the base image.
#
# PECL extensions, installed with PIE (https://github.com/php/pie):
# - igbinary/msgpack: Efficient serialization for caching (also enabled as
#   serializers in redis and memcached). igbinary 3.2.16 doesn't compile on
#   PHP 8.5 and only 3.2.17RC1 is on Packagist, so RCs are allowed for it.
# - apcu: In-memory user cache
# - imagick: Advanced image processing (alternative to GD)
# - redis: Object caching and sessions
# - memcached: Object caching backend
# - memcache: Object caching backend, PHP < 8.5 only (its latest PECL release
#   doesn't compile on 8.5)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ghostscript \
        libheif-plugin-aomenc \
        libmagickwand-dev \
        libmemcached-dev \
        libtool \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    for ext in bcmath exif gd intl mysqli zip; do \
        echo "extension=$ext" > "$PHP_INI_DIR/conf.d/$ext.ini"; \
    done; \
    pie install 'igbinary/igbinary:^3.2.17@RC'; \
    pie install msgpack/msgpack-php; \
    pie install apcu/apcu; \
    pie install imagick/imagick; \
    pie install phpredis/phpredis --enable-redis-igbinary --enable-redis-msgpack; \
    pie install php-memcached/php-memcached --enable-memcached-igbinary --enable-memcached-msgpack; \
    if php -r 'exit(PHP_VERSION_ID < 80500 ? 0 : 1);'; then \
        mkdir /tmp/memcache; \
        curl -fsSL "https://pecl.php.net/get/memcache-${MEMCACHE_VERSION}.tgz" | tar -xz -C /tmp/memcache --strip-components=1; \
        (cd /tmp/memcache && phpize && ./configure && make -j "$(nproc)" && make install); \
        rm -rf /tmp/memcache; \
        echo 'extension=memcache' > "$PHP_INI_DIR/conf.d/80-memcache.ini"; \
    fi; \
    find "$(php-config --extension-dir)" -name '*.so' -exec strip --strip-unneeded {} +; \
    php -m

# -----------------------------------------------------------------------------
# PHP Configuration
# -----------------------------------------------------------------------------
# 1. Base PHP.ini: Start with production-recommended settings
# 2. OpCache settings: Configure bytecode caching for performance
#    - memory_consumption: 128MB for caching compiled scripts
#    - interned_strings_buffer: 8MB for string interning
#    - max_accelerated_files: Cache up to 4000 files
#    - revalidate_freq: Check for changes every 2 seconds
#    See: https://www.php.net/manual/en/opcache.configuration.php
#
# 3. Error logging: Production-safe error handling
#    - Errors logged to stderr for container log aggregation
#    - Display errors disabled for security
#    - Comprehensive error reporting enabled
#    See: https://github.com/docker-library/wordpress/issues/420
#
# 4. Security: Hide PHP version from HTTP headers
RUN cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini \
    && { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini \
    && { \
        echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
        echo 'display_errors = Off'; \
        echo 'display_startup_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_log = /dev/stderr'; \
        echo 'log_errors_max_len = 1024'; \
        echo 'ignore_repeated_errors = On'; \
        echo 'ignore_repeated_source = Off'; \
        echo 'html_errors = Off'; \
    } > $PHP_INI_DIR/conf.d/error-logging.ini \
    && echo 'expose_php = Off' > $PHP_INI_DIR/conf.d/expose_php.ini

# -----------------------------------------------------------------------------
# WP-CLI Installation
# -----------------------------------------------------------------------------
# WordPress Command Line Interface for managing WordPress from the terminal.
# Useful for plugin/theme management, database operations, and automation.
# See: https://wp-cli.org/
RUN curl -fsSLo /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# -----------------------------------------------------------------------------
# WordPress Core Files
# -----------------------------------------------------------------------------
# Copy WordPress core files from the official WordPress image.
# This includes:
# - /usr/src/wordpress: WordPress core files (copied to /var/www/html on start)
# - docker-entrypoint.sh: WordPress initialization script
#
# PHP configuration is deliberately NOT copied: the WordPress image is built
# against a different PHP version, and its docker-php-ext-*.ini loaders would
# break extensions here.
COPY --from=wp /usr/src/wordpress /rootfs/usr/src/wordpress
COPY --from=wp /usr/local/bin/docker-entrypoint.sh /usr/local/bin/

# -----------------------------------------------------------------------------
# WordPress and Entrypoint Customization
# -----------------------------------------------------------------------------
# Modify the WordPress Docker entrypoint to work with FrankenPHP instead of PHP-FPM.
# Also inject WordPress configuration:
# - FORCE_HTTPS support: Enables HTTPS when FORCE_HTTPS env var is set
# - FS_METHOD=direct: Direct filesystem access (no FTP needed)
# - set_time_limit(300): Allow long-running operations (imports, updates, etc.)
RUN sed -i \
        -e 's/\[ "$1" = '\''php-fpm'\'' \]/\[\[ "$1" == frankenphp* \]\]/g' \
        -e 's/php-fpm/frankenphp/g' \
        /usr/local/bin/docker-entrypoint.sh \
    && sed -i 's/<?php/<?php if (!!getenv("FORCE_HTTPS")) { \$_SERVER["HTTPS"] = "on"; } define( "FS_METHOD", "direct" ); set_time_limit(300); /g' /rootfs/usr/src/wordpress/wp-config-docker.php

# -----------------------------------------------------------------------------
# Runtime Filesystem
# -----------------------------------------------------------------------------
# fp-collect-runtime copies /usr/local (PHP, extensions, config, WP-CLI,
# entrypoint), every Debian package whose libraries it needs, and those
# packages' dependencies into /rootfs. That covers ImageMagick's coder modules
# and config (imagemagick-7-common) and the libheif decoder plugins.
# Extra runtime packages, which nothing depends on:
# - ghostscript: PDF thumbnails through Imagick
# - libheif-plugin-aomenc: AVIF encoding
# - mawk: docker-entrypoint.sh uses awk to generate wp-config.php salts
#
# /var/www/html is created owned by the nonroot user (UID 65532).
RUN set -eux; \
    fp-collect-runtime /rootfs \
        ghostscript \
        libheif-plugin-aomenc \
        mawk \
    ; \
    ln -s mawk /rootfs/usr/bin/awk; \
    install -d -o 65532 -g 65532 /rootfs/var/www/html

# -----------------------------------------------------------------------------
# Stage 3: Final FrankenPress Image
# -----------------------------------------------------------------------------
FROM ${RUNTIME_IMAGE}

# -----------------------------------------------------------------------------
# Metadata Labels
# -----------------------------------------------------------------------------
# OCI-compliant image labels for container registries and tooling
# See: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title=FrankenPress \
      org.opencontainers.image.description="Optimized WordPress containers to run everywhere. Built with FrankenPHP & Caddy." \
      org.opencontainers.image.source=https://github.com/notglossy/frankenpress \
      org.opencontainers.image.licenses=MIT \
      org.opencontainers.image.vendor="Not Glossy"

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
# FORCE_HTTPS: Set to 1 to force HTTPS in WordPress (sets $_SERVER['HTTPS'])
# PAGER: Pager for WP-CLI help (the runtime image has no more or less)
ENV FORCE_HTTPS=0 \
    PAGER=cat

COPY --from=build /rootfs/ /

# -----------------------------------------------------------------------------
# Custom Configuration Files
# -----------------------------------------------------------------------------
# These files are copied last as they're most likely to change during development.
# Placing them here maximizes Docker build cache efficiency.
#
# - php.ini: WordPress-specific PHP settings (upload size, execution time, etc.)
# - Caddyfile: Caddy web server configuration (routing, headers, compression)
COPY php.ini $PHP_INI_DIR/conf.d/wp.ini
COPY Caddyfile /etc/caddy/Caddyfile

# -----------------------------------------------------------------------------
# Container Runtime Configuration
# -----------------------------------------------------------------------------
# Runs as the base image's nonroot user (UID/GID 65532), which owns
# /var/www/html, /data and /config.
#
# NOTE: On some platforms (e.g., AWS ECS), volume mounts are owned by root.
# Make sure the volume is writable by UID 65532.
VOLUME /var/www/html
WORKDIR /var/www/html
USER 65532

# -----------------------------------------------------------------------------
# Entrypoint and Command
# -----------------------------------------------------------------------------
# Entrypoint: WordPress initialization script
# Command: Start FrankenPHP server with Caddy configuration
#
# The entrypoint handles:
# - Copying WordPress core files to /var/www/html if not present
# - Generating wp-config.php from WORDPRESS_* environment variables
#
# To override the command (e.g., for debugging):
# docker run -it frankenpress bash
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
