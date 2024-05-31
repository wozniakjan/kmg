FROM cgr.dev/chainguard/go:latest as builder
WORKDIR /go
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 go build -o main ./main.go

FROM cgr.dev/chainguard/static:latest
COPY --from=builder /go/main /main
ENTRYPOINT ["/main"]
