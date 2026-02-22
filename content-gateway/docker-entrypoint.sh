#!/bin/sh
set -e

# Substitute environment variables in the Envoy config template
envsubst '${TENANT_ID} ${CLIENT_ID}' < /etc/envoy/envoy.template.yaml > /etc/envoy/envoy.yaml

# Start Envoy
exec envoy -c /etc/envoy/envoy.yaml
