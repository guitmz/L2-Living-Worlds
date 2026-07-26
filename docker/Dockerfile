FROM eclipse-temurin:25-jdk-noble AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends ant \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY ["L2J_Mobius_CT_0_Interlude github/", "./"]
RUN ant jar \
    && mkdir -p /opt/l2j/libs \
    && cp -a dist/libs/. /opt/l2j/libs/ \
    && cp -a /build/dist/libs/. /opt/l2j/libs/ \
    && find /opt/l2j/libs -name '*-sources.jar' -delete

# L2J compiles datapack scripts at runtime through javax.tools.JavaCompiler,
# which is only present in a full JDK image.
FROM eclipse-temurin:25-jdk-noble AS server

RUN groupadd --system l2j \
    && useradd --system --gid l2j --home-dir /opt/l2j l2j

COPY --from=builder --chown=l2j:l2j /opt/l2j /opt/l2j
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

WORKDIR /opt/l2j
USER l2j
EXPOSE 2106 7777
ENTRYPOINT ["docker-entrypoint.sh"]
