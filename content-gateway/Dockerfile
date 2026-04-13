FROM envoyproxy/envoy:v1.37-latest
COPY envoy.yaml /etc/envoy/envoy.template.yaml

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 500 /docker-entrypoint.sh

RUN apt-get update && \
  apt-get install gettext -y

ENTRYPOINT ["/docker-entrypoint.sh"]
