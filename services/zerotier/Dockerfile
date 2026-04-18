# syntax=docker/dockerfile:1
FROM zerotier/zerotier:latest

COPY networks.conf /etc/zerotier/networks.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/var/lib/zerotier-one"]

ENTRYPOINT ["/entrypoint.sh"]
