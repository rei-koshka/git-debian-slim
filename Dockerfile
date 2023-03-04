ARG SRC_TYPE=remote
ARG WITH_DOCS=true
ARG WITH_ADDONS=true

FROM debian:stable-slim as base

ARG GIT_VERSION=2.39.2
ARG SUPPRESS_ERRORS=false

ENV SRC_NAME=git-${GIT_VERSION}

RUN apt-get update && \
    apt-get install -y \
    libcurl4-gnutls-dev

FROM base as fetch_src_remote

WORKDIR /

ONBUILD ENV ARCHIVE_NAME=${SRC_NAME}.tar.gz

ONBUILD RUN apt-get install -y \
            curl

ONBUILD RUN curl https://mirrors.edge.kernel.org/pub/software/scm/git/${ARCHIVE_NAME} \
            -o ${ARCHIVE_NAME} && \
            tar -xzvf ${ARCHIVE_NAME} && \
            rm ${ARCHIVE_NAME}

FROM base as fetch_src_local

ONBUILD WORKDIR /

ONBUILD COPY ./src ./${SRC_NAME}

FROM fetch_src_${SRC_TYPE} as build_git

WORKDIR /

RUN apt-get install -y \
    cmake \
    gcc \
    dh-autoreconf \
    libz-dev \
    libssl-dev

RUN if ${WITH_DOCS}; then \
    apt-get install -y \
    libexpat1-dev \
    gettext \
    asciidoc \
    docbook2x \
    install-info \
    ; fi

RUN cd ${SRC_NAME} && \
    make configure && \
    ./configure --prefix=/usr

RUN cd ${SRC_NAME} && \
    if ! ${WITH_ADDONS}; then \
    export NO_PERL=1 && \
    export NO_PYTHON=1 && \
    export NO_TCLTK=1 && \
    export NO_GITWEB=1 \
    ; fi \
    && \
    if ${WITH_DOCS}; then \
    make \
    all \
    doc \
    info \
    ; else \
    export NO_GETTEXT=1 && \
    export NO_EXPAT=1 && \
    make \
    all \
    ; fi \
    || ${SUPPRESS_ERRORS}

RUN cd ${SRC_NAME} && \
    if ! ${WITH_ADDONS}; then \
    export NO_PERL=1 && \
    export NO_PYTHON=1 && \
    export NO_TCLTK=1 && \
    export NO_GITWEB=1 \
    ; fi \
    && \
    if ${WITH_DOCS}; then \
    make \
    install \
    install-doc \
    install-html \
    install-info \
    ; else \
    export NO_GETTEXT=1 && \
    export NO_EXPAT=1 && \
    make \
    install \
    ; fi \
    || ${SUPPRESS_ERRORS}

FROM base as git_install

WORKDIR /

RUN apt-get install -y \
    openssh-client \
    less

COPY --from=build_git /usr/bin/git* /usr/bin/
COPY --from=build_git /usr/libexec/git-core /usr/libexec/git-core
COPY --from=build_git /usr/share/git-core /usr/share/git-core

FROM git_install as build_lfs

WORKDIR /

RUN apt-get install -y \
    make \
    golang

ARG LFS_VERSION=3.3.0

RUN git config --global advice.detachedHead false && \
    git clone https://github.com/git-lfs/git-lfs.git \
    --branch="v${LFS_VERSION}" \
    --depth=1

RUN cd "git-lfs" && \
    make

FROM git_install as git_with_docs_false

ONBUILD WORKDIR /

ONBUILD RUN echo "Skip copying of docs"

FROM git_install as git_with_docs_true

WORKDIR /

ONBUILD RUN apt-get install -y \
            man

ONBUILD COPY --from=build_git /usr/share/doc/git* /usr/share/doc/
ONBUILD COPY --from=build_git /usr/share/texlive /usr/share/texlive
ONBUILD COPY --from=build_git /usr/share/info /usr/share/info
ONBUILD COPY --from=build_git /usr/share/locale /usr/share/locale
ONBUILD COPY --from=build_git /usr/share/man /usr/share/man

FROM git_with_docs_${WITH_DOCS} as git_with_addons_false

ONBUILD WORKDIR /

ONBUILD RUN echo "Skip copying of add-ons"

FROM git_with_docs_${WITH_DOCS} as git_with_addons_true

ONBUILD WORKDIR /

ONBUILD RUN apt-get install -y \
            perl \
            liberror-perl

ONBUILD COPY --from=build_git /usr/share/git-gui /usr/share/git-gui
ONBUILD COPY --from=build_git /usr/share/gitweb /usr/share/gitweb
ONBUILD COPY --from=build_git /usr/share/perl /usr/share/perl
ONBUILD COPY --from=build_git /usr/share/perl5 /usr/share/perl5
ONBUILD COPY --from=build_git /usr/share/vim /usr/share/vim

FROM git_with_addons_${WITH_ADDONS} as final

ARG BASE_IMAGE="debian:stable-slim"

LABEL base-image="${BASE_IMAGE}"
LABEL git.version="${GIT_VERSION}"
LABEL git-lfs.version="${LFS_VERSION}"

RUN rm -rf /var/lib/apt/lists/*

COPY --from=build_lfs /git-lfs/bin/git-lfs /usr/bin/git-lfs

RUN git lfs install

CMD ["git"]
