#!/usr/bin/env python3
"""
iOS Demo Video Generator
========================

100% Automated pipeline for creating iOS app demo videos.

Pipeline:
  1. CAPTURE: xcrun simctl screenshots/video from iOS Simulator
  2. NARRATION: UnaMentis TTS, macOS say, custom TTS, or pre-recorded
  3. ASSEMBLY: Shotstack API for professional video rendering

Requirements:
  - macOS with Xcode and iOS Simulator
  - Python 3.10+
  - Shotstack API key (https://shotstack.io - ~$0.40/min pay-as-you-go)
  - ffmpeg (brew install ffmpeg) - for audio conversion
  - UnaMentis management-api running (for TTS) - optional

Setup:
  export SHOTSTACK_API_KEY="your-api-key"
  export SHOTSTACK_ENV="stage"  # "stage" = watermark, "v1" = production

Usage:
  # Generate config template
  python ios_demo_video_generator.py --template > demo_config.json

  # Edit demo_config.json with your app details and scenes

  # Run full pipeline
  python ios_demo_video_generator.py --config demo_config.json

  # Capture only (no video assembly) - useful for testing
  python ios_demo_video_generator.py --config demo_config.json --capture-only

  # Assembly only (use existing captures)
  python ios_demo_video_generator.py --config demo_config.json --skip-capture

  # Load narration from markdown script
  python ios_demo_video_generator.py --config demo_config.json --script scripts/app_overview.md
"""

import os
import re
import sys
import json
import time
import shlex
import shutil
import argparse
import subprocess
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, Literal
import urllib.request
import urllib.error


# ============================================================================
# EXCEPTIONS
# ============================================================================


class DemoError(Exception):
    """Base error for demo generation."""

    pass


class TTSServerError(DemoError):
    """TTS server not available."""

    pass


class ShotstackError(DemoError):
    """Shotstack API error."""

    pass


class SimulatorError(DemoError):
    """Simulator control error."""

    pass


# ============================================================================
# CONFIGURATION DATACLASSES
# ============================================================================


@dataclass
class Scene:
    """Single scene configuration"""

    id: str  # Unique identifier
    narration: str = ""  # Text for TTS
    duration: Optional[float] = None  # Auto from audio if not set
    capture: Literal["screenshot", "video", "none"] = "screenshot"
    video_length: float = 5.0  # For video captures
    wait_before: float = 1.0  # Seconds before capture
    deep_link: Optional[str] = None  # Navigate via URL scheme
    effect: str = "zoomIn"  # zoomIn, zoomOut, slideLeft, etc.
    transition: str = "fade"  # fade, slideLeft, slideRight, etc.
    text_overlay: Optional[str] = None  # Optional text on screen


@dataclass
class Config:
    """Complete demo configuration"""

    # Metadata
    name: str = "App Demo"
    version: str = "1.0.0"

    # Simulator
    simulator_device: str = "iPhone 16 Pro"
    app_bundle_id: str = "com.unamentis.app"
    app_scheme: Optional[str] = None  # Xcode scheme (for building)
    project_path: Optional[str] = None  # .xcodeproj or .xcworkspace

    # TTS
    tts_method: Literal["unamentis", "macos", "custom", "prerecorded", "none"] = (
        "unamentis"
    )
    tts_voice: str = "nova"  # Voice ID (nova, sarah, john, etc.)
    tts_rate: int = 175  # Words per minute (175 = 1.0x speed)
    tts_provider: str = "vibevoice"  # UnaMentis TTS provider
    tts_server_url: str = "http://localhost:8766"  # UnaMentis management API
    tts_custom_cmd: Optional[str] = None  # Template: {text} {output}
    tts_prerecorded_dir: Optional[str] = None  # Dir with scene_id.mp3 files

    # Shotstack
    shotstack_resolution: str = "1080"  # preview, sd, hd, 1080, 4k
    shotstack_format: str = "mp4"  # mp4, gif, webm
    default_effect: str = "zoomIn"
    default_transition: str = "fade"
    background_color: str = "#0a0a0f"

    # Scenes
    scenes: list = field(default_factory=list)

    # Output
    output_dir: str = "./demo/output"


# ============================================================================
# SIMULATOR CONTROLLER
# ============================================================================


