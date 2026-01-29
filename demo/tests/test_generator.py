"""
Tests for iOS Demo Video Generator.

These tests verify the core functionality of the demo video generation pipeline.
Run with: pytest demo/tests/test_generator.py -v

Note: Some tests require:
- UnaMentis management-api running (for TTS tests)
- iOS Simulator installed (for simulator tests)
- SHOTSTACK_API_KEY environment variable (for Shotstack tests)
"""

import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from ios_demo_video_generator import (
    Config,
    Scene,
    TTS,
    Simulator,
    Shotstack,
    Generator,
    load_script_from_markdown,
    merge_script_into_config,
    preflight_checks,
    DemoError,
    TTSServerError,
    ShotstackError,
)


# ============================================================================
# CONFIG TESTS
# ============================================================================


class TestConfig:
    """Tests for Config dataclass."""

    def test_default_config(self):
        """Test default configuration values."""
        config = Config()
        assert config.name == "App Demo"
        assert config.simulator_device == "iPhone 16 Pro"
        assert config.tts_method == "unamentis"
        assert config.tts_voice == "nova"
        assert config.tts_provider == "vibevoice"
        assert config.shotstack_resolution == "1080"

    def test_config_with_custom_values(self):
        """Test config with custom values."""
        config = Config(name="Custom Demo", tts_method="macos", tts_voice="Samantha")
        assert config.name == "Custom Demo"
        assert config.tts_method == "macos"
        assert config.tts_voice == "Samantha"


class TestScene:
    """Tests for Scene dataclass."""

    def test_default_scene(self):
        """Test default scene values."""
        scene = Scene(id="test")
        assert scene.id == "test"
        assert scene.narration == ""
        assert scene.capture == "screenshot"
        assert scene.wait_before == 1.0
        assert scene.effect == "zoomIn"
        assert scene.transition == "fade"

    def test_scene_with_custom_values(self):
        """Test scene with custom values."""
        scene = Scene(
            id="intro",
            narration="Welcome to the app",
            capture="video",
            video_length=10.0,
        )
        assert scene.id == "intro"
        assert scene.narration == "Welcome to the app"
        assert scene.capture == "video"
        assert scene.video_length == 10.0


# ============================================================================
# SCRIPT LOADING TESTS
# ============================================================================


class TestScriptLoading:
    """Tests for markdown script loading."""

    def test_load_script_from_markdown(self):
        """Test loading narration from markdown file."""
        script_content = """# Test Script

## welcome
Welcome to the app.

## features
Here are the features.
This is a multi-line narration.

## closing
Thanks for watching.
"""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as f:
            f.write(script_content)
            script_path = Path(f.name)

        try:
            narrations = load_script_from_markdown(script_path)
            assert "welcome" in narrations
            assert narrations["welcome"] == "Welcome to the app."
            assert "features" in narrations
            assert "multi-line" in narrations["features"]
            assert "closing" in narrations
        finally:
            script_path.unlink()

    def test_merge_script_into_config(self):
        """Test merging script narrations into config."""
        config = Config()
        config.scenes = [
            {"id": "welcome", "narration": ""},
            {"id": "features", "narration": ""},
        ]
        narrations = {
            "welcome": "Hello world",
            "features": "Feature list",
        }

        merged = merge_script_into_config(config, narrations)
        assert merged.scenes[0]["narration"] == "Hello world"
        assert merged.scenes[1]["narration"] == "Feature list"


# ============================================================================
# TTS TESTS
# ============================================================================


class TestTTS:
    """Tests for TTS engine."""

    def test_tts_none_returns_zero_duration(self):
        """Test that TTS method 'none' returns 0 duration."""
        config = Config(tts_method="none")
        tts = TTS(config)
        with tempfile.NamedTemporaryFile(suffix=".mp3") as f:
            duration = tts.generate("Hello", Path(f.name))
        assert duration == 0.0

    @pytest.mark.skipif(
        os.system("curl -s http://localhost:8766/api/tts/cache/stats > /dev/null 2>&1")
        != 0,
        reason="TTS server not running",
    )
    def test_unamentis_tts_integration(self):
        """Integration test for UnaMentis TTS. Requires management-api running."""
        config = Config(
            tts_method="unamentis",
            tts_voice="nova",
            tts_provider="vibevoice",
            tts_server_url="http://localhost:8766",
        )
        tts = TTS(config)

        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
            output_path = Path(f.name)

        try:
            duration = tts.generate("Hello world, this is a test.", output_path)
            assert duration > 0
            assert output_path.exists()
            assert output_path.stat().st_size > 0
        finally:
            if output_path.exists():
                output_path.unlink()

    def test_unamentis_tts_server_unavailable(self):
        """Test that TTSServerError is raised when server is unavailable."""
        config = Config(
            tts_method="unamentis",
            tts_server_url="http://localhost:59999",  # Non-existent port
        )
        tts = TTS(config)

        with tempfile.NamedTemporaryFile(suffix=".mp3") as f:
            with pytest.raises(TTSServerError):
                tts.generate("Hello", Path(f.name))


