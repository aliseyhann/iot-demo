FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONTIKI_DIR=/opt/contiki-ng

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    git \
    make \
    net-tools \
    python3 \
    iproute2 \
    iputils-ping \
    procps \
    socat \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/contiki-ng/contiki-ng ${CONTIKI_DIR}

WORKDIR /contiki_client

COPY run-contiki.sh /contiki_client/run-contiki.sh
COPY project-conf.h.template /contiki_client/project-conf.h.template

RUN chmod +x /contiki_client/run-contiki.sh

ENTRYPOINT ["/contiki_client/run-contiki.sh"]
