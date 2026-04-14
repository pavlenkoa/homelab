# Monitor Light + Cube Controller — Design

Ambient LED strip behind the desk monitor, controlled by:
- **Power gate:** workstation `tiny` (192.168.88.5) session state — reported to HA by a small agent daemon on the PC. Strip is OFF whenever the agent says the session is inactive (logged out, shut down, suspended, or screen locked).
- **Color/brightness:** Aqara Cube T1 Pro, repurposed as a dedicated remote for this one light.

The strip is owned exclusively by this pair (agent + cube). It is NOT a member of any z2m group and is not touched by knob, schedule, arrival, or presence automations.

## Ownership change

Remove `Living Room Monitor Light` from:
- `Living Room Lights` (group id 4)
- `All Lights` (group id 1)

After removal, the living-room knob and all living-room scene automations affect only the lamp and the kitchen table light.

## PC agent (tiny)

### What it does

A small Python daemon listening on dbus for session events and POSTing state changes to an HA webhook. Uses systemd-logind (system bus) for suspend/wake and KDE's `org.freedesktop.ScreenSaver` (session bus) for lock/unlock — logind's own Lock/Unlock signals do not fire under KDE Plasma, since the Plasma screen locker only emits on the session-bus ScreenSaver interface.

**State transitions → payload:**

| PC event | Source | POST payload |
|----------|--------|--------------|
| Agent started (login, session becomes active) | (startup) | `{"state": "on"}` |
| Screen locked | `org.freedesktop.ScreenSaver.ActiveChanged(true)` (session bus) | `{"state": "off"}` |
| Screen unlocked | `org.freedesktop.ScreenSaver.ActiveChanged(false)` (session bus) | `{"state": "on"}` |
| Entering suspend | logind `PrepareForSleep(true)` (system bus) | `{"state": "off"}` |
| Resumed from suspend | logind `PrepareForSleep(false)` (system bus) | `{"state": "on"}` |
| Agent stopped (logout / shutdown / SIGTERM) | (signal handler) | `{"state": "off"}` |

### Files

- `~/.local/bin/monitor-light-agent` — Python daemon (~60 lines, stdlib + `dbus-next` or `sdbus`)
- `~/.config/systemd/user/monitor-light.service` — user unit, `WantedBy=graphical-session.target`
- `~/.config/secrets/monitor-light-webhook` — shell file exporting `MONITOR_LIGHT_WEBHOOK=https://ha.pavlenko.io/api/webhook/<random-id>`

### Systemd unit sketch

```ini
[Unit]
Description=Monitor Light agent — reports session state to Home Assistant
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
EnvironmentFile=%h/.config/secrets/monitor-light-webhook
ExecStart=%h/.local/bin/monitor-light-agent
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
```

The agent must POST `off` on SIGTERM before exiting (so logout/shutdown fires the off event). On crash, systemd restarts it; on restart the agent POSTs `on`, so state re-syncs.

### Edge cases

- **Abrupt power loss (no graceful shutdown):** HA never sees `off`. Handled by the ping watchdog (see below) — `tiny_online` is forced off after the PC drops off the network.
- **Webhook unreachable (HA down, network down):** agent retries with backoff (3 attempts, 2s apart) and logs failure. State on HA side may drift until next event.
- **Agent crashes mid-session:** systemd restarts it; on restart, POSTs `on` — state re-syncs to correct value.

## Ping watchdog

A safety net on top of the agent. Catches cases the agent can't report (abrupt power loss, kernel panic, network cable yank).

```yaml
binary_sensor:
  - platform: ping
    host: 192.168.88.5
    name: tiny_pingable
    count: 3
    scan_interval: 30
```

### Automation: `monitor_light_ping_watchdog`

| Trigger | Action |
|---------|--------|
| `binary_sensor.tiny_pingable` → off for 2 min AND `input_boolean.tiny_online == on` | Turn `input_boolean.tiny_online` off; publish `{"state":"OFF","transition":0.5}` to the strip |

Watchdog only forces **off**, never on. Coming back online is the agent's job — when PC boots/wakes, the agent POSTs `on` and HA state flips. If agent is broken, the strip stays off until agent runs. This keeps the agent as the authoritative source for "on" events.

The 2-minute debounce allows for brief network blips (wifi roaming, momentary disconnects) without false-off. Acceptable lag — strip stays on for up to 2 min after sudden PC death. Trade-off chosen over rapid false toggles.

## HA side

### Webhook trigger

Create webhook with ID like `monitor_light_state_<random>` — the ID is the secret, do not commit.

### New entities

- `input_boolean.tiny_online` — mirrors PC session state, flipped by the webhook
- `input_number.monitor_light_brightness` — 0–255, step 1, initial 200, tracks desired strip brightness

```yaml
input_boolean:
  tiny_online:
    name: "tiny session active"

input_number:
  monitor_light_brightness:
    min: 0
    max: 255
    step: 1
    initial: 200
```

### Automation: `monitor_light_power`

