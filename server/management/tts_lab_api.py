"""
TTS Lab API - Experimentation Interface

Provides endpoints for TTS model experimentation before batch processing:
- Generate test audio with specific configurations
- Save/load TTS configurations
- Compare different models and settings
- Prepare configurations for batch conversion

Supports all Kyutai models:
- Kyutai TTS 1.6B (delayed streams, 40+ voices)
- Kyutai Pocket TTS (100M, CPU-only)
- Fish Speech V1.5 (zero-shot cloning)
"""

import asyncio
import json
import logging
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

import aiofiles
from aiohttp import web

logger = logging.getLogger(__name__)


# =============================================================================
# Configuration Storage
# =============================================================================

TTS_LAB_DIR = Path(__file__).parent / "tts_lab_configs"
TTS_LAB_DIR.mkdir(exist_ok=True)


class TTSLabConfig:
    """TTS Lab configuration for experimentation."""

    def __init__(
        self,
        model: str,
        voice: str,
        cfg_coef: float = 2.0,
        n_q: int = 24,
        padding_between: int = 1,
        padding_bonus: int = 0,
        temperature: float = 1.0,
        top_p: float = 0.95,
        batch_size: int = 8,
    ):
        self.model = model
        self.voice = voice
        self.cfg_coef = cfg_coef
        self.n_q = n_q
        self.padding_between = padding_between
        self.padding_bonus = padding_bonus
        self.temperature = temperature
        self.top_p = top_p
        self.batch_size = batch_size

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "model": self.model,
            "voice": self.voice,
            "cfg_coef": self.cfg_coef,
            "n_q": self.n_q,
            "padding_between": self.padding_between,
            "padding_bonus": self.padding_bonus,
            "temperature": self.temperature,
            "top_p": self.top_p,
            "batch_size": self.batch_size,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TTSLabConfig":
        """Create from dictionary."""
        return cls(
            model=data["model"],
            voice=data["voice"],
            cfg_coef=data.get("cfg_coef", 2.0),
            n_q=data.get("n_q", 24),
            padding_between=data.get("padding_between", 1),
            padding_bonus=data.get("padding_bonus", 0),
            temperature=data.get("temperature", 1.0),
            top_p=data.get("top_p", 0.95),
            batch_size=data.get("batch_size", 8),
        )


# =============================================================================
# Model Information
# =============================================================================

SUPPORTED_MODELS = {
    "kyutai-tts-1.6b": {
        "name": "Kyutai TTS 1.6B",
        "parameters": "1.6B",
        "release_date": "July 2025",
        "capabilities": [
            "40+ voices (including emotional)",
            "Delayed streams (low latency)",
            "Voice cloning",
            "Batch processing optimized",
        ],
        "voices": [
            "sarah",
            "john",
            "emma",
            "alex",
            "sarah-happy",
            "sarah-sad",
            "john-excited",
            "emma-calm",
        ],
        "config_params": {
            "cfg_coef": {"min": 1.0, "max": 5.0, "default": 2.0},
            "n_q": {"min": 8, "max": 32, "default": 24},
            "padding_between": {"min": 0, "max": 5, "default": 1},
            "padding_bonus": {"min": -3, "max": 3, "default": 0},
            "temperature": {"min": 0.1, "max": 2.0, "default": 1.0},
            "top_p": {"min": 0.1, "max": 1.0, "default": 0.95},
        },
    },
    "kyutai-pocket-tts": {
        "name": "Kyutai Pocket TTS",
        "parameters": "100M",
        "release_date": "Jan 13, 2026",
        "capabilities": [
            "8 built-in voices",
            "Voice cloning from 5s",
            "CPU-only (no GPU)",
            "6x real-time speed",
            "Sub-50ms latency",
        ],
        "voices": [
            "voice1",
            "voice2",
            "voice3",
            "voice4",
            "voice5",
            "voice6",
            "voice7",
            "voice8",
        ],
        "config_params": {
            "cfg_coef": {"min": 1.0, "max": 5.0, "default": 2.0},
            "n_q": {"min": 8, "max": 24, "default": 24},
            "temperature": {"min": 0.1, "max": 2.0, "default": 1.0},
        },
    },
    "fish-speech-v1.5": {
        "name": "Fish Speech V1.5",
        "parameters": "~2B",
        "release_date": "Late 2025",
        "capabilities": [
            "Zero-shot voice cloning",
            "Multilingual (30+ languages)",
            "Cross-lingual synthesis",
            "Batch processing",
        ],
        "voices": ["default"],  # Uses voice cloning
        "config_params": {
            "temperature": {"min": 0.1, "max": 2.0, "default": 1.0},
            "top_p": {"min": 0.1, "max": 1.0, "default": 0.95},
        },
    },
}


# =============================================================================
# API Endpoints
# =============================================================================


