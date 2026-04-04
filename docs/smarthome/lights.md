# Smart Home Lighting System

## Architecture Overview

All lights are Philips Hue bulbs connected via Zigbee2MQTT (z2m.pavlenko.io).
Home Assistant (ha.pavlenko.io) handles automations. MQTT is the communication layer.

**Key design decision:** All "turn on" actions use **Zigbee scenes stored on bulb firmware** (`scene_recall`) instead of `light.turn_on` with color parameters. This prevents the color flash problem (see Known Issues).

## Devices

### Lights (Philips Hue bulbs)

| Z2M Name | HA Entity | Room | Group |
|----------|-----------|------|-------|
| Light Kitchen Table | light.light_kitchen_table | Living room | Living Lights |
| Light Living Lamp | light.light_living_lamp | Living room | Living Lights |
| Light Toilet 1 | light.light_toilet_1 | Bathroom | Toilet Lights |
| Light Toilet 2 | light.light_toilet_2 | Bathroom | Toilet Lights |
| Light Bedroom 1 | light.light_bedroom_1 | Bedroom | Bedroom Lights |
| Light Bedroom 2 | light.light_bedroom_2 | Bedroom | Bedroom Lights |

### Z2M Groups

| Group Name | Members | MQTT Topic |
|------------|---------|------------|
| Living Lights | Light Kitchen Table, Light Living Lamp | zigbee2mqtt/Living Lights/set |
| Toilet Lights | Light Toilet 1, Light Toilet 2 | zigbee2mqtt/Toilet Lights/set |
| Bedroom Lights | Light Bedroom 1, Light Bedroom 2 | zigbee2mqtt/Bedroom Lights/set |

**Important:** Use group topics for simultaneous control. Publishing to individual bulbs sequentially causes visible one-by-one turn-on.

### Presence Sensors (Aqara FP300)

| Name | HA Entity | Room | Placement |
|------|-----------|------|-----------|
| Aqara FP300 Sensor 1 | binary_sensor.aqara_fp300_sensor_1_presence | Bathroom | Battery powered, mmWave + PIR |
| Aqara FP300 Sensor 2 | binary_sensor.aqara_fp300_sensor_2_presence | Bedroom | Ceiling-mounted, center of room above the bed. Battery powered, mmWave + PIR |

**Sensor settings:**
- Sensor 1 (bathroom): motion_sensitivity=medium, ai_adaptive=on, absence_delay=10s
- Sensor 2 (bedroom): motion_sensitivity=high, ai_adaptive=off (disabled to fix detection issues), absence_delay=10s, spatial_learning triggered 2026-04-01

### Smart Knobs (Tuya ERS-10TZBVK-AA)

| Name | MQTT Topic | Room | Group | Operation Mode |
|------|------------|------|-------|----------------|
| Light Switch 1 | zigbee2mqtt/Light Switch 1 | Bedroom | Bedroom Lights | command |
| Light Switch 2 | zigbee2mqtt/Light Switch 2 | Living room | Living Lights | command |

**Both knobs run in Z2M "command" mode** — toggle and brightness rotation are handled directly at the Zigbee level, bypassing HA. This gives smooth, lag-free brightness control. The HA knob automations (`knob_living_room`, `knob_bedroom`) are **disabled**.

