# Monitor Light + Cube — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Aqara LED Strip T1 ("Living Room Monitor Light") as a bias light controlled by a PC agent on workstation `tiny` for power and an Aqara Cube T1 Pro ("Monitor Cube") for color/brightness.

**Architecture:** Strip is removed from living-room groups and owned exclusively by this pair. PC agent on `tiny` reports session state (login / lock / sleep / wake / logout) to an HA webhook → toggles `input_boolean.tiny_online` and publishes ON/OFF to the strip. Cube publishes gestures on its z2m MQTT topic → HA automation publishes color/brightness to the strip, gated on `tiny_online`. Ping sensor acts as a fail-safe that can only force OFF when the PC drops off the network for 2 minutes.

**Tech Stack:** Home Assistant (YAML config + automations), zigbee2mqtt, MQTT, systemd user unit on Linux, Python 3 with `dbus-next` for logind signals.

**Spec:** [`monitor-light-cube.md`](./monitor-light-cube.md)

---

## Task 1: Verify Cube in action mode

**Files:** none (MQTT verification only)

- [ ] **Step 1: Subscribe to the cube's MQTT topic**

Run in one terminal:
```bash
kubectl -n smarthome exec mosquitto-554d47466-cldqq -- \
  mosquitto_sub -h localhost -t 'zigbee2mqtt/0x54ef4410014f4d8f' -v
```

(If the mosquitto pod name has changed, use `kubectl -n smarthome get pods -l app.kubernetes.io/name=mosquitto -o name | head -1`.)

- [ ] **Step 2: Rotate and flip the cube through all 6 sides, rotate it, shake it**

Expected output: messages with `"action":"side_1"` ... `"side_6"`, `"action":"rotate_right"`, `"rotate_left"`, `"shake"`, and numeric `action_angle` on rotate events.

- [ ] **Step 3: If no `action` field appears**

Cube is in scene mode. Press the link button (under the rubber flap) 5× quickly. Repeat Step 2 to confirm action mode is active.

- [ ] **Step 4: Record the observed `action_angle` range**

Note the typical absolute value on one flick of the cube (expected ~45–120°). Used to tune the rotate step in Task 8.

## Task 2: Rename cube in z2m

**Files:** none (z2m live config)

- [ ] **Step 1: Publish rename request**

```bash
kubectl -n smarthome exec mosquitto-554d47466-cldqq -- mosquitto_pub \
  -h localhost -t 'zigbee2mqtt/bridge/request/device/rename' \
  -m '{"from":"0x54ef4410014f4d8f","to":"Monitor Cube"}'
```

- [ ] **Step 2: Verify the rename stuck**

```bash
kubectl -n smarthome exec zigbee2mqtt-0 -- cat /app/data/devices.yaml | grep -A1 '0x54ef4410014f4d8f'
```

Expected: `friendly_name: Monitor Cube`.

- [ ] **Step 3: Confirm actions publish to the new topic**

```bash
kubectl -n smarthome exec mosquitto-554d47466-cldqq -- \
  mosquitto_sub -h localhost -t 'zigbee2mqtt/Monitor Cube' -v -C 3 -W 30
```

Tap any side; expect the new topic to emit the action.

## Task 3: Remove strip from Living Room and All Lights groups

**Files:** none (z2m live config)

- [ ] **Step 1: Remove from Living Room Lights**

```bash
kubectl -n smarthome exec mosquitto-554d47466-cldqq -- mosquitto_pub \
  -h localhost -t 'zigbee2mqtt/bridge/request/group/members/remove' \
  -m '{"group":"Living Room Lights","device":"Living Room Monitor Light"}'
```

- [ ] **Step 2: Remove from All Lights**

```bash
kubectl -n smarthome exec mosquitto-554d47466-cldqq -- mosquitto_pub \
  -h localhost -t 'zigbee2mqtt/bridge/request/group/members/remove' \
  -m '{"group":"All Lights","device":"Living Room Monitor Light"}'
```

- [ ] **Step 3: Verify membership**

```bash
kubectl -n smarthome exec zigbee2mqtt-0 -- cat /app/data/database.db | python3 -c "
import json,sys
for line in sys.stdin:
    try: d=json.loads(line)
    except: continue
    if d.get('type')!='Group': continue
    members=[m['deviceIeeeAddr'] for m in d.get('members',[])]
    print(d.get('groupID'), members)"
```