class Simulator:
    """iOS Simulator control via xcrun simctl"""

    def __init__(self, device_name: str):
        self.device_name = device_name
        self.udid = self._find_device()

    def _run(self, *args, check=True):
        """Run command and return result"""
        result = subprocess.run(args, capture_output=True, text=True)
        if check and result.returncode != 0:
            raise RuntimeError(f"Command failed: {' '.join(args)}\n{result.stderr}")
        return result

    def _find_device(self) -> str:
        """Find simulator UDID by name"""
        result = self._run("xcrun", "simctl", "list", "devices", "-j")
        data = json.loads(result.stdout)

        for runtime, devices in data.get("devices", {}).items():
            if "iOS" in runtime:
                for d in devices:
                    if d["name"] == self.device_name and d["isAvailable"]:
                        return d["udid"]

        raise RuntimeError(f"Simulator '{self.device_name}' not found")

    def boot(self):
        """Boot simulator if needed"""
        result = self._run("xcrun", "simctl", "list", "devices", "-j")
        data = json.loads(result.stdout)

        for runtime, devices in data.get("devices", {}).items():
            for d in devices:
                if d["udid"] == self.udid and d["state"] == "Booted":
                    print(f"  ✓ Simulator already running: {self.device_name}")
                    return

        print(f"  ⏳ Booting: {self.device_name}...")
        self._run("xcrun", "simctl", "boot", self.udid)
        self._run("open", "-a", "Simulator")
        time.sleep(3)
        print("  ✓ Booted")

    def shutdown(self):
        """Shutdown simulator"""
        self._run("xcrun", "simctl", "shutdown", self.udid, check=False)

    def launch(self, bundle_id: str):
        """Launch app"""
        self._run("xcrun", "simctl", "launch", self.udid, bundle_id)
        time.sleep(2)

    def terminate(self, bundle_id: str):
        """Terminate app"""
        self._run("xcrun", "simctl", "terminate", self.udid, bundle_id, check=False)

    def open_url(self, url: str):
        """Open URL (deep link)"""
        self._run("xcrun", "simctl", "openurl", self.udid, url)

    def screenshot(self, path: Path):
        """Capture screenshot"""
        self._run("xcrun", "simctl", "io", self.udid, "screenshot", str(path))

    def record_video(self, path: Path, duration: float):
        """Record video for duration seconds"""
        proc = subprocess.Popen(
            ["xcrun", "simctl", "io", self.udid, "recordVideo", str(path)]
        )
        time.sleep(duration)
        proc.terminate()
        proc.wait()


# ============================================================================
# TTS ENGINE
# ============================================================================


