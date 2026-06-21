# ================================
# Build image
# ================================
FROM swift:6.2-noble AS build

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev

# Set up a build area
WORKDIR /build

# Copy package manifests for all local packages to cache dependency resolution separately.
# Build context is the repo root so catscan-shared is reachable.
COPY ./catscan-server/Package.* ./catscan-server/
COPY ./catscan-server/Packages ./catscan-server/Packages
COPY ./catscan-shared/Package.swift ./catscan-shared/Package.swift
COPY ./catscan-shared/Sources ./catscan-shared/Sources

RUN cd catscan-server && swift package resolve \
        $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy full server source
COPY ./catscan-server ./catscan-server

RUN mkdir /staging

# Build the application, with optimizations, with static linking, and using jemalloc
# N.B.: The static version of jemalloc is incompatible with the static Swift runtime.
RUN --mount=type=cache,target=/build/catscan-server/.build \
    cd catscan-server && \
    swift build -c release \
        --product CatscanServer \
        --static-swift-stdlib \
        -Xlinker -ljemalloc && \
    cp "$(swift build -c release --show-bin-path)/CatscanServer" /staging && \
    find -L "$(swift build -c release --show-bin-path)" -regex '.*\.resources$' -exec cp -Ra {} /staging \;


# Switch to the staging area
WORKDIR /staging

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/catscan-server/Public ] && { mv /build/catscan-server/Public ./Public && chmod -R a-w ./Public && chmod u+w ./Public/images; } || true
RUN [ -d /build/catscan-server/Resources ] && { mv /build/catscan-server/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      libjemalloc2 \
      ca-certificates \
      tzdata \
      ffmpeg \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./CatscanServer"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
