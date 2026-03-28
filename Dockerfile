FROM node:20-bookworm-slim AS ui-builder
WORKDIR /src

COPY package.json yarn.lock ./
COPY frontend ./frontend

RUN corepack enable \
    && yarn install --frozen-lockfile --network-timeout 120000 \
    && yarn build


FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim AS app-builder
WORKDIR /src

COPY src ./src
RUN dotnet restore "src/Prowlarr.sln"
RUN dotnet publish "src/NzbDrone.Console/Prowlarr.Console.csproj" \
    -c Release \
    -r linux-x64 \
    --self-contained false \
    -o /app/publish


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
