FROM ghcr.io/gsmlg-dev/phoenix@sha256:512564056d421e49343b84fc07fe0afe44eee760398ed94fb6c536d4682d191c

# Audited available toolchain: Alpine 3.23.3, Elixir 1.19.5, OTP 28.
# The base is tooling only; Mix starts only this project's locked applications.
ENV ELIXIR_ERL_OPTIONS="+S 2:2"
RUN apk add --no-cache python3 openssl expect
WORKDIR /work
COPY mix.exs mix.lock .formatter.exs ./
COPY config config
COPY apps apps
COPY examples examples
COPY integration integration
COPY scripts scripts
RUN unbuffer mix local.hex --force && unbuffer mix local.rebar --force \
    && unbuffer mix deps.get --check-locked && unbuffer mix compile --warnings-as-errors
RUN apk add --no-cache iproute2 util-linux
ENTRYPOINT []
CMD ["python3", "integration/network/fixture.py"]
