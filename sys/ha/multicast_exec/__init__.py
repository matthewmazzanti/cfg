from __future__ import annotations

import logging
from typing import Final

import voluptuous as vol
import homeassistant.helpers.config_validation as cv

from homeassistant.core import HomeAssistant, ServiceCall

from .multicast import MulticastManager

DOMAIN: Final = "multicast_exec"
_LOGGER = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Service schemas (voluptuous)
# ---------------------------------------------------------------------------

SERVICE_SET_SCHEMA = vol.Schema({
    vol.Required("entity_id"): cv.entity_ids,
    vol.Required("target_state"): cv.boolean,
    vol.Optional("brightness", default=255): vol.All(
        vol.Coerce(int),
        vol.Range(min=0, max=255)
    ),
})

SERVICE_TOGGLE_SCHEMA = vol.Schema({
    vol.Required("entity_id"): cv.entity_ids,
    vol.Optional("state_bias", default=True): cv.boolean,
    vol.Optional("brightness", default=255): vol.All(
        vol.Coerce(int),
        vol.Range(min=0, max=255)
    ),
})

# ---------------------------------------------------------------------------
# Service registration
# ---------------------------------------------------------------------------

async def async_setup(hass: HomeAssistant, config: dict) -> bool:
    mgr = MulticastManager(hass)
    hass.data[DOMAIN] = mgr

    async def _svc_set(call: ServiceCall) -> None:
        await mgr.apply_set(
            records=mgr.collect_entities(call.data["entity_id"]),
            target_state=call.data["target_state"],
            brightness=call.data.get("brightness", 255),
        )

    async def _svc_toggle(call: ServiceCall) -> None:
        await mgr.apply_toggle(
            records=mgr.collect_entities(call.data["entity_id"]),
            state_bias=call.data["state_bias"],
            brightness=call.data["brightness"],
        )

    hass.services.async_register(
        DOMAIN,
        "set",
        _svc_set,
        schema=SERVICE_SET_SCHEMA
    )

    hass.services.async_register(
        DOMAIN,
        "toggle",
        _svc_toggle,
        schema=SERVICE_TOGGLE_SCHEMA
    )

    _LOGGER.debug("Registered services: %s.set, %s.toggle (schemas attached)", DOMAIN, DOMAIN)
    return True
