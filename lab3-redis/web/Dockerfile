FROM golang:1.23.4-alpine3.21 AS build
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -o /web .

FROM alpine:3.21.0
COPY --from=build /web /web
ENTRYPOINT ["/web"]