Expected: group 1 and group 4 no longer contain `0x54ef441001450a6b`. Groups 2, 3, 5 unchanged.

- [ ] **Step 4: Sanity-check: recall a living room scene**

```bash
kubectl -n smarthome exec mosquitto-554d47466-cldqq -- mosquitto_pub \
  -h localhost -t 'zigbee2mqtt/Living Room Lights/set' -m '{"scene_recall":3}'
```

Expected: the lamp + kitchen table go to reading mode; the monitor strip does NOT change. Turn lights off afterward: `{"state":"OFF","transition":0.5}`.

## Task 4: Add HA config entities

**Files:**
- Modify: `kubernetes/apps/home-assistant/files/configuration.yaml`

- [ ] **Step 1: Read the current file to find the right locations**

Read the file to see existing `input_number:`, `input_boolean:`, `binary_sensor:` blocks so new entries merge cleanly.

- [ ] **Step 2: Add `input_boolean.tiny_online`**

Under the existing `input_boolean:` block (create the block if absent):

```yaml
input_boolean:
  tiny_online:
    name: tiny session active
```

- [ ] **Step 3: Add `input_number.monitor_light_brightness`**

Under `input_number:` alongside the existing `living_room_brightness` / `bedroom_brightness`:

```yaml
  monitor_light_brightness:
    name: Monitor Light brightness
    min: 0
    max: 255
    step: 1
    initial: 200
```

- [ ] **Step 4: Add `binary_sensor.tiny_pingable`**

Under `binary_sensor:` (create if absent):

```yaml
binary_sensor:
  - platform: ping
    host: 192.168.88.5
    name: tiny_pingable
    count: 3
    scan_interval: 30
```

- [ ] **Step 5: Copy to HA pod and restart**

```bash
kubectl -n smarthome cp kubernetes/apps/home-assistant/files/configuration.yaml \
  home-assistant-0:/config/configuration.yaml
source ~/.config/secrets/homeassistant
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" \
  https://ha.pavlenko.io/api/services/homeassistant/restart -o /dev/null -w "%{http_code}\n"
```

Expected HTTP 200. Wait ~30s for HA to come back.

- [ ] **Step 6: Verify entities exist**

```bash
source ~/.config/secrets/homeassistant
for e in input_boolean.tiny_online input_number.monitor_light_brightness binary_sensor.tiny_pingable; do
  echo -n "$e: "
  curl -s -H "Authorization: Bearer $HA_TOKEN" "https://ha.pavlenko.io/api/states/$e" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('state'))"
done
```

Expected: all three return a state (`off`/`200`/`on` or `off`).

## Task 5: Create the webhook + power automation

**Files:**
- Modify: `kubernetes/apps/home-assistant/files/automations.yaml`

- [ ] **Step 1: Generate a random webhook id**

```bash
python3 -c "import secrets; print('monitor_light_' + secrets.token_urlsafe(24))"
```

Record the value; it is a secret. Do NOT echo it in any shared channel. Save it to `~/.config/secrets/monitor-light-webhook` on the PC later (Task 10).

- [ ] **Step 2: Add `monitor_light_power` automation**

Append to `automations.yaml` (substitute the real webhook id for `<WEBHOOK_ID>`):

```yaml
- id: monitor_light_power
  alias: Monitor Light - Power (webhook)
  description: PC agent on tiny reports session state; strip follows.
  triggers:
  - trigger: webhook
    webhook_id: <WEBHOOK_ID>
    allowed_methods:
      - POST
    local_only: false
  actions:
  - choose:
    - conditions:
      - condition: template
        value_template: "{{ trigger.json.state == 'on' }}"
      sequence:
      - action: input_boolean.turn_on
        target:
          entity_id: input_boolean.tiny_online
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"state":"ON","brightness":{{ states('input_number.monitor_light_brightness') | int }},"transition":0.5}
    - conditions:
      - condition: template
        value_template: "{{ trigger.json.state == 'off' }}"
      sequence:
      - action: input_boolean.turn_off
        target:
          entity_id: input_boolean.tiny_online
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: '{"state":"OFF","transition":0.5}'
  mode: queued
  max: 10
```

- [ ] **Step 3: Deploy & reload automations**

```bash
kubectl -n smarthome cp kubernetes/apps/home-assistant/files/automations.yaml \
  home-assistant-0:/config/automations.yaml
source ~/.config/secrets/homeassistant
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" \
  https://ha.pavlenko.io/api/services/automation/reload -o /dev/null -w "%{http_code}\n"
```

