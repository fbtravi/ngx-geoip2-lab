FROM nginx:1.26.2-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        libmaxminddb0 \
        curl \
    && rm -rf /var/lib/apt/lists/*

# pre-built geoip2 dynamic modules (ngx_http_geoip2_module + ngx_stream_geoip2_module)
# downloaded from the leev/ngx_http_geoip2_module releases, or built locally — see README
COPY modules/ngx_http_geoip2_module.so /usr/lib/nginx/modules/

COPY nginx.conf /etc/nginx/nginx.conf

# databases are bind-mounted at runtime from ./db
RUN mkdir -p /etc/nginx/geoip
