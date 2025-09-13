from typing import (
    Any,
    Awaitable,
    Mapping,
    Protocol,
    overload,
    Literal,
    Callable,
)
from homeassistant.core import HomeAssistant
import logging

class StateLike(Protocol):
    def get(self, entity_id: str) -> str | None: ...
    def getattr(self, entity_id: str) -> Mapping[str, Any] | None: ...
    def set(self, entity_id: str, value: Any) -> None: ...

# ---- Pyscript "service" typing -----------------------------------------

class _ServiceFunction(Protocol):
    """Represents a concrete service, e.g. service.light.turn_on."""

    @overload
    def __call__(
        self,
        *,
        blocking: bool = False,
        return_response: Literal[False] = False,
        **kwargs: Any,
    ) -> Awaitable[None]: ...
    @overload
    def __call__(
        self,
        *,
        blocking: bool = False,
        return_response: Literal[True] = True,
        **kwargs: Any,
    ) -> Awaitable[Mapping[str, Any] | None]: ...
    def __call__(
        self,
        *,
        blocking: bool = False,
        return_response: bool = False,
        **kwargs: Any,
    ) -> Awaitable[Any]: ...

class _ServiceDomain(Protocol):
    """Represents a service domain proxy, e.g. service.light."""
    def __getattr__(self, service_name: str) -> _ServiceFunction: ...

class ServiceLike(Protocol):
    """
    Pyscript `service` global.

    Supports:
      - service.call("domain", "name", **kwargs)
      - service.<domain>.<name>(**kwargs)
      - service.has_service("domain", "name")
    """

    def __getattr__(self, domain: str) -> _ServiceDomain: ...

    def has_service(self, domain: str, name: str) -> bool: ...

    @overload
    def call(
        self,
        domain: str,
        name: str,
        *,
        blocking: bool = False,
        return_response: Literal[False] = False,
        **kwargs: Any,
    ) -> Awaitable[None]: ...
    @overload
    def call(
        self,
        domain: str,
        name: str,
        *,
        blocking: bool = False,
        return_response: Literal[True] = True,
        **kwargs: Any,
    ) -> Awaitable[Mapping[str, Any] | None]: ...
    def call(
        self,
        domain: str,
        name: str,
        *,
        blocking: bool = False,
        return_response: bool = False,
        **kwargs: Any,
    ) -> Awaitable[Any]: ...

    @overload
    def __call__[T](self, name: str) -> Callable[[T], T]: ...
    @overload
    def __call__[T](
        self,
        *service_names: str,
        supports_response: Literal["none", "only", "optional"] = "none"
    ) -> Callable[[T], T]: ...
    @overload
    def __call__[T](self, func: T) -> T: ...
    def __call__(self, arg: Any) -> Any: ...

# ---- Typed globals supplied by Pyscript --------------------------------
hass: HomeAssistant
log: logging.Logger
state: StateLike
service: ServiceLike