Expected 200.

- [ ] **Step 4: Test the webhook manually**

```bash
WEBHOOK_ID='<paste-webhook-id>'
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"state":"on"}' "https://ha.pavlenko.io/api/webhook/$WEBHOOK_ID"
# expect strip to come on at brightness 200

sleep 3

curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"state":"off"}' "https://ha.pavlenko.io/api/webhook/$WEBHOOK_ID"
# expect strip to fade off
```

Verify `input_boolean.tiny_online` flipped in HA UI or via the curl-state pattern from Task 4 Step 6.

## Task 6: Add ping watchdog automation

**Files:**
- Modify: `kubernetes/apps/home-assistant/files/automations.yaml`

- [ ] **Step 1: Append automation**

```yaml
- id: monitor_light_ping_watchdog
  alias: Monitor Light - Ping watchdog
  description: Force strip off if tiny drops off the network for 2 minutes.
  triggers:
  - trigger: state
    entity_id: binary_sensor.tiny_pingable
    to: 'off'
    for: '00:02:00'
  conditions:
  - condition: state
    entity_id: input_boolean.tiny_online
    state: 'on'
  actions:
  - action: input_boolean.turn_off
    target:
      entity_id: input_boolean.tiny_online
  - action: mqtt.publish
    data:
      topic: zigbee2mqtt/Living Room Monitor Light/set
      payload: '{"state":"OFF","transition":0.5}'
  mode: single
```

- [ ] **Step 2: Deploy & reload**

```bash
kubectl -n smarthome cp kubernetes/apps/home-assistant/files/automations.yaml \
  home-assistant-0:/config/automations.yaml
source ~/.config/secrets/homeassistant
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" \
  https://ha.pavlenko.io/api/services/automation/reload -o /dev/null -w "%{http_code}\n"
```

- [ ] **Step 3: Manual verification (deferred)**

Full end-to-end verification requires pulling the PC's network cable for >2 min. Defer until Task 11 (integration test).

## Task 7: Add `monitor_cube` automation — sides

**Files:**
- Modify: `kubernetes/apps/home-assistant/files/automations.yaml`

- [ ] **Step 1: Append the automation shell**

```yaml
- id: monitor_cube
  alias: Monitor Cube - controller
  description: Cube gestures control Monitor Light color and brightness. Gated on tiny_online.
  triggers:
  - trigger: mqtt
    topic: zigbee2mqtt/Monitor Cube
  variables:
    action: "{{ trigger.payload_json.action | default('') }}"
    angle: "{{ trigger.payload_json.action_angle | default(0) | float }}"
  conditions:
  - condition: state
    entity_id: input_boolean.tiny_online
    state: 'on'
  actions:
  - choose:
    - conditions: "{{ action == 'side_1' }}"
      sequence:
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"color_temp":345,"brightness":{{ states('input_number.monitor_light_brightness') | int }},"transition":0.3,"state":"ON"}
    - conditions: "{{ action == 'side_2' }}"
      sequence:
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"color":{"x":0.69,"y":0.31},"brightness":{{ states('input_number.monitor_light_brightness') | int }},"transition":0.3,"state":"ON"}
    - conditions: "{{ action == 'side_3' }}"
      sequence:
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"color":{"x":0.58,"y":0.40},"brightness":{{ states('input_number.monitor_light_brightness') | int }},"transition":0.3,"state":"ON"}
    - conditions: "{{ action == 'side_4' }}"
      sequence:
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"color":{"x":0.17,"y":0.70},"brightness":{{ states('input_number.monitor_light_brightness') | int }},"transition":0.3,"state":"ON"}
    - conditions: "{{ action == 'side_5' }}"
      sequence:
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"color":{"x":0.14,"y":0.08},"brightness":{{ states('input_number.monitor_light_brightness') | int }},"transition":0.3,"state":"ON"}
    - conditions: "{{ action == 'side_6' }}"
      sequence:
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"color":{"x":0.28,"y":0.13},"brightness":{{ states('input_number.monitor_light_brightness') | int }},"transition":0.3,"state":"ON"}
    - conditions: "{{ action == 'shake' }}"
      sequence:
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: '{"state":"OFF","transition":0.5}'
  mode: restart
```

Rotate handling is added in Task 8 (the choose block is extended, not rewritten).

- [ ] **Step 2: Deploy & reload**

