from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pyscript_typing import log, service  # type: ignore[reportMissingImports]

# File: pyscript/hello.py
@service
def hello_world():
    log.info("Hello from Pyscript!")
