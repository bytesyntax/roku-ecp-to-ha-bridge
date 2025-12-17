# syntax=docker/dockerfile:1
#
# Multi-arch capable Dockerfile for EcpEmuServer (Roku ECP emulator).
# Designed for Raspberry Pi (linux/arm64) and x64 (linux/amd64).
#
# Notes:
# - SSDP discovery uses UDP multicast and typically works best with host networking.
# - Port 8060/TCP is the Roku ECP HTTP endpoint.
# - Port 1900/UDP is used for SSDP.
#
# Build:
#   docker build -t ecpemuserver:local .
#
# Run (recommended):
#   docker run --rm --network host -v ./rules.xml:/app/rules.xml ecpemuserver:local

ARG DOTNET_VERSION=9.0

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build
WORKDIR /src

# Copy only the server project first for better layer caching
COPY ./src/EcpEmuServer/EcpEmuServer.csproj ./src/EcpEmuServer/
RUN dotnet restore ./src/EcpEmuServer/EcpEmuServer.csproj

# Copy the rest
COPY . .
RUN dotnet publish ./src/EcpEmuServer/EcpEmuServer.csproj \
  -c Release \
  -o /out \
  --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS runtime
WORKDIR /app

# Create a non-root user
RUN useradd -u 10001 -m appuser \
  && chown -R appuser:appuser /app

COPY --from=build /out/ ./

# The app reads ./rules.xml and ./devicename relative to working dir (/app)
# Allow overriding via bind mounts.
VOLUME ["/app"]

# Documentation-only (host networking recommended, so these are not strictly required)
EXPOSE 8060/tcp
EXPOSE 1900/udp

# Optionally provide a preferred local IPv4 address as first argument
# (mirrors EcpEmuServer behavior in Program.cs).
USER appuser
ENTRYPOINT ["dotnet", "EcpEmuServer.dll"]