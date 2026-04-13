# Smart Home Lighting System

## Architecture Overview

All lights are Philips Hue bulbs connected via Zigbee2MQTT (z2m.pavlenko.io).
Home Assistant (ha.pavlenko.io) handles automations. MQTT is the communication layer.

**Key design decisions:**
- All "turn on" actions use **Zigbee scenes stored on bulb firmware** (`scene_recall`) instead of `light.turn_on` with color parameters. This prevents the color flash problem (see Known Issues).
- Smart knobs are **removed from z2m groups** and operate in command mode. All knob actions (toggle, brightness, color) are intercepted by HA automations and published to group MQTT topics. This prevents the knob's stuck `state: ON` from poisoning group state and eliminates the race condition between direct Zigbee commands and HA scene recalls.

## Devices

### Lights (Philips Hue bulbs)

| Z2M Name | HA Entity | Room | Group |
|----------|-----------|------|-------|
| Living Room Lamp | light.living_room_lamp | Living room | Living Room Lights |
| Kitchen Table Light | light.kitchen_table_light | Living room (kitchen area) | Living Room Lights |
| Living Room Monitor Light | light.living_room_monitor_light | Living room | Living Room Lights |
| Bedroom Light 1 | light.bedroom_light_1 | Bedroom | Bedroom Lights |
| Bedroom Light 2 | light.bedroom_light_2 | Bedroom | Bedroom Lights |
| Bathroom Light 1 | light.bathroom_light_1 | Bathroom | Bathroom Lights |
| Bathroom Light 2 | light.bathroom_light_2 | Bathroom | Bathroom Lights |
| Hallway Light 1 | light.hallway_light_1 | Hallway | Hallway Lights |
| Hallway Light 2 | light.hallway_light_2 | Hallway | Hallway Lights |
| Hallway Light 3 | light.hallway_light_3 | Hallway | Hallway Lights |

### Z2M Groups

| Group Name | ID | Members | MQTT Topic |
|------------|-----|---------|------------|
| All Lights | 1 | Living Room Lamp, Kitchen Table Light, Living Room Monitor Light, Bedroom Light 1, Bedroom Light 2 | zigbee2mqtt/All Lights/set |
| Bedroom Lights | 2 | Bedroom Light 1, Bedroom Light 2 | zigbee2mqtt/Bedroom Lights/set |
| Bathroom Lights | 3 | Bathroom Light 1, Bathroom Light 2 | zigbee2mqtt/Bathroom Lights/set |
| Living Room Lights | 4 | Living Room Lamp, Kitchen Table Light, Living Room Monitor Light | zigbee2mqtt/Living Room Lights/set |
| Hallway Lights | 5 | Hallway Light 1, Hallway Light 2, Hallway Light 3 | zigbee2mqtt/Hallway Lights/set |

**Note:** All Lights excludes bathroom and hallway (both are fully sensor-controlled). Knobs are NOT members of any group — they are controlled through HA automations only.

**Important:** Use group topics for simultaneous control. Publishing to individual bulbs sequentially causes visible one-by-one turn-on.

### Presence Sensors (Aqara FP300)

| Name | HA Entity | Room | Placement |
|------|-----------|------|-----------|
| Bathroom Sensor | binary_sensor.bathroom_sensor_presence | Bathroom | Battery powered, mmWave + PIR |
| Bedroom Sensor | binary_sensor.bedroom_sensor_presence | Bedroom | Ceiling-mounted, center of room above the bed. Battery powered, mmWave + PIR |
| Hallway Sensor | binary_sensor.hallway_sensor_presence | Hallway | Battery powered, mmWave + PIR |

**Sensor settings:**
- Bathroom Sensor: motion_sensitivity=medium, ai_adaptive=on, absence_delay=10s
- Bedroom Sensor: motion_sensitivity=high, ai_adaptive=off (disabled to fix detection issues), absence_delay=10s, spatial_learning triggered 2026-04-01
- Hallway Sensor: motion_sensitivity=medium, ai_adaptive=on, absence_delay=10s

### Smart Knobs (Tuya ERS-10TZBVK-AA)

| Name | MQTT Topic | Room | Operation Mode |
|------|------------|------|----------------|
| Bedroom Knob | zigbee2mqtt/Bedroom Knob | Bedroom | command |
| Living Room Knob | zigbee2mqtt/Living Room Knob | Living room | command |

**Knob architecture:** Knobs are in **command mode** but **removed from z2m groups**. In command mode, z2m still reports all actions (toggle, brightness_step_up/down, hue_move) to MQTT. HA automations (`living_room_knob`, `bedroom_knob`) intercept these actions and publish commands to the appropriate group MQTT topic.