class TTS:
    """Text-to-speech generation"""

    def __init__(self, config: Config):
        self.config = config

    def generate(self, text: str, output: Path) -> float:
        """Generate audio, return duration in seconds"""
        method = self.config.tts_method

        if method == "none":
            return 0.0
        elif method == "unamentis":
            return self._unamentis_tts(text, output)
        elif method == "macos":
            return self._macos_say(text, output)
        elif method == "custom":
            return self._custom_cmd(text, output)
        elif method == "prerecorded":
            raise ValueError("Use get_prerecorded() for prerecorded audio")
        else:
            raise ValueError(f"Unknown TTS method: {method}")

    def _unamentis_tts(self, text: str, output: Path) -> float:
        """Use UnaMentis TTS server via HTTP API."""
        # Normalize speed: 175 wpm = 1.0x
        speed = self.config.tts_rate / 175.0

        payload = json.dumps(
            {
                "text": text,
                "voice_id": self.config.tts_voice,
                "tts_provider": self.config.tts_provider,
                "speed": speed,
            }
        ).encode()

        req = urllib.request.Request(
            f"{self.config.tts_server_url}/api/tts",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            wav_path = output.with_suffix(".wav")
            with urllib.request.urlopen(req, timeout=60) as resp:  # nosec B310
                with open(wav_path, "wb") as f:
                    f.write(resp.read())

            # Convert WAV to MP3 for Shotstack (smaller files)
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-i",
                    str(wav_path),
                    "-acodec",
                    "libmp3lame",
                    "-ab",
                    "192k",
                    str(output),
                ],
                check=True,
                capture_output=True,
            )
            wav_path.unlink()

            return self._get_duration(output)
        except urllib.error.URLError as e:
            raise TTSServerError(
                f"TTS server not available at {self.config.tts_server_url}: {e}"
            ) from e

    def _macos_say(self, text: str, output: Path) -> float:
        """Use macOS say command"""
        aiff = output.with_suffix(".aiff")

        subprocess.run(
            [
                "say",
                "-v",
                self.config.tts_voice,
                "-r",
                str(self.config.tts_rate),
                "-o",
                str(aiff),
                text,
            ],
            check=True,
        )

        # Convert to MP3
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(aiff),
                "-acodec",
                "libmp3lame",
                "-ab",
                "192k",
                str(output),
            ],
            check=True,
            capture_output=True,
        )
        aiff.unlink()

        return self._get_duration(output)

    def _custom_cmd(self, text: str, output: Path) -> float:
        """Use custom command"""
        cmd_template = self.config.tts_custom_cmd
        if not cmd_template:
            raise ValueError("tts_custom_cmd not set")

        # Format the command with placeholders replaced
        cmd_str = cmd_template.format(text=text, output=str(output))
        # Parse into args list to avoid shell=True security risk
        cmd_args = shlex.split(cmd_str)
        subprocess.run(cmd_args, check=True)

        return self._get_duration(output)

    def get_prerecorded(self, scene_id: str, output: Path) -> float:
        """Copy prerecorded audio file"""
        src_dir = Path(self.config.tts_prerecorded_dir)

        for ext in [".mp3", ".m4a", ".wav"]:
            src = src_dir / f"{scene_id}{ext}"
            if src.exists():
                shutil.copy(src, output)
                return self._get_duration(output)

        raise FileNotFoundError(f"No audio for scene '{scene_id}' in {src_dir}")

    def _get_duration(self, path: Path) -> float:
        """Get audio duration via ffprobe"""
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "quiet",
                "-show_entries",
                "format=duration",
                "-of",
                "csv=p=0",
                str(path),
            ],
            capture_output=True,
            text=True,
        )
        return float(result.stdout.strip() or 3.0)


# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================


def preflight_checks(
    config: Config, skip_tts: bool = False, skip_shotstack: bool = False
):
    """Verify all prerequisites before running the pipeline."""
    print("\n[PRE-FLIGHT CHECKS]")
    errors = []

    # Check TTS server (if using UnaMentis)
    if not skip_tts and config.tts_method == "unamentis":
        try:
            req = urllib.request.Request(
                f"{config.tts_server_url}/api/tts/cache/stats", method="GET"
            )
            with urllib.request.urlopen(req, timeout=5) as resp:  # nosec B310
                if resp.status == 200:
                    print(f"  ✓ TTS server: {config.tts_server_url}")
        except Exception as e:
            errors.append(f"TTS server not available at {config.tts_server_url}: {e}")
            print(f"  ✗ TTS server: {config.tts_server_url} (not responding)")

    # Check Shotstack API key
    if not skip_shotstack:
        api_key = os.environ.get("SHOTSTACK_API_KEY", "")
        env = os.environ.get("SHOTSTACK_ENV", "stage")
        if not api_key:
            errors.append("SHOTSTACK_API_KEY environment variable not set")
            print("  ✗ Shotstack: API key not set")
        else:
            try:
                req = urllib.request.Request(
                    f"https://api.shotstack.io/edit/{env}/templates",
                    headers={"x-api-key": api_key},
                    method="GET",
                )
                with urllib.request.urlopen(req, timeout=10) as resp:  # nosec B310
                    if resp.status == 200:
                        print(f"  ✓ Shotstack API: {env} environment")
            except urllib.error.HTTPError as e:
                if e.code == 401:
                    errors.append("Shotstack API key is invalid")
                    print("  ✗ Shotstack: Invalid API key")
                else:
                    errors.append(f"Shotstack API error: {e}")
                    print(f"  ✗ Shotstack: API error ({e.code})")
            except Exception as e:
                errors.append(f"Shotstack API unreachable: {e}")
                print("  ✗ Shotstack: Unreachable")

    # Check ffmpeg
    try:
        result = subprocess.run(["ffmpeg", "-version"], capture_output=True)
        if result.returncode == 0:
            print("  ✓ ffmpeg: installed")
    except FileNotFoundError:
        errors.append("ffmpeg not installed (brew install ffmpeg)")
        print("  ✗ ffmpeg: not installed")

    # Check simulator availability
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "-j"], capture_output=True, text=True
        )
        data = json.loads(result.stdout)
        found = False
        for runtime, devices in data.get("devices", {}).items():
            if "iOS" in runtime:
                for d in devices:
                    if d["name"] == config.simulator_device and d["isAvailable"]:
                        found = True
                        break
        if found:
            print(f"  ✓ Simulator: {config.simulator_device}")
        else:
            errors.append(f"Simulator '{config.simulator_device}' not found")
            print(f"  ✗ Simulator: {config.simulator_device} not found")
    except Exception as e:
        errors.append(f"Cannot check simulators: {e}")
        print(f"  ✗ Simulator: Cannot check ({e})")

    if errors:
        print("\n  ⚠️  Pre-flight checks failed:")
        for err in errors:
            print(f"     - {err}")
        raise DemoError("Pre-flight checks failed. Fix issues and retry.")

    print("  ✓ All checks passed\n")