Triggered by the webhook:

| Payload | Action |
|---------|--------|
| `{"state": "on"}` | Set `input_boolean.tiny_online` on; publish `{"state":"ON","brightness":<helper>,"transition":0.5}` to `zigbee2mqtt/Living Room Monitor Light/set`. Bulb restores last color from firmware memory. |
| `{"state": "off"}` | Set `input_boolean.tiny_online` off; publish `{"state":"OFF","transition":0.5}` |

Webhook payload is a simple JSON object; the automation reads `{{ trigger.json.state }}` and branches via `choose`.

### Automation: `monitor_cube`

Cube works regardless of `input_boolean.tiny_online` — you can turn the strip on with the cube while the PC is off. PC transitions (login/lock/sleep/wake) still drive auto-on/off via the agent, but they don't gate cube input.

### Cube event shape

The Cube T1 Pro on this firmware publishes only these actions to `zigbee2mqtt/Cube`:
- `flip90` / `flip180` — face-change events, carrying `side` (new face, 1–6) and `action_from_side` (old face)
- `rotate_right` / `rotate_left` — with signed `action_angle` (rotate_left is negative; typical flick 70–150°)
- `shake`

No `side_N`, tap, throw, or slide. Automation triggers on `action` and reads the `side` attribute for face selection.

| Cube event | Published payload |
|------------|-------------------|
| `flip90`/`flip180`, `side == 1` | `{"color_temp": 345, "brightness": <helper>, "transition": 0.3, "state": "ON"}` |
| `flip90`/`flip180`, `side == 2` | `{"color": {"x": 0.69, "y": 0.31}, "brightness": <helper>, "transition": 0.3, "state": "ON"}` |
| `side == 3` | `{"color": {"x": 0.58, "y": 0.40}, ...}` |
| `side == 4` | `{"color": {"x": 0.17, "y": 0.70}, ...}` |
| `side == 5` | `{"color": {"x": 0.14, "y": 0.08}, ...}` |
| `side == 6` | `{"color": {"x": 0.28, "y": 0.13}, ...}` |
| `rotate_right` | Brightness up: `step = round(abs(action_angle) * 3/13)` clamped to [1,64]. Update helper, publish `{"state":"ON","brightness": <helper>, "transition": 0.3}`. |
| `rotate_left` | Brightness down: same step, decrement helper. If helper ≤ 2, publish `{"state":"OFF","transition":0.5}` and keep helper at last above-threshold value. |
| `shake` | Manual OFF — `{"state":"OFF","transition":0.5}`. Strip stays off until next flip, rotate-up, or session off→on cycle. |

### Cube mode

Already set to action mode. The cube name in z2m is `Cube`.

## Configuration changes

All file edits under `kubernetes/apps/home-assistant/files/`:

1. **`configuration.yaml`:**
   - Add `input_boolean.tiny_online`
   - Add `input_number.monitor_light_brightness`
   - Add `binary_sensor.tiny_pingable` (ping watchdog)
2. **`automations.yaml`:**
   - Add `monitor_light_power` (webhook-triggered)
   - Add `monitor_light_ping_watchdog` (ping-sensor-triggered)
   - Add `monitor_cube` (MQTT-triggered on `zigbee2mqtt/Cube`)

Live MQTT changes (no file edits):

1. Rename cube → `Cube`
2. Remove `Living Room Monitor Light` from groups 1 and 4

PC-side files (outside the homelab repo, but the agent script + unit should be committed to a dotfiles repo or documented inline):

1. `~/.local/bin/monitor-light-agent` — Python daemon
2. `~/.config/systemd/user/monitor-light.service` — user unit
3. `~/.config/secrets/monitor-light-webhook` — webhook URL (not committed)

## Out of scope (deliberate YAGNI)

- **Heartbeat watchdog.** If the agent dies without firing off (abrupt power loss), state drifts. Accepting the edge case.
- **Manual override to turn strip on while PC is off.** User explicitly rejected.
- **Sync-to-screen-content** (Hue Sync style). Separate project.
- **Tap / flip / throw gestures.** Only sides + rotate + shake are bound.
- **Per-color brightness memory.** One helper shared across all colors.

## Known risks / verification required during implementation

- **Aqara LED Strip T1 color memory:** design assumes the strip remembers its last color through OFF/ON (only state toggles, no color republished on power-gate events). If it doesn't, the power-gate automation will need to re-publish color. Verify with: cube → side_2 (red) → PC suspend → PC wake → expect strip back to red. If it comes up wrong, add color storage to `input_text.monitor_light_color` and republish on power-on.
- **KDE Plasma lock/unlock detection:** resolved by listening on the session bus `org.freedesktop.ScreenSaver.ActiveChanged` signal (emitted by `kwin_wayland`) instead of logind's Lock/Unlock (which Plasma does not emit).
- **Cube rotate angle magnitude:** verify `action_angle` values and tune the 3/13 scaling if rotation feels too fast or too slow.
