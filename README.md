<p align="center">
  <img src="res/icon.png" alt="SoCo Systems Sentry" width="112"><br><br>
  <b>Secure remote support by Southern Colorado Systems, LLC</b>
</p>

# SoCo Systems Sentry — Client

Sentry is the branded, self-hosted remote-support client used by **Southern
Colorado Systems, LLC (SoCo Systems)** to securely view and control client
computers during support sessions. It is a fork of
[RustDesk](https://github.com/rustdesk/rustdesk) (Flutter/Rust, AGPL-3.0),
re-pointed at SoCo Systems' own private relay and management infrastructure.

> [!IMPORTANT]
> **Authorized use only.** This software and the service it connects to are
> provided solely for Southern Colorado Systems and its authorized clients.
> Unauthorized use, access, or distribution is prohibited. This repository is
> published for source transparency and AGPL-3.0 license compliance — it is not
> a general-purpose product and SoCo Systems does not provide support for
> third-party deployments of it.

## What makes it different from upstream RustDesk

- **Self-hosted, key-locked relay.** Every build ships pointed at SoCo Systems'
  own rendezvous/relay server in key-enforced mode, with end-to-end encryption.
  No third-party servers are involved.
- **Blocked by default (zero-trust).** A fresh installation cannot connect or be
  connected to. Each device stays denied at the relay until a SoCo Systems
  administrator explicitly authorizes it in the management console — installing
  the software alone grants no access.
- **Integrated device management.** Online status, device inventory, and
  authorization are managed centrally through SoCo Systems' portal.
- **Self-hosted updates, code-signed builds.** Windows installers are
  Authenticode-signed by Southern Colorado Systems and update from our own
  release feed; the client verifies the signature before applying an update.
- **SoCo Systems branding** throughout (name, icons, theme, `sentry://` links,
  About page).

## Download

Authorized clients download Sentry from **[sentry.socosystems.net](https://sentry.socosystems.net)**.
Only install Sentry, or share your connection ID, at the request of a SoCo
Systems technician you contacted yourself.

## Building

Windows installers are produced by CI on a version tag (`1.4.9-N`), which drives
the build version and publishes signed `.exe`/`.msi` assets to the Releases page.
The client is built from the `soco-brand` branch and pulls its shared library
from the [`SoCoSys/hbb_common`](https://github.com/SoCoSys/hbb_common) submodule.
General RustDesk build prerequisites and structure are documented upstream.

## License & attribution

Sentry is a derivative work of **[RustDesk](https://github.com/rustdesk/rustdesk)**
and is distributed under the **GNU AGPL-3.0** license, the same license as the
upstream project. See [`LICENCE`](LICENCE). All RustDesk trademarks and
copyrights remain with their respective owners; "SoCo Systems Sentry" branding
belongs to Southern Colorado Systems, LLC.
