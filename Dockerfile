FROM golang:1.24.2-alpine AS go-builder

RUN apk add --no-cache protobuf-dev git

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

FROM oven/bun:1-alpine

RUN apk add --no-cache git curl protobuf protobuf-dev
COPY --from=go-builder /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

COPY --from=go-builder /usr/bin/protoc /usr/bin/protoc
COPY --from=go-builder /go/bin/protoc-gen-go /usr/local/bin/
COPY --from=go-builder /go/bin/protoc-gen-go-grpc /usr/local/bin/

RUN bun install -g @protobuf-ts/plugin@latest

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
COPY Dockerfile /Dockerfile
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]