```bash
kubectl -n smarthome cp kubernetes/apps/home-assistant/files/automations.yaml \
  home-assistant-0:/config/automations.yaml
source ~/.config/secrets/homeassistant
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" \
  https://ha.pavlenko.io/api/services/automation/reload -o /dev/null -w "%{http_code}\n"
```

- [ ] **Step 3: Verify sides**

With `input_boolean.tiny_online` forced on (via Task 5 Step 4 webhook), rotate the cube through sides 1–6. Observe the strip changing color each time. Shake to confirm OFF.

- [ ] **Step 4: Confirm gate**

Set `tiny_online` off:
```bash
WEBHOOK_ID='<paste-webhook-id>'
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"state":"off"}' "https://ha.pavlenko.io/api/webhook/$WEBHOOK_ID"
```

Now rotate the cube. Strip stays off. Expected: no color change.

## Task 8: Add rotate handling to `monitor_cube`

**Files:**
- Modify: `kubernetes/apps/home-assistant/files/automations.yaml`

- [ ] **Step 1: Insert rotate_right branch before the shake branch**

```yaml
    - conditions: "{{ action == 'rotate_right' }}"
      sequence:
      - variables:
          step: "{{ [ [ (angle | abs * 3 / 13) | round(0, 'ceiling') | int, 1 ] | max, 64 ] | min }}"
          cur: "{{ states('input_number.monitor_light_brightness') | int }}"
          nxt: "{{ [ cur + step, 254 ] | min }}"
      - action: input_number.set_value
        target:
          entity_id: input_number.monitor_light_brightness
        data:
          value: "{{ nxt }}"
      - action: mqtt.publish
        data:
          topic: zigbee2mqtt/Living Room Monitor Light/set
          payload: >-
            {"state":"ON","brightness":{{ nxt }},"transition":0.3}
    - conditions: "{{ action == 'rotate_left' }}"
      sequence:
      - variables:
          step: "{{ [ [ (angle | abs * 3 / 13) | round(0, 'ceiling') | int, 1 ] | max, 64 ] | min }}"
          cur: "{{ states('input_number.monitor_light_brightness') | int }}"
          nxt: "{{ [ cur - step, 0 ] | max }}"
      - choose:
        - conditions: "{{ nxt <= 2 }}"
          sequence:
          - action: mqtt.publish
            data:
              topic: zigbee2mqtt/Living Room Monitor Light/set
              payload: '{"state":"OFF","transition":0.5}'
        default:
        - action: input_number.set_value
          target:
            entity_id: input_number.monitor_light_brightness
          data:
            value: "{{ nxt }}"
        - action: mqtt.publish
          data:
            topic: zigbee2mqtt/Living Room Monitor Light/set
            payload: >-
              {"brightness":{{ nxt }},"transition":0.3}
```

Note: `rotate_left` past the threshold does NOT modify the helper (keeps last above-threshold value). Matches spec.

- [ ] **Step 2: Deploy & reload**

Same pattern as Task 7 Step 2.

- [ ] **Step 3: Verify**

Cube: side_1 (reading). Rotate right one flick → helper value goes up (check via `curl /api/states/input_number.monitor_light_brightness`), strip brightens. Rotate left many flicks → strip eventually fades off; helper retains its last above-2 value.

- [ ] **Step 4: Tune if needed**

If rotation feels too fast/slow, adjust `3 / 13` multiplier. Redeploy & reload.

## Task 9: Commit HA changes and docs

**Files:**
- Modify: `docs/smarthome/lights.md`
- (committed earlier) `docs/smarthome/monitor-light-cube.md`, `docs/smarthome/monitor-light-cube-plan.md`, `kubernetes/apps/home-assistant/files/configuration.yaml`, `kubernetes/apps/home-assistant/files/automations.yaml`

- [ ] **Step 1: Update `docs/smarthome/lights.md`**

- Remove `Living Room Monitor Light` from the `Living Room Lights` (group 4) and `All Lights` (group 1) rows in the Groups table.
- Leave the Devices-table row but update its Group column to `— (standalone, PC-gated)`.
- Under Automations, add a new subsection "Monitor Light + Cube" with a one-line pointer: "See [`monitor-light-cube.md`](./monitor-light-cube.md)."
- Under Known Issues, add a note that `Living Room Monitor Light` is NOT part of the living-room group and is controlled exclusively by the PC agent + Monitor Cube.

- [ ] **Step 2: Commit all HA-side changes**

