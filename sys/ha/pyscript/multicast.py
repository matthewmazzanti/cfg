"""Multicast planning & execution with upfront snapshots (records-based).

Exposes two services:
  • pyscript.multicast_set(entity_ids, target_state, brightness)
  • pyscript.multicast_toggle(entity_ids, state_bias=True, brightness=255)
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import TYPE_CHECKING

from homeassistant.helpers import entity_registry as er

# ---------------------------------------------------------------------------
# Globals provided by Pyscript runtime (typed)
# ---------------------------------------------------------------------------
if TYPE_CHECKING:
    from pyscript_typing import hass, log, state, service  # type: ignore[reportMissingImports]

# ---------------------------------------------------------------------------
# Entity snapshot records
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class LightRecord:
    """Snapshot of a light entity.

    Attributes:
        entity_id: HA entity ID.
        is_zwave: True if Z-Wave.
        is_on: Current state (True/False) or None if unknown.
        brightness: Current brightness (0–255) or None if not available.
    """
    entity_id: str
    is_zwave: bool
    is_on: bool | None
    brightness: int | None

@dataclass(frozen=True)
class SwitchRecord:
    """Snapshot of a switch entity.

    Attributes:
        entity_id: HA entity ID.
        is_zwave: True if Z-Wave.
        is_on: Current state (True/False) or None if unknown.
    """
    entity_id: str
    is_zwave: bool
    is_on: bool | None

@dataclass(frozen=True)
class OtherRecord:
    """Snapshot of any other entity that supports on/off.

    Attributes:
        entity_id: HA entity ID.
        is_on: Current state (True/False) or None if unknown.
    """
    entity_id: str
    is_on: bool | None

EntityRecord = LightRecord | SwitchRecord | OtherRecord

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_is_on(entity_id: str) -> bool | None:
    """Return True/False/None for entity state from HA."""
    raw_state = state.get(entity_id)
    match raw_state:
        case "on":
            return True
        case "off":
            return False
        case _:
            return None


def _get_brightness(entity_id: str) -> int | None:
    """Return brightness 0–255 if available, else None."""
    attrs = state.getattr(entity_id)
    if not attrs:
        return None
    value = attrs.get("brightness")
    return value if isinstance(value, int) else None


def _is_zwave_entity(ent_reg: er.EntityRegistry, entity_id: str) -> bool:
    """Return True if entity belongs to zwave_js integration."""
    ent = ent_reg.async_get(entity_id)
    return bool(ent and ent.platform == "zwave_js")


def ha_to_zwave_level(brightness: int) -> int:
    """Convert HA brightness (0–255) to Z-Wave multilevel (0–99)."""
    if brightness <= 0:
        return 0
    return max(1, round(brightness * 99 / 255))


def expand_entity_ids(entity_ids: object) -> list[str]:
    """Normalize service argument into a list of entity IDs."""
    if isinstance(entity_ids, str):
        return [entity_ids]
    if isinstance(entity_ids, list) and all(isinstance(e, str) for e in entity_ids):
        return entity_ids
    raise ValueError("entity_ids must be a string or list of strings")


def expect_bool(value: object, name: str) -> bool:
    """Validate that `value` is a bool; raise if not."""
    if not isinstance(value, bool):
        raise ValueError(f"{name} must be a boolean")
    return value


def expect_brightness(value: object, name: str) -> int:
    """Validate that `value` is an int in [0, 255]; raise if not."""
    if not isinstance(value, int) or not (0 <= value <= 255):
        raise ValueError(f"{name} must be an int between 0 and 255")
    return value

# ---------------------------------------------------------------------------
# Snapshot collector
# ---------------------------------------------------------------------------

def collect_entities(
    ent_reg: er.EntityRegistry,
    entity_ids: list[str],
) -> list[EntityRecord]:
    """Collect entity snapshots for given IDs.

    Each entity is classified into LightRecord, SwitchRecord, or OtherRecord
    depending on its domain.
    """
    records: list[EntityRecord] = []

    for entity_id in entity_ids:
        is_on = _get_is_on(entity_id)

        match entity_id.split(".", 1):
            case ["light", _]:
                record = LightRecord(
                    entity_id=entity_id,
                    is_zwave=_is_zwave_entity(ent_reg, entity_id),
                    is_on=is_on,
                    brightness=_get_brightness(entity_id),
                )
            case ["switch", _]:
                record = SwitchRecord(
                    entity_id=entity_id,
                    is_zwave=_is_zwave_entity(ent_reg, entity_id),
                    is_on=is_on,
                )
            case _:
                record = OtherRecord(entity_id=entity_id, is_on=is_on)

        records.append(record)

    return records

# ---------------------------------------------------------------------------
# Core service functions (no class wrapper)
# ---------------------------------------------------------------------------

async def apply_set(
    records: list[EntityRecord],
    target_state: bool,
    brightness: int,
) -> None:
    """Plan and execute service calls to set switches/lights/others.

    - Z-Wave switches: multicast if 2+ targets, else fall back to HA call.
    - Z-Wave lights: multicast if 2+ targets, else fall back to light call.
    - Non-Z-Wave switches/others: use homeassistant.turn_on/off.
    - Non-Z-Wave lights: use light.turn_on/off.
    - Brightness only included on turn_on for lights, and only if target_state is True.
    """

    zw_switches: list[str] = []
    zw_lights: list[str] = []
    ha_targets: list[str] = []
    light_targets: list[str] = []

    # -------- Plan --------
    for rec in records:
        match rec:
            case LightRecord(is_on=False) if not target_state:
                continue
            case LightRecord(is_on=True, brightness=curr_bright) \
                if target_state and curr_bright == brightness:
                continue
            case SwitchRecord(is_on=is_on) if is_on == target_state:
                continue
            case OtherRecord(is_on=is_on) if is_on == target_state:
                continue

            case LightRecord(is_zwave=True):
                zw_lights.append(rec.entity_id)
            case LightRecord(is_zwave=False):
                light_targets.append(rec.entity_id)
            case SwitchRecord(is_zwave=True):
                zw_switches.append(rec.entity_id)
            case SwitchRecord(is_zwave=False):
                ha_targets.append(rec.entity_id)
            case OtherRecord():
                ha_targets.append(rec.entity_id)

            case x:
                raise ValueError(f"Unhandled case: {x}")

    # Handle fallback to general services for single zwave entity
    if len(zw_switches) == 1:
        ha_targets.extend(zw_switches)
        zw_switches.clear()

    if len(zw_lights) == 1:
        light_targets.extend(zw_lights)
        zw_switches.clear()

    # -------- Execute --------
    if zw_switches:
        service.zwave_js.multicast_set_value(
            entity_id=zw_switches,
            command_class=37,
            property="targetValue",
            value=target_state,
            blocking=False,
        )

    if zw_lights:
        service.zwave_js.multicast_set_value(
            entity_id=zw_lights,
            command_class=38,
            property="targetValue",
            value=ha_to_zwave_level(brightness) if target_state else 0,
            blocking=False,
        )

    if ha_targets:
        service.call(
            "homeassistant",
            "turn_on" if target_state else "turn_off",
            entity_id=ha_targets,
            blocking=False,
        )

    if light_targets:
        if target_state:
            service.light.turn_on(
                entity_id=light_targets,
                brightness=brightness,
                blocking=False
            )
        else:
            service.light.turn_off(
                entity_id=light_targets,
                blocking=False
            )


async def apply_toggle(
    records: list[EntityRecord],
    state_bias: bool,
    brightness: int,
) -> None:
    """Toggle entities with bias.

    - If all records are already in `state_bias`, flip to `not state_bias`.
    - Otherwise, set group to `state_bias`.
    - Lights only use `brightness` when turning on (state_bias/target_state True).
    - `None` state counts as differing from bias.
    """
    if not records:
        return

    target_state = not state_bias
    for rec in records:
        if rec.is_on != state_bias:
            target_state = state_bias
            break

    await apply_set(
        records=records,
        target_state=target_state,
        brightness=brightness
    )

# ---------------------------------------------------------------------------
# Service entrypoints
# ---------------------------------------------------------------------------

@service
async def multicast_set(
    entity_ids: object,
    target_state: object,
    brightness: object = 255,
) -> None:
    """Service: pyscript.multicast_set

    Set group of entities to target state/brightness.

    Args:
        entity_ids: str | list[str] of entities.
        target_state: bool, desired on/off state for switches and others.
        brightness: int [0..255], brightness for lights (only used if target_state is
            True).
    """
    entity_ids = expand_entity_ids(entity_ids)
    target_state = expect_bool(target_state, "target_state")
    brightness = expect_brightness(brightness, "brightness")

    records = collect_entities(er.async_get(hass), entity_ids)

    await apply_set(
        records=records,
        target_state=target_state,
        brightness=brightness
    )


@service
async def multicast_toggle(
    entity_ids: object,
    state_bias: object = True,
    brightness: object = 255,
) -> None:
    """Service: pyscript.multicast_toggle

    Toggle group of entities with bias.

    Args:
        entity_ids: str | list[str] of entities.
        state_bias: bool, preferred state. If all match, toggle away; else set to this.
        brightness: int [0..255], brightness for lights (only used if final state is
            True).
    """
    entity_ids = expand_entity_ids(entity_ids)
    state_bias = expect_bool(state_bias, "bias")
    brightness = expect_brightness(brightness, "brightness")

    records = collect_entities(er.async_get(hass), entity_ids)

    await apply_toggle(
        records=records,
        state_bias=state_bias,
        brightness=brightness
    )
