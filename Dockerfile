FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim AS ui-builder
WORKDIR /src
ENV NODE_OPTIONS=--max-old-space-size=4096

COPY package.json yarn.lock ./
COPY tsconfig.json ./
COPY frontend ./frontend

RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm yarnpkg python3 make g++ ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN yarnpkg --version && node --version
RUN yarnpkg install --frozen-lockfile --non-interactive --network-timeout 120000
RUN yarnpkg run build --env production


FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim AS app-builder
WORKDIR /src
ARG RID=auto
ARG TARGETARCH

COPY src ./src
RUN set -eux; \
    if [ "${RID}" = "auto" ]; then \
      case "${TARGETARCH}" in \
        amd64) EFFECTIVE_RID="linux-x64" ;; \
        arm64) EFFECTIVE_RID="linux-arm64" ;; \
        arm) EFFECTIVE_RID="linux-arm" ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
      esac; \
    else \
      EFFECTIVE_RID="${RID}"; \
    fi; \
    echo "Using RID=${EFFECTIVE_RID} (TARGETARCH=${TARGETARCH})"; \
    dotnet publish "src/NzbDrone.Console/Prowlarr.Console.csproj" \
      -c Release \
      -r "${EFFECTIVE_RID}" \
      --self-contained false \
      -p:EnableAnalyzers=false \
      -p:TreatWarningsAsErrors=false \
      -o /app/publish \
      --verbosity normal


FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim AS runtime
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY --from=app-builder /app/publish/ ./
COPY --from=ui-builder /src/_output/UI ./UI

ENV ASPNETCORE_URLS=http://+:9696
EXPOSE 9696

VOLUME ["/config"]

ENTRYPOINT ["./Prowlarr"]
CMD ["-nobrowser", "-data=/config"]
