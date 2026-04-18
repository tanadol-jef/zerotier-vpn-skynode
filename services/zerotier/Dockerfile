# syntax=docker/dockerfile:1
FROM zerotier/zerotier:latest

ARG ZEROTIER_NETWORK_ID

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/var/lib/zerotier-one"]

ENTRYPOINT ["/entrypoint.sh"]
