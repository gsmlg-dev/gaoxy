FROM rust@sha256:0e2bcaef56d041a486784e54104a81aebe0da44bd03019bd70bc0401e42e4a97 AS rust
FROM hexpm/elixir@sha256:abbfaf9699b7a3650810c92268023806217486c26b4da3dc0492a778b22a09bb AS builder
ENV CARGO_HOME=/usr/local/cargo RUSTUP_HOME=/usr/local/rustup
COPY --from=rust /usr/local/cargo /usr/local/cargo
COPY --from=rust /usr/local/rustup /usr/local/rustup
ENV PATH=/opt/elixir/bin:/usr/local/cargo/bin:$PATH ERL_FLAGS="+S 2:2" ELIXIR_ERL_OPTIONS="+S 2:2" CI=true
RUN apt-get update && apt-get install -y --no-install-recommends build-essential ca-certificates git curl openssl pkg-config python3 python3-venv file binutils && rm -rf /var/lib/apt/lists/*
RUN git init /opt/elixir && cd /opt/elixir && git remote add origin https://github.com/elixir-lang/elixir.git && git fetch --depth 1 origin dfe6612e546cec6557900e67651f7d21805472ef && git checkout --detach FETCH_HEAD && test "$(git rev-parse HEAD)" = dfe6612e546cec6557900e67651f7d21805472ef && make compile
WORKDIR /work
COPY source.tar /tools/source.tar
RUN tar -xf /tools/source.tar -C /work
COPY build.py /tools/build.py
RUN python3 /tools/build.py

FROM scratch AS artifact
COPY --from=builder /output/ /

FROM debian@sha256:a4672c0cb26fbdde88e38fa2dfb6c681942306680e41e4378b28770b6e79ee91 AS runtime
ENV ERL_FLAGS="+S 2:2" ELIXIR_ERL_OPTIONS="+S 2:2" PYTHONDONTWRITEBYTECODE=1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates openssl libssl3 libstdc++6 libncurses6 libtinfo6 zlib1g python3 file binutils && rm -rf /var/lib/apt/lists/*
WORKDIR /work
COPY --from=builder /work/scripts/release-smoke.py /work/scripts/gateway-release-smoke.py /work/scripts/generate-fixtures.sh /work/scripts/
COPY --from=builder /work/.audit/h2peer /work/.audit/h2peer
COPY runtime.py /tools/runtime.py
ENTRYPOINT ["python3", "/tools/runtime.py"]
