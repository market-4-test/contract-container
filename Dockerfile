FROM alpine:latest

RUN apk add --no-cache \
    bash \
    git \
    curl \
    go \
    protobuf-dev \
    grpc-plugins \
    nodejs \
    npm \
    python3 \
    py3-pip

RUN pip install --no-cache-dir --break-system-packages grpcio grpcio-tools


RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest


RUN npm install -g @protobuf-ts/plugin

ENV PATH="/root/go/bin:${PATH}"

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
COPY Dockerfile /Dockerfile
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]