# ============================================================================
# SHOTSTACK RENDERER
# ============================================================================


class Shotstack:
    """Shotstack API client for video assembly"""

    MAX_RETRIES = 3
    RETRY_DELAY = 5  # seconds

    def __init__(self, config: Config):
        self.config = config
        self.api_key = os.environ.get("SHOTSTACK_API_KEY", "")
        self.env = os.environ.get("SHOTSTACK_ENV", "stage")

        if not self.api_key:
            raise ShotstackError("SHOTSTACK_API_KEY environment variable required")

    def _request(
        self, method: str, endpoint: str, data: dict = None, retries: int = 0
    ) -> dict:
        """Make API request with retry logic"""
        url = f"https://api.shotstack.io/edit/{self.env}/{endpoint}"
        headers = {"x-api-key": self.api_key, "Content-Type": "application/json"}

        req = urllib.request.Request(url, method=method, headers=headers)
        if data:
            req.data = json.dumps(data).encode()

        try:
            with urllib.request.urlopen(req, timeout=60) as resp:  # nosec B310
                return json.loads(resp.read())
        except (urllib.error.URLError, urllib.error.HTTPError) as e:
            if retries < self.MAX_RETRIES:
                print(f"    ⚠️  Retry {retries + 1}/{self.MAX_RETRIES}: {e}")
                time.sleep(self.RETRY_DELAY * (retries + 1))
                return self._request(method, endpoint, data, retries + 1)
            raise ShotstackError(
                f"Shotstack API error after {self.MAX_RETRIES} retries: {e}"
            ) from e

    def upload(self, files: list[Path]) -> dict[str, str]:
        """Upload files via Ingest API, return {filename: url}"""
        urls = {}
        base = f"https://api.shotstack.io/ingest/{self.env}"

        for path in files:
            print(f"    Uploading {path.name}...")

            # Get signed upload URL
            headers = {"x-api-key": self.api_key, "Content-Type": "application/json"}
            data = json.dumps({"filename": path.name}).encode()

            req = urllib.request.Request(
                f"{base}/upload", data=data, headers=headers, method="POST"
            )
            with urllib.request.urlopen(req) as resp:  # nosec B310
                info = json.loads(resp.read())

            # Upload file
            with open(path, "rb") as f:
                upload_req = urllib.request.Request(
                    info["data"]["url"], data=f.read(), method="PUT"
                )
                upload_req.add_header("Content-Type", "application/octet-stream")
                urllib.request.urlopen(upload_req)  # nosec B310

            urls[path.name] = info["data"]["url"].split("?")[0]

        return urls

    def build_timeline(self, scenes: list[dict], urls: dict) -> dict:
        """Build Shotstack timeline JSON"""
        image_clips = []
        audio_clips = []
        t = 0.0

        for s in scenes:
            dur = s["duration"]

            # Image/video
            if s.get("capture_file") and s["capture_file"] in urls:
                image_clips.append(
                    {
                        "asset": {
                            "type": "image"
                            if s["capture"] == "screenshot"
                            else "video",
                            "src": urls[s["capture_file"]],
                        },
                        "start": t,
                        "length": dur,
                        "fit": "contain",
                        "effect": s.get("effect", self.config.default_effect),
                        "transition": {
                            "in": s.get("transition", self.config.default_transition),
                            "out": s.get("transition", self.config.default_transition),
                        },
                    }
                )

            # Audio
            if s.get("audio_file") and s["audio_file"] in urls:
                audio_clips.append(
                    {
                        "asset": {"type": "audio", "src": urls[s["audio_file"]]},
                        "start": t,
                        "length": dur,
                    }
                )

            t += dur - 0.3  # Overlap for transitions

        tracks = []
        if image_clips:
            tracks.append({"clips": image_clips})
        if audio_clips:
            tracks.append({"clips": audio_clips})

        return {
            "timeline": {"background": self.config.background_color, "tracks": tracks},
            "output": {
                "format": self.config.shotstack_format,
                "resolution": self.config.shotstack_resolution,
            },
        }

    def render(self, timeline: dict) -> str:
        """Submit render, wait for completion, return video URL"""
        print("    Submitting render...")
        resp = self._request("POST", "render", timeline)
        render_id = resp["response"]["id"]
        print(f"    Render ID: {render_id}")

        while True:
            status = self._request("GET", f"render/{render_id}")
            state = status["response"]["status"]
            print(f"    Status: {state}")

            if state == "done":
                return status["response"]["url"]
            elif state == "failed":
                raise RuntimeError(f"Render failed: {status['response'].get('error')}")

            time.sleep(5)


