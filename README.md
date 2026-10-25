# FrankenPress Docker Image

![PHP 8.5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fnotglossy%2Ffrankenpress%2Fbadges%2Fphp-8.5.json) ![PHP 8.4](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fnotglossy%2Ffrankenpress%2Fbadges%2Fphp-8.4.json) ![PHP 8.3](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fnotglossy%2Ffrankenpress%2Fbadges%2Fphp-8.3.json) ![PHP 8.2](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fnotglossy%2Ffrankenpress%2Fbadges%2Fphp-8.2.json)

A WordPress image built for simplicity and scale, powered by FrankenPHP and Caddy.

## Quick Start

```bash
docker run -d \
  -p 80:80 \
  -e DB_HOST=your-db-host \
  -e DB_USER=wordpress \
  -e DB_PASSWORD=your-password \
  -e DB_NAME=wordpress \
  notglossy/frankenpress:latest
```

## Available Images

### Standard Images
- `notglossy/frankenpress:latest` - Latest (PHP 8.4) on Debian Trixie (amd64, arm64)
- `notglossy/frankenpress:php-8.5-trixie` - PHP 8.5 on Debian Trixie (amd64, arm64)
- `notglossy/frankenpress:php-8.4-trixie` - PHP 8.4 on Debian Trixie (amd64, arm64)
- `notglossy/frankenpress:php-8.3-trixie` - PHP 8.3 on Debian Trixie (amd64, arm64)
- `notglossy/frankenpress:php-8.2-trixie` - PHP 8.2 on Debian Trixie (amd64, arm64)

### VIPS Images (with FFI support for advanced image processing)
- `notglossy/frankenpress:vips-ffi` - Latest VIPS (PHP 8.4) on Debian Trixie (amd64, arm64)
- `notglossy/frankenpress:php-8.5-vips-ffi-trixie` - PHP 8.5 VIPS on Debian Trixie (amd64, arm64)
- `notglossy/frankenpress:php-8.4-vips-ffi-trixie` - PHP 8.4 VIPS on Debian Trixie (amd64, arm64)

