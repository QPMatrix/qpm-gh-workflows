# syntax=docker/dockerfile:1
# Minimal fixture image for rust-gate.yml's self-test `image` job — proves
# a Dockerfile in a caller repo actually gets built, nothing more.
FROM rust:1.90.0-slim-bookworm
COPY . /src
