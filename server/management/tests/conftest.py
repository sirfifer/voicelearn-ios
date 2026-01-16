"""
Pytest configuration for management server tests.

Configures Hypothesis profiles for different environments:
- default: Standard local development (100 examples)
- ci: Faster CI runs (50 examples)
- thorough: Comprehensive testing (500 examples)
"""

import logging
import os
from hypothesis import settings, Verbosity, Phase

logger = logging.getLogger(__name__)

# Detect CI environment
IS_CI = os.environ.get("CI") == "true" or os.environ.get("GITHUB_ACTIONS") == "true"

# Configure Hypothesis profiles
settings.register_profile(
    "default",
    max_examples=100,
    verbosity=Verbosity.normal,
    deadline=None,  # Disable deadline for potentially slow tests
)

settings.register_profile(
    "ci",
    max_examples=50,
    verbosity=Verbosity.normal,
    deadline=None,
    suppress_health_check=[],
    phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.shrink],
)

settings.register_profile(
    "thorough",
    max_examples=500,
    verbosity=Verbosity.verbose,
    deadline=None,
)

settings.register_profile(
    "debug",
    max_examples=10,
    verbosity=Verbosity.verbose,
    deadline=None,
)

# Load appropriate profile
profile_name = os.environ.get("HYPOTHESIS_PROFILE", "ci" if IS_CI else "default")
settings.load_profile(profile_name)

logger.info(f"Hypothesis profile: {profile_name}")