All images are built on [Docker Hardened Images](https://www.docker.com/products/hardened-images/) (Debian 13 Trixie) through [frankenpress-src](https://github.com/notglossy/frankenpress-src). Debian Bookworm and 32-bit ARM (arm/v7) images are no longer built.

**Migrating from Bookworm:** the `bookworm`, `php-*-bookworm` and `vips-ffi-bookworm` tags are still published but no longer rebuilt, so they won't get Debian, PHP or WordPress security updates. Switch to the matching `-trixie` tag (e.g. `php-8.4-bookworm` → `php-8.4-trixie`). There is no replacement for arm/v7.

## Performance & Build Optimization

Standard image arm64 builds run on native GitHub-hosted ARM runners (`ubuntu-24.04-arm`) for maximum performance and speed. This eliminates QEMU emulation overhead, resulting in significantly faster build times.

## Links

- [Docker Hub](https://hub.docker.com/r/notglossy/frankenpress)
- [GitHub Repository](https://github.com/notglossy/frankenpress)

## What's Included

### Core Components

- **[WordPress](https://wordpress.org/)** - Latest version from official WordPress Docker images
- **[FrankenPHP](https://frankenphp.dev/)** - Modern PHP application server (custom builds from [frankenpress-src](https://github.com/notglossy/frankenpress-src))
- **[Docker Hardened Images](https://www.docker.com/products/hardened-images/)** - Minimal Debian runtime with no package manager, running as a non-root user
- **[Caddy](https://caddyserver.com/)** - Fast, secure web server with automatic HTTPS
- **PHP Extensions** - Optimized selection for WordPress performance

### PHP Extensions & Caching

**Performance & Caching:**
- OPcache (configured for production)
- APCu
- Memcache (PHP 8.4 and earlier)
- Memcached
- Redis
- igbinary
- msgpack

**WordPress Essentials:**
- bcmath
- exif
- gd
- intl
- mysqli
- zip
- imagick

Imagick supports JPEG, PNG, GIF, WebP, AVIF, HEIC (decoding) and PDF (through Ghostscript). SVG, WMF, DjVu and OpenEXR are not included.

**VIPS Images Only:**
- FFI (Foreign Function Interface)
- libvips (high-performance image processing), built from source with only the formats WordPress uses: JPEG, PNG, GIF, WebP, HEIF/HEIC/AVIF and JPEG XL. Other formats (OpenEXR, PDF, SVG, TIFF, scientific formats) are left out to keep the image small and its vulnerability surface low. The libvips and plugin releases are pinned with checksums in `Dockerfile.vips-ffi`; a weekly workflow (`bump-dependencies.yml`) opens a PR when either has a new release
- [vips-image-editor-ffi](https://github.com/notglossy/vips-image-editor-ffi) WordPress plugin

### Environment Variables

#### FrankenPHP

- `SERVER_NAME`: change the addresses on which to listen, the provided hostnames will also be used for the generated TLS certificate
- `CADDY_GLOBAL_OPTIONS`: inject global options (debug most common)
- `FRANKENPHP_CONFIG`: inject config under the frankenphp directive

#### Wordpress

- `DB_NAME`: The WordPress database name.
- `DB_USER`: The WordPress database user.
- `DB_PASSWORD`: The WordPress database password.
- `DB_HOST`: The WordPress database host.
- `DB_TABLE_PREFIX`: The WordPress database table prefix.
- `WP_DEBUG`: Turns on WordPress Debug.
- `FORCE_HTTPS`: Tells WordPress to use https on requests. This is beneficial behind load balancer. Defaults to true.
- `WORDPRESS_CONFIG_EXTRA`: use this for adding WP_HOME, WP_SITEURL, etc

## Questions

### Why Not Just Use Standard WordPress Images?

The standard WordPress images are a good starting point and can handle many use cases, but require significant modification to scale. You also don't get FrankenPHP app server. Instead, you need to choose Apache or PHP-FPM. We use the WordPress base image but extend it with FrankenPHP & Caddy.

### Why FrankenPHP?

FrankenPHP is built on Caddy, a modern web server built in Go. It is secure & performs well when scaling becomes important. It also allows us to take advantage of built-in mature concurrency through goroutines into a single Docker image. high performance in a single lean image.

**[Check out FrankenPHP Here](https://frankenphp.dev/ "FrankenPHP")**

### Why is Non-Root User Important?

It is good practice to avoid using root users in your Docker images for security purposes. If a questionable individual gets access into your running Docker container with root account then they could have access to the cluster and all the resources it manages. This could be problematic. Running as an unprivileged user narrows the threat to only the image itself.

FrankenPress runs as the Docker Hardened Images `nonroot` user (UID/GID 65532). FrankenPHP can still bind ports 80 and 443. Volumes mounted at `/var/www/html` must be writable by UID 65532; on platforms that mount volumes owned by root (e.g. AWS ECS), set the ownership or permissions accordingly.

### How do I add packages or PHP extensions?

The runtime image has no package manager (`apt-get`), compiler or `install-php-extensions`. Install packages in the matching frankenpress-src `-dev` image, then copy them onto FrankenPress with `fp-collect-runtime`, which copies the named packages plus every Debian package their libraries need:

```dockerfile
FROM notglossy/frankenpress:php-8.4-trixie AS base

FROM ghcr.io/notglossy/frankenpress-src:php8.4-trixie-dev AS build
# Skip packages FrankenPress already ships
COPY --from=base /var/lib/dpkg/status.d /usr/local/share/frankenpress/base-status.d
RUN apt-get update && apt-get install -y --no-install-recommends less \
    && fp-collect-runtime /rootfs less \
    # /usr/local (PHP, extensions, config) comes from the base image
    && rm -rf /rootfs/usr/local

FROM base
COPY --from=build /rootfs/ /
```

PHP extensions are compiled with [PIE](https://github.com/php/pie) in the `-dev` image; see `Dockerfile` for how the bundled extensions are built and collected, and `Dockerfile.vips-ffi` for a complete example of extending the image.


### How to use when behind load balancer or proxy?

_tldr: Use a port (ie :80, :8095, etc) for SERVER_NAME env variable._

Working in cloud environments like AWS can be tricky because your traffic is going through a load balancer or some proxy. This means your server name is not what you think your server name is. Your domain hits a proxy dns entry that then hits your application. The application doesn't know your domain. It knows the proxied name. This may seem strange, but it's actually a well established strong architecture pattern.

What about SSL cert? Use `SERVER_NAME=mydomain.com, :80`
Caddy, the underlying application server is flexible enough for multiple entries. Separate multiple values with a comma. It will still request certificate.
