"""
Source importer plugins.

Each plugin in this directory provides access to a curriculum source
(MIT OCW, CK-12, MERLOT, Stanford, etc.).

Plugins are auto-discovered but must be enabled via the Plugin Manager.
"""

# Import plugins to trigger @SourceRegistry.register decorators
from . import mit_ocw
from . import ck12_flexbook
from . import merlot

__all__ = [
    "mit_ocw",
    "ck12_flexbook",
    "merlot",
]
