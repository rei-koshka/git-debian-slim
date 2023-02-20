ARG IMAGE_NAME="debian"
ARG IMAGE_TAG="stable-slim"

FROM ${IMAGE_NAME}:${IMAGE_TAG} as base

FROM base as build

WORKDIR /

ARG GIT_VERSION=2.39.2
ARG SUPPRESS_ERRORS=false

ENV SRC_NAME=git-${GIT_VERSION}
ENV ARCHIVE_NAME=${SRC_NAME}.tar.gz

RUN apt update && apt install -y \
    curl \
    cmake \
    gcc \
    dh-autoreconf \
    libcurl4-gnutls-dev \
    libexpat1-dev \
    gettext \
    libz-dev \
    libssl-dev \
    asciidoc \
    docbook2x \
    install-info && \
    rm -rf /var/lib/apt/lists/*

RUN curl https://mirrors.edge.kernel.org/pub/software/scm/git/${ARCHIVE_NAME} \
    -o ${ARCHIVE_NAME} && \
    tar -xzvf ${ARCHIVE_NAME} && \
    rm ${ARCHIVE_NAME}

RUN cd ${SRC_NAME} && \
    make configure && \
    ./configure --prefix=/usr

RUN cd ${SRC_NAME} && \
    make \
    all \
    doc \
    info || ${SUPPRESS_ERRORS}

RUN cd ${SRC_NAME} && \
    make \
    install \
    install-doc \
    install-html \
    install-info || ${SUPPRESS_ERRORS}

FROM base as final

WORKDIR /

COPY --from=build /usr/bin/git /usr/bin/git

CMD ["git"]
