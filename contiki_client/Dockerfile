FROM ubuntu:24.04

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV CONTIKI_DIR=/home/user/contiki-ng

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    make \
    ca-certificates \
    net-tools \
    socat \
    iproute2 \
    iputils-ping \
    procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN if [ ! -f "${CONTIKI_DIR}/Makefile.include" ]; then \
      rm -rf "${CONTIKI_DIR}" && \
      git clone --depth 1 https://github.com/contiki-ng/contiki-ng "${CONTIKI_DIR}"; \
    fi

WORKDIR /contiki_client

COPY run-contiki.sh /contiki_client/run-contiki.sh

RUN chmod +x /contiki_client/run-contiki.sh

ENTRYPOINT ["/contiki_client/run-contiki.sh"]
