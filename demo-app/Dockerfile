FROM golang:1.22.6 AS builder

WORKDIR /
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN CGO_ENABLED=0 go build -v -o /demo-app

# https://github.com/GoogleContainerTools/distroless/issues/1360#issuecomment-1646667145
FROM alpine:3.21.0
WORKDIR /
COPY --from=builder /demo-app .

RUN apk add --no-cache ca-certificates curl && update-ca-certificates bash

ENTRYPOINT ["/demo-app"]
