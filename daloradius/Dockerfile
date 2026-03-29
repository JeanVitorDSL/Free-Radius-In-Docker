FROM php:8.1-apache-bookworm

RUN apt-get update && apt-get install -y \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libzip-dev \
        default-mysql-client \
        git \
        unzip \
        curl \
        php-pear \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        gettext \
    && rm -rf /var/lib/apt/lists/*

RUN pear channel-update pear.php.net && \
    pear install --force DB && \
    cp /usr/share/php/DB.php /usr/local/lib/php/DB.php && \
    cp -r /usr/share/php/DB /usr/local/lib/php/DB && \
    cp /usr/share/php/PEAR.php /usr/local/lib/php/PEAR.php && \
    cp -r /usr/share/php/PEAR /usr/local/lib/php/PEAR

RUN git clone --depth 1 --branch master \
    https://github.com/lirantal/daloradius.git \
    /var/www/html/daloradius && \
    chown -R www-data:www-data /var/www/html/daloradius && \
    chmod -R 755 /var/www/html/daloradius

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN echo '<VirtualHost *:80>\n\
    DocumentRoot /var/www/html/daloradius/app/users\n\
    ServerName daloradius\n\
    <Directory /var/www/html/daloradius>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    Alias /operators /var/www/html/daloradius/app/operators\n\
    <Directory /var/www/html/daloradius/app/operators>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

RUN a2enmod rewrite

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]