from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Final

from homeassistant.const import ATTR_ENTITY_ID
from homeassistant.core import HomeAssistant
from homeassistant.helpers import entity_registry as er

_LOGGER = logging.getLogger(__name__)

# --- Records -----------------------------------------------------------------

@dataclass(frozen=True)
class LightRecord:
    entity_id: str
    is_zwave: bool
    is_on: bool | None
    brightness: int | None

@dataclass(frozen=True)
class SwitchRecord:
    entity_id: str
    is_zwave: bool
    is_on: bool | None

@dataclass(frozen=True)
class OtherRecord:
    entity_id: str
    is_on: bool | None

EntityRecord = LightRecord | SwitchRecord | OtherRecord

# --- Manager -----------------------------------------------------------------

class MulticastManager:
    """Plan and execute multicast-aware set/toggle operations."""

    DOMAIN: Final = "multicast_exec"

    def __init__(self, hass: HomeAssistant) -> None:
        self.hass = hass
        self.ent_reg = er.async_get(hass)

    # ----- helpers -----

    def _get_is_on(self, entity_id: str) -> bool | None:
        st = self.hass.states.get(entity_id)
        if st is None:
            return None
        match st.state:
            case "on":
                return True
            case "off":
                return False
            case _:
                return None

    def _get_brightness(self, entity_id: str) -> int | None:
        st = self.hass.states.get(entity_id)
        if st is None:
            return None
        val = st.attributes.get("brightness")
        return val if isinstance(val, int) else None

    def _is_zwave_entity(self, entity_id: str) -> bool:
        ent = self.ent_reg.async_get(entity_id)
        return bool(ent and ent.platform == "zwave_js")

    @staticmethod
    def _ha_to_zwave_level(brightness_0_255: int) -> int:
        """HA 0–255 → Z-Wave 0–99; keep 0 as 0; non-zero min is 1."""
        if brightness_0_255 <= 0:
            return 0
        # round to nearest and clamp to 1..99
        lvl = round(brightness_0_255 * 99 / 255)
        return 1 if lvl < 1 else (99 if lvl > 99 else lvl)

    # ----- snapshots -----

    def collect_entities(self, entity_ids: list[str]) -> list[EntityRecord]:
        records: list[EntityRecord] = []

        for entity_id in entity_ids:
            is_on = self._get_is_on(entity_id)
            domain = entity_id.split(".", 1)[0]

            match domain:
                case "light":
                    rec = LightRecord(
                        entity_id=entity_id,
                        is_zwave=self._is_zwave_entity(entity_id),
                        is_on=is_on,
                        brightness=self._get_brightness(entity_id),
                    )
                case "switch":
                    rec = SwitchRecord(
                        entity_id=entity_id,
                        is_zwave=self._is_zwave_entity(entity_id),
                        is_on=is_on,
                    )
                case _:
                    rec = OtherRecord(entity_id=entity_id, is_on=is_on)

            records.append(rec)

        _LOGGER.debug("Collected %d records: %s", len(records), records)
        return records

    # ----- core operations -----

    async def apply_set(
        self,
        records: list[EntityRecord],
        *,
        target_state: bool,
        brightness: int,
    ) -> None:
        zw_switches: list[str] = []
        zw_lights: list[str] = []
        ha_targets: list[str] = []
        light_targets: list[str] = []

        for rec in records:
            match rec:
                # no-ops
                case LightRecord(is_on=False) if not target_state:
                    _LOGGER.debug("Skip %s (already off)", rec.entity_id)
                    continue
                case LightRecord(is_on=True, brightness=curr_bright) if target_state and curr_bright == brightness:
                    _LOGGER.debug("Skip %s (already at brightness %d)", rec.entity_id, brightness)
                    continue
                case SwitchRecord(is_on=is_on) if is_on == target_state:
                    _LOGGER.debug("Skip %s (already in state %s)", rec.entity_id, target_state)
                    continue
                case OtherRecord(is_on=is_on) if is_on == target_state:
                    _LOGGER.debug("Skip %s (already in state %s)", rec.entity_id, target_state)
                    continue

                # bucketize
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
                    raise ValueError(f"Unhandled record: {x}")

        # Fallback: single Z-Wave item → regular service
        if len(zw_switches) == 1:
            ha_targets.extend(zw_switches)
            zw_switches.clear()
        if len(zw_lights) == 1:
            light_targets.extend(zw_lights)
            zw_lights.clear()

        # Execute
        if zw_switches:
            data = {
                ATTR_ENTITY_ID: zw_switches,
                "command_class": 37,      # SWITCH_BINARY
                "property": "targetValue",
                "value": target_state,
            }
            _LOGGER.debug("Exec: zwave_js.multicast_set_value (switches) %s", data)
            await self.hass.services.async_call("zwave_js", "multicast_set_value", data, blocking=False)

        if zw_lights:
            value = self._ha_to_zwave_level(brightness) if target_state else 0
            data = {
                ATTR_ENTITY_ID: zw_lights,
                "command_class": 38,      # SWITCH_MULTILEVEL
                "property": "targetValue",
                "value": value,
            }
            _LOGGER.debug("Exec: zwave_js.multicast_set_value (lights) %s", data)
            await self.hass.services.async_call("zwave_js", "multicast_set_value", data, blocking=False)

        if ha_targets:
            svc = "turn_on" if target_state else "turn_off"
            data = {ATTR_ENTITY_ID: ha_targets}
            _LOGGER.debug("Exec: homeassistant.%s %s", svc, data)
            await self.hass.services.async_call("homeassistant", svc, data, blocking=False)

        if light_targets:
            if target_state:
                data = {ATTR_ENTITY_ID: light_targets, "brightness": brightness}
                _LOGGER.debug("Exec: light.turn_on %s", data)
                await self.hass.services.async_call("light", "turn_on", data, blocking=False)
            else:
                data = {ATTR_ENTITY_ID: light_targets}
                _LOGGER.debug("Exec: light.turn_off %s", data)
                await self.hass.services.async_call("light", "turn_off", data, blocking=False)

    async def apply_toggle(
        self,
        records: list[EntityRecord],
        *,
        state_bias: bool,
        brightness: int,
    ) -> None:
        if not records:
            _LOGGER.debug("Toggle: no records; nothing to do")
            return

        # If any differs from bias → target=bias; else flip away
        target_state = not state_bias
        for rec in records:
            if rec.is_on != state_bias:
                target_state = state_bias
                break

        _LOGGER.debug("Toggle computed target_state=%s (bias=%s)", target_state, state_bias)
        await self.apply_set(records, target_state=target_state, brightness=brightness)