```bash
cd /home/andrii/git/homelab
git add docs/smarthome/monitor-light-cube.md \
        docs/smarthome/monitor-light-cube-plan.md \
        docs/smarthome/lights.md \
        kubernetes/apps/home-assistant/files/configuration.yaml \
        kubernetes/apps/home-assistant/files/automations.yaml
git commit -m 'feat: monitor light + cube controller (HA side)'
git pull --rebase
git push
```

## Task 10: PC agent — write the daemon

**Files:**
- Create: `~/.local/bin/monitor-light-agent` (Python 3 script, executable)

Runs on workstation `tiny`. Not under the homelab repo — user's choice whether to commit to a dotfiles repo.

- [ ] **Step 1: Install dependency**

```bash
python3 -m pip install --user --break-system-packages dbus-next requests
```

- [ ] **Step 2: Write the script**

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/monitor-light-agent <<'PYEOF'
#!/usr/bin/env python3
"""Monitor Light agent — reports session state to Home Assistant webhook.

Listens to systemd-logind dbus signals and POSTs {"state":"on"|"off"} to
$MONITOR_LIGHT_WEBHOOK on relevant events. On startup POSTs "on"; on SIGTERM
POSTs "off" before exit.
"""
import asyncio
import logging
import os
import signal
import sys
import time
from urllib.parse import urlparse

import requests
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
)
log = logging.getLogger('monitor-light-agent')

WEBHOOK = os.environ.get('MONITOR_LIGHT_WEBHOOK')
if not WEBHOOK:
    log.error('MONITOR_LIGHT_WEBHOOK not set')
    sys.exit(2)


def post_state(state: str) -> None:
    """POST state with retry. Never raises."""
    for attempt in range(3):
        try:
            r = requests.post(WEBHOOK, json={'state': state}, timeout=5)
            if r.status_code < 300:
                log.info('POST %s ok (attempt %d)', state, attempt + 1)
                return
            log.warning('POST %s returned %d', state, r.status_code)
        except Exception as e:
            log.warning('POST %s failed (attempt %d): %s', state, attempt + 1, e)
        time.sleep(2)
    log.error('POST %s gave up after 3 attempts', state)


async def main() -> None:
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()

    # Manager proxy — PrepareForSleep signal and session lookup
    manager_intro = await bus.introspect(
        'org.freedesktop.login1', '/org/freedesktop/login1')
    manager = bus.get_proxy_object(
        'org.freedesktop.login1', '/org/freedesktop/login1', manager_intro)
    manager_iface = manager.get_interface('org.freedesktop.login1.Manager')

    # Current session path
    uid = os.getuid()
    sessions = await manager_iface.call_list_sessions()
    session_path = None
    for sid, s_uid, s_user, s_seat, s_path in sessions:
        if s_uid == uid:
            session_path = s_path
            break
    if session_path is None:
        log.error('no session found for uid %d', uid)
        sys.exit(3)
    log.info('using session %s', session_path)

    session_intro = await bus.introspect('org.freedesktop.login1', session_path)
    session = bus.get_proxy_object(
        'org.freedesktop.login1', session_path, session_intro)
    session_iface = session.get_interface('org.freedesktop.login1.Session')

    def on_prepare_for_sleep(entering: bool) -> None:
        log.info('PrepareForSleep entering=%s', entering)
        post_state('off' if entering else 'on')

    def on_lock() -> None:
        log.info('Lock')
        post_state('off')

    def on_unlock() -> None:
        log.info('Unlock')
        post_state('on')

    manager_iface.on_prepare_for_sleep(on_prepare_for_sleep)
    session_iface.on_lock(on_lock)
    session_iface.on_unlock(on_unlock)

    # Initial state — session is active when agent starts
    post_state('on')

    stop = asyncio.Event()

    def shutdown(*_):
        log.info('shutting down')
        # POST off synchronously before asyncio loop tears down
        post_state('off')
        stop.set()

    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, shutdown)

    await stop.wait()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
