# --------------------------------------
# Apache Web Server for i2b2/AKTIN
# Version:      1.0
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         16 Dec 24
# Purpose:      Provides web interface for i2b2 with PHP support and reverse proxy
#               configuration for AKTIN emergency department system integration.
# --------------------------------------

FROM php:__APACHE_VERSION__

# Build-time metadata
LABEL org.opencontainers.image.title="AKTIN Apache2"
LABEL org.opencontainers.image.description="Apache/PHP web server with i2b2 interface and AKTIN integration"
LABEL org.opencontainers.image.authors="shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de"
LABEL org.opencontainers.image.version="__DWH_DEBIAN_RELEASE__-docker__HTTPD_CONTAINER_VERSION__"
LABEL org.opencontainers.image.vendor="AKTIN"

# PHP and Apache configuration
COPY ./webclient /var/www/html/webclient
COPY ./aktin-j2ee-reverse-proxy.conf /etc/apache2/conf-available/

# Enable the recommended production PHP settings
# Install required PHP extensions for database interaction
# Enable Apache mod_rewrite for URL rewriting and proxy_http module
# Activate the AKTIN reverse proxy configuration
RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
  && docker-php-ext-install pdo pdo_mysql \
  && a2enmod rewrite proxy_http \
  && a2enconf aktin-j2ee-reverse-proxy
