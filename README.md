# Roku ECP → Home Assistant Bridge (Sofabaton-friendly)

This project runs an emulated Roku ECP (External Control Protocol) device on your LAN and maps remote-control button presses (Sofabaton / Harmony-style IP control) to **Home Assistant actions** via **Home Assistant webhooks**.

It is a modified version of https://github.com/logantgt/EcpEmuServer.

Primary use case: control things that *don’t* have a simple REST API (e.g. Zigbee devices), while still using a universal remote that can control “Roku” devices on the network.

## How it works

1. The service advertises itself via SSDP multicast as a Roku ECP device (UDP/1900), implemented in [`SSDPManager.StartSSDP()`](src/EcpEmuServer/SSDPManager.cs:9).
2. Your remote sends Roku ECP keypresses to the service (HTTP/8060), handled in [`Program.Main()`](src/EcpEmuServer/Program.cs:9) at `POST /keypress/{btn}`.
3. Each `btn` is matched to rules in `rules.xml` and triggers an HTTP `GET` / `POST` to the configured endpoint, implemented in [`RuleManager.Execute()`](src/EcpEmuServer/RuleManager.cs:60).
4. Those endpoints are Home Assistant **webhook URLs** that fire automations (open/close/stop awning, etc.).

Why webhooks: HA service calls normally require auth headers, but the current rules engine is intentionally simple and doesn’t set custom headers. Webhooks avoid that and are ideal for LAN-triggered automations.

## Requirements

- Home Assistant reachable on your LAN (example uses `http://127.0.0.1:8123` when running on the same host with Docker host networking).
- Docker + Docker Compose on your server (Raspberry Pi 5 / `linux/arm64` supported).
- Your remote can add/control a “Roku” IP device (Sofabaton X1 supports this via Roku device profiles).

## Home Assistant setup (webhook automations)

Create 3 automations in Home Assistant (open/close/stop). An example file is provided:

- [`example/ha-automations-awning-webhooks.yaml`](example/ha-automations-awning-webhooks.yaml:1)

In the example, the webhook IDs are:
- `awning_open`
- `awning_close`
- `awning_stop`

And the awning entity is:
- `cover.awning_controller`

Adjust those as needed.

Security recommendation: keep `local_only: true` on the webhook triggers unless you have a specific reason not to.

## Service configuration (`rules.xml`)

Map Roku buttons to HA webhook URLs.

An example rules file is provided:

- [`example/rules.awning.homeassistant.webhooks.xml`](example/rules.awning.homeassistant.webhooks.xml:1)

Example mapping:
- `Fwd` → open
- `Rev` → close
- `Play` → stop

If Home Assistant runs on the same machine and you run this container with host networking, you can use:

- `http://127.0.0.1:8123/api/webhook/<webhook_id>`

## Run with Docker Compose (recommended)

The included Compose file uses host networking for reliable SSDP multicast discovery:

- [`docker-compose.yml`](docker-compose.yml:1)

Typical steps on your server:
1. Copy [`example/rules.awning.homeassistant.webhooks.xml`](example/rules.awning.homeassistant.webhooks.xml:1) to `./rules.xml` and adjust webhook IDs/URLs as needed.
2. Create a `devicename` file (optional) to control what the remote sees in discovery:
   - The service reads `./devicename` relative to the container working directory.
3. Start:
   - `docker compose up -d`

Notes:
- Host networking is important because SSDP uses UDP multicast on port 1900.
- The ECP HTTP endpoint is port 8060.

## Sofabaton setup (high level)

1. Add a new device and choose a Roku device profile (or other Roku ECP compatible profile).
2. Ensure it discovers the server on your LAN (SSDP).
3. Map buttons/sequences to Roku keypresses (`Fwd`, `Rev`, `Play`, etc.).
4. Press buttons → HA webhook automation fires → Zigbee cover action executes.

## GitHub Actions: publish multi-arch image (no local build needed)

A workflow is included to build and publish a multi-arch Docker image to GHCR (amd64 + arm64):

- [`publish-ghcr.yml`](.github/workflows/publish-ghcr.yml:1)

Once your repo’s Actions run, you can reference the published image in Compose instead of building locally (edit [`docker-compose.yml`](docker-compose.yml:1) accordingly).

## Platform notes (Windows-only AutoHotKey)

This codebase includes an AutoHotKey action type intended for Windows. For Linux/ARM container builds, AutoHotKey is made Windows-only and a stub is used on non-Windows platforms:

- [`AutoHotKeyStub.cs`](src/EcpEmuServer/AutoHotKeyStub.cs:1)
- Package conditioning is in [`EcpEmuServer.csproj`](src/EcpEmuServer/EcpEmuServer.csproj:1)

## Files you’ll most likely edit

- Rules mapping: `rules.xml` (start from [`example/rules.awning.homeassistant.webhooks.xml`](example/rules.awning.homeassistant.webhooks.xml:1))
- Home Assistant automation YAML: start from [`example/ha-automations-awning-webhooks.yaml`](example/ha-automations-awning-webhooks.yaml:1)
- Container run config: [`docker-compose.yml`](docker-compose.yml:1)