# ============================================================================
# SCRIPT LOADING
# ============================================================================


def load_script_from_markdown(script_path: Path) -> dict[str, str]:
    """
    Load narration text from a markdown file.

    Format:
        # Title (ignored)

        ## scene_id_1
        Narration text for scene 1.

        ## scene_id_2
        Narration text for scene 2.
        Can span multiple lines.

    Returns:
        dict mapping scene_id to narration text
    """
    content = script_path.read_text()
    narrations = {}

    # Split by ## headers
    sections = re.split(r"^## +", content, flags=re.MULTILINE)

    for section in sections[1:]:  # Skip content before first ##
        lines = section.strip().split("\n")
        if not lines:
            continue

        scene_id = lines[0].strip()
        narration = "\n".join(lines[1:]).strip()
        narrations[scene_id] = narration

    return narrations


def merge_script_into_config(config: Config, narrations: dict[str, str]) -> Config:
    """Merge narration text from script into config scenes."""
    for scene in config.scenes:
        if isinstance(scene, dict):
            scene_id = scene.get("id")
            if scene_id and scene_id in narrations:
                scene["narration"] = narrations[scene_id]
        elif hasattr(scene, "id") and scene.id in narrations:
            scene.narration = narrations[scene.id]
    return config


# ============================================================================
# MAIN GENERATOR
# ============================================================================


