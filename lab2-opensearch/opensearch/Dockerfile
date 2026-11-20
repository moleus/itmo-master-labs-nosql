# OpenSearch with the Aiven Prometheus exporter plugin.
# The plugin version has the OpenSearch version plus one more number.
ARG OPENSEARCH_VERSION=3.9.0
FROM opensearchproject/opensearch:${OPENSEARCH_VERSION}
ARG PLUGIN_VERSION=3.9.0.0
RUN /usr/share/opensearch/bin/opensearch-plugin install --batch \
  https://github.com/Aiven-Open/prometheus-exporter-plugin-for-opensearch/releases/download/${PLUGIN_VERSION}/prometheus-exporter-${PLUGIN_VERSION}.zip
