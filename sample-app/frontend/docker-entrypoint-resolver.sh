#!/bin/sh
set -e

# nginx's resolver directive needs a literal IP, and the correct cluster
# DNS ClusterIP differs per environment (it comes from each cluster's own
# service CIDR, not a fixed value). Reading it from the pod's own
# /etc/resolv.conf at startup - which Kubernetes always populates
# correctly - means this works in any cluster automatically instead of
# needing a hardcoded, environment-specific value baked into the image.
RESOLVER_IP=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
if [ -z "$RESOLVER_IP" ]; then
  echo "docker-entrypoint-resolver.sh: no nameserver found in /etc/resolv.conf, refusing to start" >&2
  exit 1
fi

export RESOLVER_IP
envsubst '${RESOLVER_IP}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
