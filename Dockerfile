FROM nginx:1.26.2-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libmaxminddb-dev \
        libpcre3-dev \
        zlib1g-dev \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# nginx source matching the running version
RUN curl -fsSL https://nginx.org/download/nginx-1.26.2.tar.gz | tar xz -C /usr/src

# geoip2 module source (upstream)
RUN curl -fsSL https://github.com/leev/ngx_http_geoip2_module/archive/refs/heads/master.tar.gz \
    | tar xz -C /usr/src \
    && mv /usr/src/ngx_http_geoip2_module-master /usr/src/ngx_http_geoip2_module

RUN cd /usr/src/nginx-1.26.2 \
    && ./configure --with-compat \
        --add-dynamic-module=/usr/src/ngx_http_geoip2_module \
    && make modules

FROM nginx:1.26.2-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        libmaxminddb0 \
        curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/nginx-1.26.2/objs/ngx_http_geoip2_module.so /usr/lib/nginx/modules/

COPY nginx.conf /etc/nginx/nginx.conf

# databases are bind-mounted at runtime from ./db
RUN mkdir -p /etc/nginx/geoip