class Generator:
    """Main demo video generator"""

    def __init__(self, config: Config):
        self.config = config
        self.output = Path(config.output_dir)
        self.output.mkdir(parents=True, exist_ok=True)

        self.scenes_data = []
        self.capture_files = []
        self.audio_files = []

    def run(self, capture=True, assemble=True, skip_preflight=False) -> Optional[str]:
        """Run pipeline. Returns video URL if assembled."""
        print(f"\n{'=' * 60}")
        print("  iOS Demo Video Generator")
        print(f"  {self.config.name} v{self.config.version}")
        print(f"{'=' * 60}")

        # Pre-flight checks
        if not skip_preflight:
            preflight_checks(
                self.config,
                skip_tts=(not capture or self.config.tts_method == "none"),
                skip_shotstack=(not assemble),
            )

        sim = None
        try:
            if capture:
                sim = Simulator(self.config.simulator_device)
                self._capture(sim)
            else:
                self._load_existing()

            if assemble:
                return self._assemble()
        finally:
            if sim:
                sim.terminate(self.config.app_bundle_id)

        return None

    def _capture(self, sim: Simulator):
        """Capture phase"""
        print("\n[CAPTURE]")

        sim.boot()
        sim.launch(self.config.app_bundle_id)

        tts = TTS(self.config)

        for i, scene_cfg in enumerate(self.config.scenes):
            # Handle both dict and Scene objects
            if isinstance(scene_cfg, dict):
                scene = Scene(**scene_cfg)
            else:
                scene = scene_cfg

            print(f"\n  Scene {i + 1}/{len(self.config.scenes)}: {scene.id}")
            data = {"id": scene.id, "capture": scene.capture}

            # Pre-capture wait
            time.sleep(scene.wait_before)

            # Deep link navigation
            if scene.deep_link:
                sim.open_url(scene.deep_link)
                time.sleep(1)

            # Capture
            if scene.capture == "screenshot":
                path = self.output / f"{scene.id}.png"
                sim.screenshot(path)
                self.capture_files.append(path)
                data["capture_file"] = path.name
                print(f"    ✓ Screenshot: {path.name}")

            elif scene.capture == "video":
                path = self.output / f"{scene.id}.mp4"
                sim.record_video(path, scene.video_length)
                self.capture_files.append(path)
                data["capture_file"] = path.name
                print(f"    ✓ Video: {path.name}")

            # Audio
            if scene.narration and self.config.tts_method != "none":
                audio_path = self.output / f"{scene.id}_audio.mp3"

                if self.config.tts_method == "prerecorded":
                    duration = tts.get_prerecorded(scene.id, audio_path)
                else:
                    duration = tts.generate(scene.narration, audio_path)

                self.audio_files.append(audio_path)
                data["audio_file"] = audio_path.name
                data["duration"] = scene.duration or (duration + 0.5)
                print(f"    ✓ Audio: {audio_path.name} ({duration:.1f}s)")
            else:
                data["duration"] = scene.duration or 3.0

            data["effect"] = scene.effect
            data["transition"] = scene.transition
            self.scenes_data.append(data)

        # Save for resume
        with open(self.output / "scenes.json", "w") as f:
            json.dump(self.scenes_data, f, indent=2)

        print(f"\n  ✓ Captured {len(self.capture_files)} files")

    def _load_existing(self):
        """Load existing capture data"""
        print("\n[LOADING EXISTING]")

        with open(self.output / "scenes.json") as f:
            self.scenes_data = json.load(f)

        for s in self.scenes_data:
            if s.get("capture_file"):
                self.capture_files.append(self.output / s["capture_file"])
            if s.get("audio_file"):
                self.audio_files.append(self.output / s["audio_file"])

        print(f"  ✓ Loaded {len(self.scenes_data)} scenes")

    def _assemble(self) -> str:
        """Assembly phase"""
        print("\n[ASSEMBLE]")

        shotstack = Shotstack(self.config)

        # Upload
        print("  Uploading assets...")
        all_files = self.capture_files + self.audio_files
        urls = shotstack.upload(all_files)

        # Build timeline
        print("  Building timeline...")
        timeline = shotstack.build_timeline(self.scenes_data, urls)

        with open(self.output / "timeline.json", "w") as f:
            json.dump(timeline, f, indent=2)

        # Render
        print("  Rendering...")
        video_url = shotstack.render(timeline)

        # Download
        print("  Downloading...")
        final_path = self.output / f"{self.config.name.replace(' ', '_')}.mp4"
        urllib.request.urlretrieve(video_url, final_path)  # nosec B310

        print(f"\n{'=' * 60}")
        print(f"  ✓ DONE: {final_path}")
        print(f"  ✓ URL:  {video_url}")
        print(f"{'=' * 60}\n")

        return video_url


# ============================================================================
# CONFIG TEMPLATE
# ============================================================================

