# syntax=docker/dockerfile:1

FROM golang:1.26 AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/backend .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/backend /backend
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/backend"]