This design:
- **Eliminates the color flash** on toggle (scene_recall is the only command, no race with direct Zigbee toggle)
- **Fixes group state tracking** (knob's permanent `state: ON` no longer poisons the group entity)
- **Allows time-aware scene selection** (HA picks the correct scene for the time of day)
- **Trade-off:** Brightness rotation goes through HA→MQTT→z2m instead of direct Zigbee, adding some latency. The step size is scaled down (raw * 3/13) and uses absolute brightness with 0.3s transition. Brightness is tracked via `input_number` helpers to avoid spring-back from stale z2m state.

## Zigbee Scenes

Scenes are stored on each bulb's firmware, indexed by `(group_id, scene_id)`. The scene_recall command turns the light on AND sets color/brightness/transition atomically — no flash.

| Scene ID | Name | Color | Brightness | Transition | Use Case |
|----------|------|-------|------------|------------|----------|
| 1 | reading_presence | 2890K (color_temp: 345) | 254 | 1.5s | Presence sensor on |
| 2 | red_presence | xy 0.69/0.31 | 254 | 1.5s | Presence sensor on |
| 3 | reading_transition | 2890K (color_temp: 345) | 254 | 30s | Time-based transition (sunset, 06:00/09:00) |
| 4 | red_transition | xy 0.69/0.31 | 254 | 30s | Time-based transition (22:00) |
| 5 | reading_toggle | 2890K (color_temp: 345) | 1 | 0s | Knob/button toggle on (instant color, minimal brightness) |
| 6 | red_toggle | xy 0.69/0.31 | 1 | 0s | Knob/button toggle on (instant color, minimal brightness) |

- Scenes 1–4 exist on all four room groups (Bedroom Lights group 2, Bathroom Lights group 3, Living Room Lights group 4, Hallway Lights group 5).
- Scenes 5–6 exist on Living Room Lights and Bedroom Lights only (bathroom and hallway have no knob).
- No group-0 (individual-bulb) scenes exist.
- Hue bulbs support ~16 scene slots per group.

### Storage rule (important)

Which scene gets recalled depends on the MQTT topic the command was published to:

- **Group topic** (`zigbee2mqtt/Bedroom Lights/set`) → uses scenes in that group's table (group 2 for Bedroom, etc).
- **Individual bulb topic** (`zigbee2mqtt/Bedroom Light 1/set`) → uses scenes in **group 0** on that bulb.

All current automations publish to group topics only. Publishing scene_add/scene_recall to an individual bulb topic will create/read group-0 scenes, which nothing else touches — avoid doing this by mistake (it silently drifts the state).

**Adding a scene via MQTT** (publish to the group topic):
```json
{"scene_add": {"ID": 1, "name": "reading_presence", "color_temp": 345, "brightness": 254, "transition": 1.5, "state": "ON"}}
{"scene_add": {"ID": 2, "name": "red_presence", "color": {"x": 0.69, "y": 0.31}, "brightness": 254, "transition": 1.5, "state": "ON"}}
```

`scene_add` with an existing ID overwrites.

**Recalling:** `{"scene_recall": 1}` — transition is baked into the scene; scene_recall does not accept a transition parameter.

**Removing:** `{"scene_remove": 5}` — removes from the scope implied by the topic (group topic → that group's table, individual topic → group 0).

## HA Helpers

| Helper | Type | Range | Purpose |
|--------|------|-------|---------|
| `input_number.living_room_brightness` | input_number | 0–255 | Tracks living room brightness for knob rotation (avoids stale z2m state) |
| `input_number.bedroom_brightness` | input_number | 0–255 | Tracks bedroom brightness for knob rotation |

Defined in `configuration.yaml`. On toggle-on, brightness fades to the helper value (minimum floor of 2). On dim-to-off, helper retains its last value above the threshold so toggle-on restores a meaningful brightness. On rotation-on from off, helper resets to the first step value and climbs from there.

## Light Schedule

```
06:00  ──── Reading mode (2890K, warm white) ────  Sunset
                                                      │
Sunset ──── Reading mode continues ───────────── 22:00
                                                      │
22:00  ──── Red mode (xy 0.69/0.31) ─────────── 00:00
                                                      │
00:00  ──── Red dim 45% (brightness 115) ─────── 02:00
                                                      │
00:00  ──── Bedroom blackout (no lights) ─────── 09:00
```

## Automations

### Living Room - Knob Controller
**ID:** `living_room_knob`

Handles all knob actions for living room via group MQTT topic:

| Action | Time | Result |
|--------|------|--------|
| Toggle (lights off) | 06:00–22:00 | scene_recall 5 (reading_toggle) → brightness fade-in 0.5s |
| Toggle (lights off) | 22:00–06:00 | scene_recall 6 (red_toggle) → brightness fade-in 0.5s |
| Toggle (lights on) | any | `{"state": "OFF", "transition": 0.5}` via group topic |
| Rotation up (lights off) | 06:00–22:00 | scene_recall 5 → climb brightness from zero |
| Rotation up (lights off) | 22:00–06:00 | scene_recall 6 → climb brightness from zero |
| Rotation up (lights on) | any | `{"brightness": X, "transition": 0.3}` via group topic (absolute value, scaled step) |
| Rotation down (lights on) | any | `{"brightness": X, "transition": 0.3}` via group topic. Dims to off when brightness ≤ 2 (sends OFF with 0.5s fade, helper retains last value). |
| Long press (hue_move) | any | Toggle between reading (2890K) and red (0.69/0.31) via group topic |

**Toggle-on sequence:** Scene_recall (brightness 1, correct color, 0s transition) instantly sets the right color at minimal brightness, then a second command fades brightness to the helper value over 0.5s (minimum brightness floor of 2). This gives a smooth fade-in with correct color from the start — no wrong-color flash, no full-brightness flash.

**Rotation-on sequence:** When rotating up while lights are off, recalls the correct scene for time of day (sets color), then starts climbing brightness from zero. Each subsequent tick increases normally.

**Dim-to-off:** Rotating down past brightness 2 sends OFF (0.5s fade) instead of reaching brightness 0. The helper keeps its last value above the threshold, so toggle-on has a meaningful brightness to restore.

**Brightness tracking:** Uses `input_number.living_room_brightness` helper to track current brightness locally. Each rotation tick updates the helper immediately (no waiting for z2m state), then publishes the new value to the group. This prevents the "spring-back" effect caused by calculating brightness from stale z2m state.

**Mode:** restart (rapid rotations cancel previous)

### Bedroom - Knob Controller
**ID:** `bedroom_knob`

Same as living room but:
- Uses Bedroom Knob MQTT topic
- Uses Bedroom Lights group topic
- Time boundary is 09:00 (not 06:00) — aligned with blackout window
- Checks `light.bedroom_light_1` for state
- Uses `input_number.bedroom_brightness` helper for brightness tracking

### Living Room - Time-based
**ID:** `living_room_sunset_reading` — At sunset, if iPhone is home → scene_recall 3 (reading_transition) via group topic.

**ID:** `living_room_red_mode` — At 22:00, if living lights on → scene_recall 4 (red_transition) via group topic.

### Living Room - Arrival
**ID:** `living_room_arrival` — When iPhone arrives home (device_tracker.andriis_iphone → home) and sun elevation < 3° → scene_recall 1 (reading_presence, 1.5s) before 22:00, scene_recall 2 (red_presence, 1.5s) after 22:00. Presence scenes for quick fade-in on arrival. Elevation threshold (vs fixed sunset offset) adapts to season automatically.

**ID:** `living_room_morning_reading` — At 06:00, if living lights on → scene_recall 3 (reading_transition) via group topic. Transitions already-on lights from red to reading.

### Presence-based (Bathroom)
**ID:** `bathroom_presence`

| Trigger | Time | Action |
|---------|------|--------|
| Presence ON | 06:00–22:00 | scene_recall 1 (reading_presence, 1.5s) via group topic |
| Presence ON | 22:00–06:00 | scene_recall 2 (red_presence, 1.5s) via group topic |
| 22:00 hits | if presence ON | scene_recall 4 (red_transition, 30s) |
| 06:00 hits | if presence ON | scene_recall 3 (reading_transition, 30s) |
| Presence OFF | any | `{"state": "OFF", "transition": 3}` via group topic (3s fade) |

### Presence-based (Hallway)
**ID:** `hallway_presence`

Identical to `bathroom_presence` but uses Hallway Sensor and Hallway Lights group topic.

### Presence-based (Bedroom)
**ID:** `bedroom_presence`

Same as bathroom but:
- Uses Bedroom Sensor instead of Bathroom Sensor
- **Blackout period 00:00–09:00** — entire automation has condition `after: 09:00, before: 00:00`
- Time triggers are 22:00 and 09:00 (not 06:00)
- Uses Bedroom Lights group topic
- Presence-OFF fades over 3s via group topic payload `{"state": "OFF", "transition": 3}`

During the blackout window (00:00–09:00), the `bedroom_knob` automation handles manual knob presses — it always recalls scene 6 (red_toggle) in that period.

### Late Night Dim
**ID:** `late_night_dim` — At 00:00, if living room or bedroom lights are on → dim to 45% brightness (115/255) with 30s transition via group MQTT topics. Aligns with bedroom sensor blackout window start.

### Safety net
**ID:** `lights_off_2am` — At 02:00, publishes `{"state": "OFF", "transition": 10}` directly to Living Room Lights and Bedroom Lights group topics. Does not touch bathroom (sensor-controlled). Uses group MQTT topics instead of `light.all_lights` to ensure proper state sync.

## Known Issues & Solutions

### Color flash on turn-on (SOLVED)
**Problem:** When using `light.turn_on` with color parameters, bulbs first restore their last state (e.g. red), then transition to the new color. Visible flash of wrong color.

**Solution:** Use Zigbee scenes (`scene_recall`). Scenes are stored on bulb firmware and apply color + brightness + transition atomically. The scene also turns the light on, so no separate `light.turn_on` is needed.

### Knob race condition / color flash (SOLVED)
**Problem:** When knobs were in the z2m group (direct Zigbee binding), pressing toggle caused the bulb to turn on with last state via direct Zigbee, then HA's scene_recall arrived ~200ms later causing a visible flash of wrong color.

**Solution:** Removed knobs from z2m groups. Knobs stay in command mode (z2m still reports actions via MQTT) but no longer send direct Zigbee commands to bulbs. All commands go through HA automations → group MQTT topic. Scene_recall is the only command that reaches the bulb, so no race condition.

### Knob poisoning group state (SOLVED)
**Problem:** Tuya TS004F knobs in command mode permanently report `state: ON`. When the knob was a group member, z2m calculated the group state as ON (because one member was ON), even when all bulbs were off. This broke state-based automation triggers.

**Solution:** Removed knobs from z2m groups. The knob's state no longer affects group state calculation. All knob control goes through HA automations.

### Knob brightness spring-back (SOLVED)
**Problem:** With knobs removed from z2m groups, brightness rotation goes through HA. Fast rotation caused "spring-back" — brightness would jump then bounce back — because each tick read the current brightness from z2m state, which lagged behind the actual bulb state.

**Solution:** Track brightness locally via `input_number` helpers (`input_number.living_room_brightness`, `input_number.bedroom_brightness`). Each rotation tick updates the helper immediately, then publishes the helper value to the group MQTT topic. The helper is always up-to-date, eliminating stale-state calculations. On toggle-on, the helper resets to 254 (scene default brightness).

### Bulbs turning on one-by-one (SOLVED)
**Problem:** Publishing scene_recall to individual bulb topics sequentially caused visible staggered turn-on.

**Solution:** Publish to the Z2M group topic (e.g. `zigbee2mqtt/Bathroom Lights/set`). The group command is sent as a single Zigbee broadcast.

### Bedroom sensor not detecting lying on side (SOLVED)
**Problem:** FP300 Bedroom Sensor stopped detecting user lying on their side in bed.

**Solution:**
1. Triggered spatial learning (recalibration) via `button.bedroom_sensor_spatial_learning`
2. Disabled AI adaptive sensitivity (`ai_sensitivity_adaptive` = off) — the adaptive algorithm was reducing sensitivity over time
3. Set motion sensitivity to "high"

### lights_off_2am not properly turning off lights (SOLVED)
**Problem:** `lights_off_2am` used `light.turn_off` on `light.all_lights` (HA group entity). The z2m state for individual room groups didn't always update, causing `light.living_room_lights` to appear "on" even after bulbs were off. This cascaded: `morning_reading_mode` falsely triggered at 06:00.

**Solution:** Changed `lights_off_2am` to publish `{"state": "OFF", "transition": 10}` directly to each room's group MQTT topic. This ensures z2m updates the state for each group properly.

### Knob-initiated off transition
Knob turn-off (toggle or dim-to-off) uses `{"state": "OFF", "transition": 0.5}` via the group MQTT topic (handled by HA automation). Presence sensor turn-off uses 3s fade. The `lights_off_2am` safety net uses 10s fade.

## Inspecting Scenes

```bash
kubectl -n smarthome exec zigbee2mqtt-0 -- cat /app/data/database.db | python3 -c "
import json, sys
for line in sys.stdin:
    try: d = json.loads(line)
    except: continue
    for ep_id, ep in (d.get('endpoints') or {}).items():
        scenes = ep.get('meta', {}).get('scenes', {})
        if scenes:
            print(d.get('ieeeAddr'), scenes)"
```
Scene keys in metadata are formatted `<sceneID>_<groupID>` (e.g. `1_2` = scene 1 in group 2).

## Configuration Files

Source of truth for HA config is stored in git at `kubernetes/apps/home-assistant/files/`:
- `configuration.yaml` — HA config (input_number helpers, integrations)
- `automations.yaml` — all automations

**Update workflow:**
1. Edit the file in the git repo
2. Copy to the HA pod: `kubectl -n smarthome cp <file> home-assistant-0:/config/<file>`
3. Reload automations: call `automation.reload` via HA API. For `configuration.yaml` changes, restart HA.
4. Test, then commit and push.
