# ------------------------------------------------------------------------------
# Build Stage
# ------------------------------------------------------------------------------

# Use bullseye as build image instead of Bookworm as ubi9 does not not have GLIBCXX_3.4.30
# https://access.redhat.com/solutions/6969351
FROM --platform=${BUILDPLATFORM} rust:1.72-bullseye as limitador-build

RUN apt update && apt upgrade -y \
    && apt install -y protobuf-compiler clang

WORKDIR /usr/src/limitador

ARG GITHUB_SHA
ENV GITHUB_SHA=${GITHUB_SHA:-unknown}
ENV RUSTFLAGS="-C target-feature=-crt-static"

COPY . .

RUN cargo build --release

# ------------------------------------------------------------------------------
# Run Stage
# ------------------------------------------------------------------------------

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.2

# shadow-utils is required for `useradd`
RUN PKGS="libgcc libstdc++ shadow-utils" \
    && microdnf --assumeyes install --nodocs $PKGS \
    && rpm --verify --nogroup --nouser $PKGS \
    && microdnf -y clean all
RUN useradd -u 1000 -s /bin/sh -m -d /home/limitador limitador

WORKDIR /home/limitador/bin/
ENV PATH="/home/limitador/bin:${PATH}"

COPY --from=limitador-build /usr/src/limitador/limitador-server/examples/limits.yaml ../
COPY --from=limitador-build /usr/src/limitador/target/release/limitador-server ./limitador-server

RUN chown -R limitador:root /home/limitador \
    && chmod -R 750 /home/limitador

USER limitador

CMD ["limitador-server"]