async def handle_list_models(request: web.Request) -> web.Response:
    """
    GET /api/tts-lab/models

    List all supported TTS models with their capabilities.

    Response:
    {
        "models": [
            {
                "id": "kyutai-tts-1.6b",
                "name": "Kyutai TTS 1.6B",
                "parameters": "1.6B",
                "release_date": "July 2025",
                "capabilities": [...],
                "voices": [...],
                "config_params": {...}
            }
        ]
    }
    """
    models = []
    for model_id, info in SUPPORTED_MODELS.items():
        models.append({"id": model_id, **info})

    return web.json_response({"models": models})


async def handle_generate_test_audio(request: web.Request) -> web.Response:
    """
    POST /api/tts-lab/generate

    Generate test audio with specific configuration.

    Request body:
    {
        "text": "The French Revolution began in 1789...",
        "config": {
            "model": "kyutai-tts-1.6b",
            "voice": "sarah",
            "cfg_coef": 2.0,
            "n_q": 24,
            "padding_between": 1,
            "padding_bonus": 0,
            "temperature": 1.0,
            "top_p": 0.95
        }
    }

    Response:
    {
        "id": "audio-uuid",
        "url": "/api/tts-lab/audio/audio-uuid.wav",
        "duration": 4.5,
        "config": {...},
        "generated_at": "2026-01-19T12:00:00Z"
    }
    """
    try:
        data = await request.json()
    except Exception:
        return web.json_response({"error": "Invalid JSON body"}, status=400)

    text = data.get("text")
    if not text or not text.strip():
        return web.json_response(
            {"error": "Missing or empty 'text' field"}, status=400
        )

    config_data = data.get("config")
    if not config_data:
        return web.json_response({"error": "Missing 'config' field"}, status=400)

    try:
        config = TTSLabConfig.from_dict(config_data)
    except (KeyError, ValueError) as e:
        return web.json_response({"error": f"Invalid config: {e}"}, status=400)

    # Validate model
    if config.model not in SUPPORTED_MODELS:
        return web.json_response(
            {
                "error": f"Unsupported model '{config.model}'. Supported: {list(SUPPORTED_MODELS.keys())}"
            },
            status=400,
        )

    # TODO: Actual TTS generation
    # For now, simulate generation
    audio_id = str(uuid.uuid4())
    duration = len(text) / 15.0  # Rough estimate: 15 chars/second

    # Simulate processing time
    await asyncio.sleep(0.5)

    result = {
        "id": audio_id,
        "url": f"/api/tts-lab/audio/{audio_id}.wav",
        "duration": round(duration, 1),
        "config": config.to_dict(),
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    return web.json_response(result)


async def handle_save_config(request: web.Request) -> web.Response:
    """
    POST /api/tts-lab/config

    Save TTS configuration for batch processing.

    Request body:
    {
        "name": "KB Questions - Sarah Voice",
        "description": "Standard configuration for Knowledge Bowl",
        "config": {
            "model": "kyutai-tts-1.6b",
            "voice": "sarah",
            "cfg_coef": 2.0,
            "n_q": 24,
            "batch_size": 8
        }
    }

    Response:
    {
        "id": "config-uuid",
        "name": "KB Questions - Sarah Voice",
        "saved_at": "2026-01-19T12:00:00Z"
    }
    """
    try:
        data = await request.json()
    except Exception:
        return web.json_response({"error": "Invalid JSON body"}, status=400)

    name = data.get("name")
    if not name or not name.strip():
        return web.json_response({"error": "Missing 'name' field"}, status=400)

    config_data = data.get("config")
    if not config_data:
        return web.json_response({"error": "Missing 'config' field"}, status=400)

    try:
        config = TTSLabConfig.from_dict(config_data)
    except (KeyError, ValueError) as e:
        return web.json_response({"error": f"Invalid config: {e}"}, status=400)

    config_id = str(uuid.uuid4())
    config_file = TTS_LAB_DIR / f"{config_id}.json"

    saved_config = {
        "id": config_id,
        "name": name,
        "description": data.get("description", ""),
        "config": config.to_dict(),
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    async with aiofiles.open(config_file, "w") as f:
        await f.write(json.dumps(saved_config, indent=2))

    logger.info(f"Saved TTS Lab config: {name} (ID: {config_id})")

    return web.json_response(
        {
            "id": config_id,
            "name": name,
            "saved_at": saved_config["created_at"],
        }
    )


async def handle_list_configs(request: web.Request) -> web.Response:
    """
    GET /api/tts-lab/configs

    List all saved TTS configurations.

    Response:
    {
        "configs": [
            {
                "id": "config-uuid",
                "name": "KB Questions - Sarah Voice",
                "description": "...",
                "config": {...},
                "created_at": "2026-01-19T12:00:00Z"
            }
        ]
    }
    """
    configs = []

    for config_file in TTS_LAB_DIR.glob("*.json"):
        try:
            async with aiofiles.open(config_file, "r") as f:
                content = await f.read()
                config_data = json.loads(content)
                configs.append(config_data)
        except Exception as e:
            logger.warning(f"Failed to load config {config_file}: {e}")

    # Sort by created_at descending
    configs.sort(key=lambda x: x.get("created_at", ""), reverse=True)

    return web.json_response({"configs": configs})


async def handle_get_config(request: web.Request) -> web.Response:
    """
    GET /api/tts-lab/config/{config_id}

    Get a specific TTS configuration.

    Response:
    {
        "id": "config-uuid",
        "name": "KB Questions - Sarah Voice",
        "description": "...",
        "config": {...},
        "created_at": "2026-01-19T12:00:00Z"
    }
    """
    config_id = request.match_info["config_id"]
    config_file = TTS_LAB_DIR / f"{config_id}.json"

    if not config_file.exists():
        return web.json_response({"error": "Configuration not found"}, status=404)

    try:
        async with aiofiles.open(config_file, "r") as f:
            content = await f.read()
            config_data = json.loads(content)
        return web.json_response(config_data)
    except Exception as e:
        logger.error(f"Failed to load config {config_id}: {e}")
        return web.json_response({"error": "Failed to load configuration"}, status=500)


async def handle_delete_config(request: web.Request) -> web.Response:
    """
    DELETE /api/tts-lab/config/{config_id}

    Delete a saved TTS configuration.

    Response:
    {
        "success": true,
        "deleted_id": "config-uuid"
    }
    """
    config_id = request.match_info["config_id"]
    config_file = TTS_LAB_DIR / f"{config_id}.json"

    if not config_file.exists():
        return web.json_response({"error": "Configuration not found"}, status=404)

    try:
        config_file.unlink()
        logger.info(f"Deleted TTS Lab config: {config_id}")
        return web.json_response({"success": True, "deleted_id": config_id})
    except Exception as e:
        logger.error(f"Failed to delete config {config_id}: {e}")
        return web.json_response({"error": "Failed to delete configuration"}, status=500)


async def handle_validate_config(request: web.Request) -> web.Response:
    """
    POST /api/tts-lab/validate

    Validate a TTS configuration without generating audio.

    Request body:
    {
        "config": {
            "model": "kyutai-tts-1.6b",
            "voice": "sarah",
            "cfg_coef": 2.0,
            "n_q": 24
        }
    }

    Response:
    {
        "valid": true,
        "errors": [],
        "warnings": ["CFG coefficient above 3.0 may reduce quality"]
    }
    """
    try:
        data = await request.json()
    except Exception:
        return web.json_response({"error": "Invalid JSON body"}, status=400)

    config_data = data.get("config")
    if not config_data:
        return web.json_response({"error": "Missing 'config' field"}, status=400)

    errors = []
    warnings = []

    # Validate model
    model = config_data.get("model")
    if not model:
        errors.append("Missing 'model' field")
    elif model not in SUPPORTED_MODELS:
        errors.append(f"Unsupported model: {model}")
    else:
        model_info = SUPPORTED_MODELS[model]

        # Validate voice
        voice = config_data.get("voice")
        if not voice:
            errors.append("Missing 'voice' field")
        elif voice not in model_info["voices"]:
            errors.append(
                f"Voice '{voice}' not available for {model_info['name']}. "
                f"Available: {', '.join(model_info['voices'])}"
            )

        # Validate config parameters
        for param, limits in model_info.get("config_params", {}).items():
            value = config_data.get(param)
            if value is not None:
                min_val = limits.get("min")
                max_val = limits.get("max")
                default_val = limits.get("default")

                if min_val is not None and value < min_val:
                    errors.append(f"{param} below minimum: {value} < {min_val}")
                if max_val is not None and value > max_val:
                    errors.append(f"{param} above maximum: {value} > {max_val}")

                # Warnings for non-default values
                if default_val is not None and abs(value - default_val) > 0.01:
                    if param == "cfg_coef" and value > 3.0:
                        warnings.append(
                            "CFG coefficient above 3.0 may reduce naturalness"
                        )
                    elif param == "n_q" and value < 16:
                        warnings.append(
                            "Low quantization levels (<16) may reduce quality"
                        )
                    elif param == "temperature" and value > 1.5:
                        warnings.append(
                            "High temperature (>1.5) may reduce consistency"
                        )

    return web.json_response(
        {
            "valid": len(errors) == 0,
            "errors": errors,
            "warnings": warnings,
        }
    )


# =============================================================================
# Route Registration
# =============================================================================


def register_tts_lab_routes(app: web.Application) -> None:
    """Register TTS Lab API routes."""
    app.router.add_get("/api/tts-lab/models", handle_list_models)
    app.router.add_post("/api/tts-lab/generate", handle_generate_test_audio)
    app.router.add_post("/api/tts-lab/config", handle_save_config)
    app.router.add_get("/api/tts-lab/configs", handle_list_configs)
    app.router.add_get("/api/tts-lab/config/{config_id}", handle_get_config)
    app.router.add_delete("/api/tts-lab/config/{config_id}", handle_delete_config)
    app.router.add_post("/api/tts-lab/validate", handle_validate_config)

    logger.info("Registered TTS Lab API routes")
