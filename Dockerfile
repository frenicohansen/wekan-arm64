FROM amd64/alpine:3.7 AS builder

# Set the environment variables for builder
ENV QEMU_VERSION=v4.2.0-6 \
    QEMU_ARCHITECTURE=aarch64 \
    NODE_ARCHITECTURE=linux-arm64 \
    NODE_VERSION=v14.20.1 \
    WEKAN_VERSION=latest  \
    WEKAN_ARCHITECTURE=arm64 \
    NODE_OPTIONS="--max_old_space_size=4096"

#---------------------------------------------------------------------
# https://github.com/wekan/wekan/issues/3585#issuecomment-1021522132
# Add more Node heap:
#   NODE_OPTIONS="--max_old_space_size=4096"
# Add more stack:
#   bash -c "ulimit -s 65500; exec node --stack-size=65500 main.js"
#---------------------------------------------------------------------

    # Install dependencies
RUN apk update && apk add ca-certificates outils-sha1 && \
    \
    # Download qemu static for our architecture
    wget https://github.com/multiarch/qemu-user-static/releases/download/v4.2.0-6/qemu-aarch64-static.tar.gz -O - | tar -xz && \
    \
    # Download wekan and shasum
    wget https://github.com/frenicohansen/wekan/releases/download/v6.53.2/wekan-6.53.2-arm64.zip -O wekan-latest-arm64.zip && \
#    wget https://releases.wekan.team/raspi3/SHA256SUMS.txt && \
    # Verify wekan
#    grep wekan-latest-arm64.zip SHA256SUMS.txt | sha256sum -c - && \
    \
    # Unzip wekan
    unzip -q wekan-latest-arm64.zip && \
    \
    # Download node and shasums
    wget https://nodejs.org/dist/v14.20.1/node-v14.20.1-linux-arm64.tar.gz && \
#    wget https://nodejs.org/dist/v14.20.1/SHASUMS256.txt.asc && \
    \
    # Verify nodejs authenticity
#    grep node-v14.20.1-linux-arm64.tar.gz SHASUMS256.txt.asc | sha256sum -c - && \
    \
    # Extract node and remove tar.gz
    tar xvzf node-v14.20.1-linux-arm64.tar.gz

# Build wekan dockerfile
FROM arm64v8/ubuntu:22.04
LABEL maintainer="wekan"

# Set the environment variables (defaults where required)
ENV QEMU_ARCHITECTURE=aarch64 \
    NODE_ARCHITECTURE=linux-arm64 \
    NODE_VERSION=v14.20.1 \
    NODE_ENV=production \
    NPM_VERSION=latest \
    WITH_API=true \
    PORT=8080 \
    ROOT_URL=http://localhost \
    MONGO_URL=mongodb://127.0.0.1:27017/wekan

# Copy qemu-static to image
COPY --from=builder qemu-aarch64-static /usr/bin

# Copy the app to the image
COPY --from=builder bundle /home/wekan/bundle

# Copy
COPY --from=builder node-v14.20.1-linux-arm64 /opt/nodejs

RUN \
    apt update && apt upgrade -y && \
    set -o xtrace && \
    # Add non-root user wekan
    useradd --user-group --system --home-dir /home/wekan wekan && \
    \
    # Install Node
    ln -s /opt/nodejs/bin/node /usr/bin/node && \
    ln -s /opt/nodejs/bin/npm /usr/bin/npm && \
    mkdir -p /opt/nodejs/lib/node_modules/fibers/.node-gyp /root/.node-gyp/8.16.1 /home/wekan/.config && \
    chown wekan --recursive /home/wekan/.config && \
    mkdir -p /data && \
    chown wekan --recursive /data && \
    \
    # Install Node dependencies
    npm install -g npm@latest

EXPOSE 8080
USER wekan

#---------------------------------------------------------------------
# https://github.com/wekan/wekan/issues/3585#issuecomment-1021522132
# Add more Node heap:
#   NODE_OPTIONS="--max_old_space_size=4096"
# Add more stack:
#   bash -c "ulimit -s 65500; exec node --stack-size=65500 main.js"
#---------------------------------------------------------------------
#
#CMD ["node", "/home/wekan/bundle/main.js"]

CMD ["bash", "-c", "ulimit -s 65500; exec node --stack-size=65500 /home/wekan/bundle/main.js"]