Active knob HA automations (for features Z2M can't handle):
- `knob_bedroom_color_toggle` (on) — long press (hue_move) toggles between reading (2890K) and red
- `knob_living_room_color_toggle` (on) — same for living room

## Zigbee Scenes (stored on bulb firmware)

Scenes are stored directly on each bulb. The scene_recall command turns the light on AND sets color/brightness/transition atomically — no flash.

| Scene ID | Name | Color | Brightness | Transition | Use Case |
|----------|------|-------|------------|------------|----------|
| 1 | reading | 2890K (color_temp: 345) | 254 | 2s | Presence on / knob toggle during daytime |
| 2 | red | xy 0.69/0.31 | 254 | 2s | Presence on / knob toggle during nighttime |
| 3 | reading_slow | 2890K (color_temp: 345) | 254 | 30s | Time-based transition (sunset, 6AM/9AM) |
| 4 | red_slow | xy 0.69/0.31 | 254 | 30s | Time-based transition (22:00) |

Scenes 1-4 are stored on ALL bulbs (toilet, bedroom, living room).

**Adding a scene via MQTT:**
```json
{"scene_add": {"ID": 1, "name": "reading", "color_temp": 345, "brightness": 254, "transition": 2, "state": "ON"}}
{"scene_add": {"ID": 2, "name": "red", "color": {"x": 0.69, "y": 0.31}, "brightness": 254, "transition": 2, "state": "ON"}}
```

**Recalling:** `{"scene_recall": 1}` — note: scene_recall does NOT accept a transition parameter; transition is embedded in the scene definition.

**Removing:** `{"scene_remove": 5}`

**Capacity:** Hue bulbs support ~16 scene slots.

## Light Schedule

```
06:00  ──── Reading mode (2890K, warm white) ────  Sunset
                                                      │
Sunset ──── Reading mode continues ───────────── 22:00
                                                      │
22:00  ──── Red mode (xy 0.69/0.31) ─────────── 00:00
                                                      │
00:00  ──── Bedroom blackout (no lights) ─────── 09:00
```

## Automations

### Presence-based (Toilet)
**ID:** `toilet_lights_presence`

| Trigger | Time | Action |
|---------|------|--------|
| Presence ON | 06:00–22:00 | scene_recall 1 (reading, 2s) via group topic |
| Presence ON | 22:00–06:00 | scene_recall 2 (red, 2s) via group topic |
| 22:00 hits | if presence ON | scene_recall 4 (red_slow, 30s) |
| 06:00 hits | if presence ON | scene_recall 3 (reading_slow, 30s) |
| Presence OFF | any | light.turn_off |

### Presence-based (Bedroom)
**ID:** `bedroom_lights_presence`

Same as toilet but:
- Uses Sensor 2 instead of Sensor 1
- **Blackout period 00:00–09:00** — entire automation has condition `after: 09:00, before: 00:00`
- Time triggers are 22:00 and 09:00 (not 06:00)
- Uses Bedroom Lights group topic

### Time-based (Living Room)
**ID:** `sunset_reading_mode` — At sunset, if living lights on → scene_recall 3 (reading_slow) to individual bulbs

**ID:** `red_mode` — At 22:00, if living lights on → scene_recall 4 (red_slow) to individual bulbs

**ID:** `living_lights_on_scene` — When living lights turn on (off→on), recall correct scene for time of day:
- 06:00–22:00 → scene_recall 1 (reading, 2s)
- 22:00–06:00 → scene_recall 2 (red, 2s)

**Note:** Living room has no presence sensor. Lights are controlled by knob (toggle/brightness) and time-based automations. The `living_lights_on_scene` automation corrects the color when lights are turned on by the knob (since the knob restores last state via Zigbee). There is a brief flash of the old color before the scene takes effect (~200-300ms HA delay), but the 2s scene transition makes it smooth and acceptable.

## Known Issues & Solutions

### Color flash on turn-on (SOLVED)
**Problem:** When using `light.turn_on` with color parameters, bulbs first restore their last state (e.g. red), then transition to the new color. Visible flash of wrong color.

**Solution:** Use Zigbee scenes (`scene_recall`). Scenes are stored on bulb firmware and apply color + brightness + transition atomically. The scene also turns the light on, so no separate `light.turn_on` is needed.

**Caveat for living room:** The knob toggles lights directly at the Zigbee level (command mode), so the bulb restores last state before HA can react. The `living_lights_on_scene` automation then corrects via scene_recall. Brief old-color flash is unavoidable but acceptable with 2s transition.

### Bulbs turning on one-by-one (SOLVED)
**Problem:** Publishing scene_recall to individual bulb topics sequentially caused visible staggered turn-on.

**Solution:** Publish to the Z2M group topic (e.g. `zigbee2mqtt/Toilet Lights/set`). The group command is sent as a single Zigbee broadcast.

**Note:** Living room time-based automations still publish to individual bulbs (not group topic). This is fine because lights are already on and the 30s transition masks any stagger.

### Bedroom sensor not detecting lying on side (SOLVED)
**Problem:** FP300 Sensor 2 stopped detecting user lying on their side in bed.

**Solution:**
1. Triggered spatial learning (recalibration) via `button.aqara_fp300_sensor_2_spatial_learning`
2. Disabled AI adaptive sensitivity (`ai_sensitivity_adaptive` = off) — the adaptive algorithm was reducing sensitivity over time
3. Set motion sensitivity to "high"

### Knob brightness sync issues (SOLVED)
**Problem:** When knob brightness was handled through HA automations, there were sync issues between HA state and actual bulb state.

**Solution:** Keep knobs in Z2M "command" mode — brightness rotation handled directly at Zigbee level. HA knob automations (`knob_living_room`, `knob_bedroom`) are disabled. Only special actions (color toggle on long press) go through HA.
