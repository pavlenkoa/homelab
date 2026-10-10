# HomeKit (Apple Home) for Home Assistant

Home Assistant's HomeKit Bridge needs two things from the network: mDNS discovery
(`_hap._tcp`) and a TCP route from the iPhone / Apple TV hub to the bridge port.
HA runs in the OrbStack VM, which sits behind NAT on a vmnet bridge, so neither works
out of the box. Three pieces fix it:

```
iPhone / Apple TV ──mDNS──► en0 ─┐
                                 │  mdns-reflector (native on Mac, launchd)
HA (hostNetwork, in VM) ◄─ bridge100 ─┘
iPhone ──TCP 21063──► 192.168.88.2 ──OrbStack port forward──► VM:21063 ──► HA
```

1. **HA runs with `hostNetwork: true`** (`kubernetes/apps/home-assistant/values/homelab.yaml`).
   Its zeroconf then advertises on the VM's `eth0` (the vmnet bridge), and the HomeKit
   port is a real `0.0.0.0` listener in the VM, which OrbStack forwards to the Mac's LAN IP
   (same mechanism as kgateway on 80/443, see `orbstack-networking.md`).
2. **`homekit.advertise_ip: 192.168.88.2`** makes HA advertise the Mac's LAN IP instead of
   the VM's unroutable `192.168.139.x`.
3. **`host/macmini/mdns-reflector`** copies mDNS between `bridge100` (VM side) and `en0`
   (LAN) in both directions. macOS's mDNSResponder does not do this itself.

Side effect of hostNetwork: HA's port 8123 is also forwarded to `192.168.88.2:8123` on
the LAN (HA's own login still applies; the gateway route is unchanged).

## Install the reflector (Mac Mini, outside GitOps)

```bash
mkdir -p ~/.local/bin
cp host/macmini/mdns-reflector/mdns-reflector.py ~/.local/bin/
cp host/macmini/mdns-reflector/io.homelab.mdns-reflector.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.homelab.mdns-reflector.plist
tail -f /opt/homebrew/var/log/mdns-reflector.log
```

The plist hardcodes the interface IPs (`en0` 192.168.88.2, `bridge100` 192.168.139.3) and
subnets. Update it if either changes. macOS may ask for Local Network permission for
`python3` on first start.

## Verify

```bash
dns-sd -B _hap._tcp local.        # on the Mac: should list "Home Assistant ..." on en0
```

From another LAN host the bridge should resolve to `192.168.88.2:21063`. Then in the
Home app: Add Accessory -> More options -> pick the bridge, enter the code from
HA (Settings -> Notifications, "HomeKit Pairing").

## Notes

- Exposed entities are limited by `homekit.filter` in the HA config (currently
  `include_domains: [light]`). Changing the filter or entity set needs an HA restart.
- An Apple TV / HomePod home hub is needed for remote access and Apple-side automations.
- If a killed bridge leaves a stale `_hap._tcp` name cached on the network, HA may rename
  itself ("... #2"); it clears after the record TTL.
- Rollback: unload the launchd job, set `hostNetwork: false` and remove the `homekit:` block.