# ============================================================================
# SIMULATOR TESTS
# ============================================================================


class TestSimulator:
    """Tests for Simulator control."""

    @pytest.mark.skipif(
        os.system("xcrun simctl list devices 2>/dev/null | grep -q 'iPhone'") != 0,
        reason="iOS Simulator not available",
    )
    def test_find_device(self):
        """Test finding simulator device by name."""
        # This test uses whatever iPhone is available
        sim = Simulator("iPhone 16 Pro")
        assert sim.udid is not None
        assert len(sim.udid) > 0

    def test_device_not_found(self):
        """Test error when device not found."""
        with pytest.raises(RuntimeError, match="not found"):
            Simulator("Nonexistent Device XYZ")


# ============================================================================
# SHOTSTACK TESTS
# ============================================================================


class TestShotstack:
    """Tests for Shotstack API client."""

    def test_missing_api_key(self):
        """Test that ShotstackError is raised when API key is missing."""
        # Temporarily remove API key
        original_key = os.environ.pop("SHOTSTACK_API_KEY", None)
        try:
            config = Config()
            with pytest.raises(ShotstackError, match="API key"):
                Shotstack(config)
        finally:
            if original_key:
                os.environ["SHOTSTACK_API_KEY"] = original_key

    def test_build_timeline(self):
        """Test building Shotstack timeline JSON."""
        config = Config()
        # Mock the API key check
        with patch.dict(os.environ, {"SHOTSTACK_API_KEY": "test-key"}):
            shotstack = Shotstack(config)

        scenes = [
            {
                "id": "intro",
                "capture": "screenshot",
                "capture_file": "intro.png",
                "audio_file": "intro_audio.mp3",
                "duration": 5.0,
                "effect": "zoomIn",
                "transition": "fade",
            }
        ]
        urls = {
            "intro.png": "https://example.com/intro.png",
            "intro_audio.mp3": "https://example.com/intro_audio.mp3",
        }

        timeline = shotstack.build_timeline(scenes, urls)

        assert "timeline" in timeline
        assert "output" in timeline
        assert timeline["output"]["format"] == "mp4"
        assert timeline["output"]["resolution"] == "1080"
        assert len(timeline["timeline"]["tracks"]) == 2  # Image and audio tracks


# ============================================================================
# PREFLIGHT TESTS
# ============================================================================


class TestPreflight:
    """Tests for pre-flight checks."""

    def test_preflight_with_invalid_tts_server(self):
        """Test that preflight fails with invalid TTS server."""
        config = Config(tts_method="unamentis", tts_server_url="http://localhost:59999")

        with pytest.raises(DemoError, match="Pre-flight checks failed"):
            preflight_checks(config, skip_tts=False, skip_shotstack=True)

    def test_preflight_skips_tts_when_requested(self):
        """Test that TTS check is skipped when requested."""
        config = Config(tts_method="unamentis", tts_server_url="http://localhost:59999")

        # Should not raise because TTS check is skipped
        # But will still fail on Shotstack if key not set
        with patch.dict(os.environ, {"SHOTSTACK_API_KEY": "test"}):
            # This may fail on simulator check, but not TTS
            try:
                preflight_checks(config, skip_tts=True, skip_shotstack=True)
            except DemoError as e:
                # If it fails, make sure it's not about TTS
                assert "TTS" not in str(e)


# ============================================================================
# GENERATOR TESTS
# ============================================================================


class TestGenerator:
    """Tests for main Generator class."""

    def test_generator_creates_output_directory(self):
        """Test that generator creates output directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / "test_output"
            config = Config(output_dir=str(output_dir))

            Generator(config)  # Constructor creates the output directory
            assert output_dir.exists()

    def test_generator_loads_existing_scenes(self):
        """Test loading existing scene data."""
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            config = Config(output_dir=str(output_dir))

            # Create scenes.json
            scenes_data = [{"id": "test", "capture": "screenshot", "duration": 3.0}]
            with open(output_dir / "scenes.json", "w") as f:
                json.dump(scenes_data, f)

            gen = Generator(config)
            gen._load_existing()

            assert len(gen.scenes_data) == 1
            assert gen.scenes_data[0]["id"] == "test"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