TEMPLATE = {
    "name": "UnaMentis App Overview",
    "version": "1.0.0",
    "simulator_device": "iPhone 16 Pro",
    "app_bundle_id": "com.unamentis.app",
    "app_scheme": "UnaMentis",
    "project_path": "/Users/ramerman/dev/unamentis/UnaMentis.xcodeproj",
    "tts_method": "unamentis",
    "tts_voice": "nova",
    "tts_rate": 175,
    "tts_provider": "vibevoice",
    "tts_server_url": "http://localhost:8766",
    "tts_custom_cmd": None,
    "tts_prerecorded_dir": None,
    "shotstack_resolution": "1080",
    "shotstack_format": "mp4",
    "default_effect": "zoomIn",
    "default_transition": "fade",
    "background_color": "#0a0a0f",
    "scenes": [
        {
            "id": "welcome",
            "narration": "Welcome to UnaMentis, your AI-powered voice learning companion.",
            "wait_before": 2.0,
            "capture": "screenshot",
            "effect": "zoomIn",
            "transition": "fade",
        },
        {
            "id": "session_tab",
            "narration": "Start a voice session with just a tap. The AI adapts to your pace and learning style.",
            "wait_before": 1.5,
            "capture": "screenshot",
            "deep_link": "unamentis://chat",
        },
        {
            "id": "learning_tab",
            "narration": "Browse structured curricula or start a freeform conversation on any topic.",
            "wait_before": 1.5,
            "capture": "screenshot",
            "deep_link": "unamentis://learning",
        },
        {
            "id": "active_session",
            "narration": "Lessons are voice-first. Speak naturally, ask questions, and learn through conversation.",
            "wait_before": 2.0,
            "capture": "video",
            "video_length": 5.0,
        },
        {
            "id": "analytics",
            "narration": "Track your progress with detailed analytics. See latency, quality, and session metrics.",
            "wait_before": 1.5,
            "capture": "screenshot",
            "deep_link": "unamentis://analytics",
        },
        {
            "id": "closing",
            "narration": "UnaMentis. Learning through conversation.",
            "wait_before": 1.0,
            "capture": "screenshot",
            "effect": "zoomOut",
        },
    ],
    "output_dir": "./demo/output/app_overview",
}


# ============================================================================
# CLI
# ============================================================================


def main():
    parser = argparse.ArgumentParser(
        description="Generate iOS app demo videos automatically",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Setup:
  1. Start UnaMentis services: /service start management-api
  2. Get Shotstack API key: https://shotstack.io (free tier available)
  3. export SHOTSTACK_API_KEY="your-key"
  4. export SHOTSTACK_ENV="stage"  # or "v1" for production (no watermark)

Quick Start:
  python ios_demo_video_generator.py --template > configs/demo.json
  # Edit configs/demo.json
  python ios_demo_video_generator.py --config configs/demo.json

With Script:
  # Edit scripts/demo.md with narration text
  python ios_demo_video_generator.py --config configs/demo.json --script scripts/demo.md

TTS Options:
  unamentis   - UnaMentis TTS server (default, requires management-api)
  macos       - Built-in macOS voices (say -v '?' to list)
  custom      - Your own TTS command with {text} and {output} placeholders
  prerecorded - Pre-recorded audio files in a directory
  none        - Video only, no narration

Shotstack Pricing (~$0.40/min, $10 minimum):
  stage env   - Free testing with watermark
  v1 env      - Production quality, no watermark
        """,
    )

    parser.add_argument("--config", "-c", help="Config JSON file")
    parser.add_argument("--script", "-s", help="Markdown script file for narration")
    parser.add_argument(
        "--template", "-t", action="store_true", help="Print template config"
    )
    parser.add_argument(
        "--capture-only", action="store_true", help="Only capture, skip assembly"
    )
    parser.add_argument(
        "--skip-capture", action="store_true", help="Use existing captures"
    )
    parser.add_argument(
        "--skip-preflight", action="store_true", help="Skip pre-flight checks"
    )

    args = parser.parse_args()

    if args.template:
        print(json.dumps(TEMPLATE, indent=2))
        return

    if not args.config:
        parser.print_help()
        print("\n⚠️  Use --config to specify config file or --template to generate one")
        sys.exit(1)

    # Load config
    with open(args.config) as f:
        data = json.load(f)
    config = Config(**{k: v for k, v in data.items() if k != "scenes"})
    config.scenes = data.get("scenes", [])

    # Load script if provided
    if args.script:
        script_path = Path(args.script)
        if not script_path.exists():
            print(f"⚠️  Script file not found: {script_path}")
            sys.exit(1)
        narrations = load_script_from_markdown(script_path)
        config = merge_script_into_config(config, narrations)
        print(f"  ✓ Loaded narration from: {script_path}")

    # Run
    try:
        gen = Generator(config)
        gen.run(
            capture=not args.skip_capture,
            assemble=not args.capture_only,
            skip_preflight=args.skip_preflight,
        )
    except DemoError as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
