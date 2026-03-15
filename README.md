# tapotun

`tapotun` is a small D project for creating a TUN interface and transporting IP traffic between nodes over HTTP(S).

The project is currently focused on **Linux + TUN**: it creates an interface, keeps two long-lived sessions between client and server, and moves raw IP packets through a regular web transport.

## Features

- creates a `TUN` interface and assigns IP/MTU
- runs in both **server** and **client** mode from the same binary
- transports traffic over long-lived `GET`/`PUT` streams
- uses `x-api-key` for client authorization
- sends interface parameters from server to client
- supports extra routes for clients
- supports Linux policy routing through `fwmark`
- supports binding traffic to a client by `source IP`
- periodically checks for binary updates

## How it works

The server creates a `TUN` interface, exposes an HTTP endpoint, and matches clients by token.

The client:

- opens a `GET` request to receive packets from the server
- opens a `PUT` request to send packets to the server
- receives interface parameters from the server: IP, prefix, MTU
- then creates and configures the local `TUN`

In practice, the transport is usually exposed through a public **HTTPS URL**.

The built-in server is expected to run **behind a reverse proxy**. TLS termination should be handled by Nginx, Caddy, HAProxy, or another reverse proxy in front of `tapotun`. Native TLS in the application itself is not a goal at the moment.

## Current status

- primary platform: **Linux**
- `TAP`/L2 mode: **not implemented yet**
- Windows: **planned**
- configuration format: JSON
- a single config file can contain multiple interface definitions

## Build

The project uses `dub`.

Typical build variants:

- debug build
- release build

You need a D toolchain and the project dependencies.

## Run

The binary needs permissions for network interfaces and routing.

Usually that means:

- running as `root`
- or using capabilities such as `CAP_NET_ADMIN`

Run format:

```bash
./tapotun config.json
```

## Configuration format

The root JSON value is an array of objects. Each object is a separate interface definition.

There are two modes:

- **server**: if `port` is present
- **client**: if `server` is present

### Common fields

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | TUN interface name |
| `mark.value` | uint | `fwmark` value for policy routing |
| `mark.table` | uint | routing table used for `fwmark` |

### Server fields

| Field | Type | Description |
| --- | --- | --- |
| `port` | number | local HTTP server port |
| `net` | string | server-side TUN address and prefix, for example `10.10.0.1/24` |
| `mtu` | number | interface MTU, default is `1500` |
| `ips` | string[] | additional IP addresses added to the interface |
| `routes` | string[] | extra server-side networks used in routing logic |
| `clients` | object[] | list of allowed clients |

### `server.clients[]` fields

| Field | Type | Description |
| --- | --- | --- |
| `token` | string | **SHA-1 hash** of the client token in lowercase hex |
| `ip` | string | IP address assigned to that client by the server |
| `routes` | string[] | networks that should be routed to that client |
| `sources` | string[] | source IPs that should be pinned to that client |

### Client fields

| Field | Type | Description |
| --- | --- | --- |
| `server` | string | server URL, usually `https://host/path` |
| `token` | string | raw client token |

> Important: the client stores the **raw token**, while the server stores its **SHA-1** in `clients[].token`.

## Example 1. Minimal server

```json
[
  {
    "name": "tun0",
    "port": 8080,
    "net": "10.10.0.1/24",
    "clients": [
      {
        "token": "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3",
        "ip": "10.10.0.2"
      }
    ]
  }
]
```

What happens here:

- `tun0` is created
- the server gets `10.10.0.1/24`
- the client with token `test` gets `10.10.0.2`
- the server listens on local port `8080`

## Example 2. Minimal client

```json
[
  {
    "name": "tun0",
    "server": "https://edge.example.com/ip",
    "token": "test"
  }
]
```

What happens here:

- the client connects to `https://edge.example.com/ip`
- it sends token `test` in the `x-api-key` header
- after authorization it receives IP/prefix/MTU from the server
- then it creates and configures local `tun0`

## Example 3. Server with multiple clients and routes

```json
[
  {
    "name": "corp0",
    "port": 8080,
    "net": "10.50.0.1/24",
    "mtu": 1400,
    "ips": [
      "10.50.0.254"
    ],
    "mark": {
      "value": 100,
      "table": 100
    },
    "routes": [
      "172.20.0.0/16"
    ],
    "clients": [
      {
        "token": "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3",
        "ip": "10.50.0.2",
        "routes": [
          "10.60.0.0/24",
          "10.61.0.0/24"
        ],
        "sources": [
          "192.168.100.10"
        ]
      },
      {
        "token": "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33",
        "ip": "10.50.0.3",
        "routes": [
          "10.70.0.0/24"
        ]
      }
    ]
  }
]
```

What the extra fields mean:

- `mtu`: sets the TUN MTU
- `ips`: adds extra addresses to the interface
- `mark`: creates `ip rule`/`ip route` entries for Linux policy routing
- `clients[].routes`: packets to these networks are forwarded to the matching client
- `clients[].sources`: pins traffic by source IP to a specific client
- top-level `routes`: additional networks treated as local by the server routing logic

## Example 4. Client with policy routing

```json
[
  {
    "name": "corp0",
    "server": "https://edge.example.com/ip",
    "token": "test",
    "mark": {
      "value": 100,
      "table": 100
    }
  }
]
```

This is useful if you want only traffic already marked with `fwmark=100` to be routed through this path.

## Choosing a config layout

### If you need one client

- set `net`, `port`, and one client on the server
- set `name`, `server`, and `token` on the client
- manage the rest of routing with OS tools

### If you need a hub-and-spoke setup

- one server config
- multiple entries in `clients`
- each client gets its own IP
- networks in `clients[].routes` define where the server should forward packets

### If you need client selection by source IP

Use `clients[].sources`.

This is useful when one server handles several upstream clients and the path is chosen by source address.

## Reverse proxy deployment

`tapotun` should normally be deployed behind a reverse proxy.

Recommended layout:

- client connects to `https://edge.example.com/ip`
- reverse proxy terminates TLS
- reverse proxy forwards requests to local plain HTTP `tapotun`
- `tapotun` handles streaming packet transport and client authorization

This keeps certificate management and public HTTPS exposure outside of the application, which is the intended deployment model.

## Why use it instead of alternatives

`tapotun` is aimed at simple high-throughput IP transport, especially on low-power Linux devices such as routers.

Main advantages:

- support for Linux TUN offload features, including `TSO`
- lower per-packet overhead in the intended deployment model
- simple streaming transport over HTTP(S)
- easy deployment behind an existing reverse proxy
- flexible routing logic for multiple clients, routes, and source-based selection

On small devices, offload support matters. `tapotun` enables TUN features such as `VNET_HDR` and `TSO`, which can reduce CPU overhead and improve throughput compared to more traditional per-packet processing paths.

In the target scenarios for this project, it can work faster than WireGuard or similar solutions, especially when running on weak routers where CPU budget is limited.

Formal benchmarks are not published yet and will be added later, so for now this should be treated as a practical project goal and an observed result in early usage rather than a final benchmark claim.

## Current limitations

- currently `TUN` only, which means L3/IP
- no `TAP`/L2 yet
- networking logic is mainly Linux-oriented
- the built-in server is minimal and intended to sit behind a reverse proxy
- IPv4 is the primary target right now, IPv6 is not the main focus yet

## Ideas and roadmap

The most natural next steps are:

- `TAP` mode for L2 scenarios
- **Windows** platform support
- server-side balancing across different clients
- config validation and more user-friendly error messages
- config hot reload without restarting the process
- health checks and metrics
- systemd unit, Docker/OCI packaging
- clearer reverse proxy deployment examples
- IPv6
- ACLs and routing by client groups
- connection status and a simple admin panel

## Good use cases

- site-to-site for small installations
- point-to-point IP links between Linux hosts
- carrying IP routes over regular web transport
- environments where HTTP(S) is easier to expose than a dedicated network transport protocol

## What would improve the project most

If I were extending it further, I would start with:

1. `TAP` for L2 bridge scenarios
2. Windows backend through Wintun/TAP driver support
3. server-side balancing between multiple clients
4. a clearer CLI such as `server`, `client`, `validate-config`
5. ready-to-use deployment examples for bare metal, systemd, Docker, and reverse proxy setups

## License

This project is free for **non-commercial use**.

For this README, non-commercial use means personal use, home labs, learning, research, testing, internal evaluation, and any other use that does **not** generate profit.

Commercial use means any use that directly or indirectly generates profit.

If you want to use `tapotun` commercially, please contact: contact@temtaime.cc

## Support development

If this project is useful to you, you can support its development with a donation.

Support helps with:

- development time
- testing on more environments
- new features such as `TAP`, Windows support, and server-side balancing
- documentation and deployment examples

Donation options:

- Boosty: <https://boosty.to/temtaime>
- CloudTips: <https://pay.cloudtips.ru/p/27fa67d9>
- Ko-fi: <https://ko-fi.com/temtaime>
- GitHub Sponsors: <https://github.com/sponsors/Temtaime>
- Patreon: <https://www.patreon.com/temtaime>

Crypto:

- BTC: `bc1qze6mx5fcjepj9e7xcd5gm38jnsxw94frm7a5tg`
- ETH / USDT / USDC (ERC-20): `0xb823742e88215834AB61d208e5A5374CE202f81f`
- TON: `UQBIAH1wLo7sqKUHav37lYaTQ6nBwma8dh-zgu2gvrFUVvZ7`

---

For a production-friendly start, the simplest setup is still:

- one server
- one client
- one `https://` endpoint in front of a reverse proxy
- a minimal route set
- no `sources` and no `fwmark` until the basic setup is working reliably
