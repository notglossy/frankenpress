# FrankenPress Docker Image

A WordPress image built for simplicity and scale.

## Getting Started

- [Docker Images](https://hub.docker.com/r/notglossy/frankenpress "Docker Hub")

## Whats Included

### Services

- [WordPress](https://hub.docker.com/_/wordpress "WordPress Docker Image")
- [FrankenPHP](https://hub.docker.com/r/dunglas/frankenphp "FrankenPHP Docker Image")
- [Caddy](https://caddyserver.com/ "Caddy Server")

### Caching

- opcache
- APCu
- Memcache Extension
- Memcached Extension
- Redis Extension

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

It is good practice to avoid using root users in your Docker images for security purposes. If a questionable individual gets access into your running Docker container with root account then they could have access to the cluster and all the resources it manages. This could be problematic. On the other hand, by creating a user specific to the Docker image, narrows the threat to only the image itself. It is also important to note that the base WordPress images also create non-root users by default.


### How to use when behind load balancer or proxy?

_tldr: Use a port (ie :80, :8095, etc) for SERVER_NAME env variable._

Working in cloud environments like AWS can be tricky because your traffic is going through a load balancer or some proxy. This means your server name is not what you think your server name is. Your domain hits a proxy dns entry that then hits your application. The application doesn't know your domain. It knows the proxied name. This may seem strange, but it's actually a well established strong architecture pattern.

What about SSL cert? Use `SERVER_NAME=mydomain.com, :80`
Caddy, the underlying application server is flexible enough for multiple entries. Separate multiple values with a comma. It will still request certificate.