PYEOF
chmod +x ~/.local/bin/monitor-light-agent
```

- [ ] **Step 3: Smoke-test the script directly**

```bash
export MONITOR_LIGHT_WEBHOOK='https://ha.pavlenko.io/api/webhook/<paste-webhook-id>'
~/.local/bin/monitor-light-agent &
AGENT_PID=$!
# expect strip on, HA input_boolean.tiny_online on
sleep 3
# lock the session to exercise Lock signal (KDE: loginctl lock-session)
loginctl lock-session
sleep 2
# strip should be off
loginctl unlock-session
sleep 2
# strip should be on
kill -TERM $AGENT_PID
wait $AGENT_PID
# strip should be off
```

Verify each state transition either by watching the strip or via HA state (`input_boolean.tiny_online`).

## Task 11: PC agent — systemd user unit

**Files:**
- Create: `~/.config/systemd/user/monitor-light.service`
- Create: `~/.config/secrets/monitor-light-webhook`

- [ ] **Step 1: Write the webhook env file**

```bash
mkdir -p ~/.config/secrets
chmod 700 ~/.config/secrets
umask 077
cat > ~/.config/secrets/monitor-light-webhook <<EOF
MONITOR_LIGHT_WEBHOOK=https://ha.pavlenko.io/api/webhook/<paste-webhook-id>
EOF
chmod 600 ~/.config/secrets/monitor-light-webhook
```

- [ ] **Step 2: Write the unit file**

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/monitor-light.service <<'EOF'
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
KillSignal=SIGTERM
TimeoutStopSec=10

[Install]
WantedBy=graphical-session.target
EOF
```

- [ ] **Step 3: Enable + start**

```bash
systemctl --user daemon-reload
systemctl --user enable --now monitor-light.service
systemctl --user status monitor-light.service --no-pager
```

Expected: active (running). Strip should be on at helper brightness.

- [ ] **Step 4: Check logs**

```bash
journalctl --user -u monitor-light.service -n 30 --no-pager
```

Expected: `using session /org/freedesktop/login1/session/...` and `POST on ok`.

## Task 12: Integration tests

**Files:** none (behavioral verification)

- [ ] **Step 1: Normal color flow**

With agent running, rotate cube through 6 sides; verify strip follows. Rotate right/left to change brightness. Shake → OFF. Rotate right → back on.

- [ ] **Step 2: Lock / unlock**

```bash
loginctl lock-session
# expect strip OFF within ~1s
loginctl unlock-session
# expect strip ON within ~1s at helper brightness
```

- [ ] **Step 3: Suspend / wake**

```bash
systemctl suspend
# (physically wake the machine)
```

Verify: strip off during suspend, on within a second of wake.

- [ ] **Step 4: Cube is no-op while locked**

```bash
loginctl lock-session
# rotate cube — strip stays off
sleep 5
loginctl unlock-session
# strip comes back on
```

- [ ] **Step 5: Ping watchdog**

Disconnect tiny from the network (unplug wifi or `sudo ip link set <iface> down`) and leave for 3 minutes. Expect strip to turn off ~2 min after the disconnect. Reconnect; agent should POST `on` on its next event (or if still running, stays in current state — you may need to lock/unlock to resync). Restore network.

- [ ] **Step 6: Abrupt shutdown**

```bash
# Do a graceful shutdown first to confirm normal path:
systemctl poweroff
# Verify strip turns off as agent POSTs off on SIGTERM.
```

## Task 13: Final commit

**Files:** any doc tweaks discovered during integration tests.

- [ ] **Step 1: Update the spec with any tuning changes**

If the rotate scaling (`3 / 13`) was adjusted during Task 8 Step 4, update the matching value in `docs/smarthome/monitor-light-cube.md`.

- [ ] **Step 2: Commit remaining changes**

```bash
cd /home/andrii/git/homelab
git status
git add -u
git commit -m 'docs(smarthome): tune monitor light after integration test'
git pull --rebase
git push
```

---

## File map (what ends up changed)

| File | Purpose |
|------|---------|
| `kubernetes/apps/home-assistant/files/configuration.yaml` | Add `input_boolean.tiny_online`, `input_number.monitor_light_brightness`, `binary_sensor.tiny_pingable` |
| `kubernetes/apps/home-assistant/files/automations.yaml` | Add `monitor_light_power`, `monitor_light_ping_watchdog`, `monitor_cube` |
| `docs/smarthome/lights.md` | Strip moved out of groups; pointer to new design doc |
| `docs/smarthome/monitor-light-cube.md` | Design (already committed) |
| `docs/smarthome/monitor-light-cube-plan.md` | This plan |
| `~/.local/bin/monitor-light-agent` (tiny) | Python dbus daemon |
| `~/.config/systemd/user/monitor-light.service` (tiny) | User-scope systemd unit |
| `~/.config/secrets/monitor-light-webhook` (tiny) | Webhook URL (secret, not committed) |
| Live z2m state | Cube renamed; strip removed from groups |
