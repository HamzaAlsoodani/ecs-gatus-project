# Builder 
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o ga tus .



# Scratch container
FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /app/gatus /gatus

COPY --from=builder /app/config.yaml /config/config.yaml

ENV GATUS_CONFIG_PATH="/config/config.yaml"

EXPOSE 8080

USER 65532:65532

ENTRYPOINT ["/gatus"]
