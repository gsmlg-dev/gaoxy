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
COPY source-identity.json /tools/source-identity.json
RUN tar -xf /tools/source.tar -C /work
COPY build.py /tools/build.py
COPY ordinary-scope.json /tools/ordinary-scope.json
RUN python3 /tools/build.py prepare
RUN python3 /tools/build.py compile
COPY --from=diagnostic instrument.exs run.py /diagnostic/
RUN python3 /diagnostic/run.py


FROM builder AS repaired
COPY --from=repair / /repair/
RUN python3 /repair/run.py

FROM scratch AS repair-evidence
COPY --from=repaired /repair-evidence/ /
