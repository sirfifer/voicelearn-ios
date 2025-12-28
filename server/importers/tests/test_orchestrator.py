"""
Unit tests for the import orchestrator.

Tests the full import pipeline including:
- Job creation and tracking
- Stage progression
- UMLCF generation
- File storage
"""

import asyncio
import json
import shutil
import tempfile
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from importers.core.orchestrator import ImportOrchestrator
from importers.core.models import ImportConfig, ImportStatus
from importers.core.registry import SourceRegistry
from importers.core.discovery import get_plugin_discovery, reset_plugin_discovery, PluginState


class MockHandler:
    """Mock curriculum source handler for testing."""

    @property
    def source_id(self):
        return "mock_source"

    @property
    def source_info(self):
        from importers.core.models import CurriculumSource
        return CurriculumSource(
            id="mock_source",
            name="Mock Source",
            description="Mock source for testing",
            logo_url="/test.png",
            license=self.default_license,
            course_count="100",
            features=["video", "transcript"],
            status="active",
            base_url="https://example.com",
        )

    @property
    def default_license(self):
        from importers.core.models import LicenseInfo
        return LicenseInfo(
            type="CC-BY-4.0",
            name="Creative Commons Attribution 4.0",
            url="https://creativecommons.org/licenses/by/4.0/",
            permissions=["share", "adapt"],
            conditions=["attribution"],
            attribution_required=True,
            attribution_format="Test attribution",
            holder_name="Test Holder",
            holder_url="https://example.com",
            restrictions=[],
        )

    def validate_license(self, course_id):
        from importers.core.base import LicenseValidationResult
        return LicenseValidationResult(
            can_import=True,
            license=self.default_license,
            warnings=[],
            attribution_text="Test attribution text",
        )

    async def download_course(self, course_id, output_dir, progress_callback=None, selected_lectures=None):
        """Simulate course download."""
        output_dir = Path(output_dir)
        course_dir = output_dir / course_id
        course_dir.mkdir(parents=True, exist_ok=True)

        # Create mock metadata with detailed lecture info
        metadata = {
            "source": "mock_source",
            "course_id": course_id,
            "title": "Test Course",
            "description": "A test course for unit testing",
            "instructors": ["Test Instructor"],
            "department": "Testing",
            "level": "intermediate",
            "content": {
                "lectures": [
                    {"id": "lecture-1", "number": 1, "title": "Introduction to Testing", "has_video": True, "has_transcript": True},
                    {"id": "lecture-2", "number": 2, "title": "Unit Test Fundamentals", "has_video": True, "has_transcript": True},
                    {"id": "lecture-3", "number": 3, "title": "Advanced Testing Patterns", "has_video": False, "has_transcript": True},
                ],
                "assignments": [
                    {"file": "assignment1.pdf", "name": "Problem Set 1"},
                ],
                "exams": [
                    {"file": "midterm.pdf", "name": "Midterm Exam"},
                ],
                "resources": [],
            },
        }

        metadata_path = course_dir / "course_metadata.json"
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2)

        if progress_callback:
            progress_callback(100, "Download complete")

        return course_dir

    async def validate_content(self, content_path):
        from importers.core.base import ValidationResult
        return ValidationResult(is_valid=True, errors=[], warnings=[], metadata={})


def run_async(coro):
    """Helper to run async code in tests."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


class TestImportOrchestrator(unittest.TestCase):
    """Test cases for ImportOrchestrator."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.output_dir = Path(self.temp_dir) / "output"
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Create curriculum directory structure
        self.curriculum_dir = Path(self.temp_dir) / "curriculum" / "examples" / "realistic"
        self.curriculum_dir.mkdir(parents=True, exist_ok=True)

        self.orchestrator = ImportOrchestrator(
            output_dir=self.output_dir,
            enrichment_enabled=False,  # Disable enrichment for faster tests
        )

        # Reset and set up discovery with mock handler
        reset_plugin_discovery()
        SourceRegistry.clear()

        # Register mock handler directly in the registry instances
        self.mock_handler = MockHandler()
        SourceRegistry._instances["mock_source"] = self.mock_handler

        # Also register the mock in the discovery system
        discovery = get_plugin_discovery()
        discovery._loaded_classes["mock_source"] = type(self.mock_handler)
        discovery._states["mock_source"] = PluginState(enabled=True)

        # Mark as initialized to prevent re-discovery overwriting our mock
        SourceRegistry._discovery_initialized = True

    def tearDown(self):
        """Clean up test fixtures."""
        shutil.rmtree(self.temp_dir, ignore_errors=True)
        SourceRegistry.clear()
        reset_plugin_discovery()

    def wait_for_job(self, job_id, timeout_seconds=5):
        """Wait for a job to complete."""
        async def _wait():
            for _ in range(timeout_seconds * 10):
                await asyncio.sleep(0.1)
                progress = self.orchestrator.get_progress(job_id)
                if progress.status in [ImportStatus.COMPLETE, ImportStatus.FAILED, ImportStatus.CANCELLED]:
                    return progress
            return self.orchestrator.get_progress(job_id)
        return run_async(_wait())

    def test_orchestrator_initialization(self):
        """Test orchestrator initializes correctly."""
        self.assertTrue(self.output_dir.exists())
        self.assertEqual(len(self.orchestrator._jobs), 0)

    def test_start_import_creates_job(self):
        """Test that starting an import creates a job."""
        config = ImportConfig(
            source_id="mock_source",
            course_id="test-course-123",
            output_name="test-course-123",
        )

        job_id = run_async(self.orchestrator.start_import(config))

        self.assertIsNotNone(job_id)
        self.assertIn(job_id, self.orchestrator._jobs)

        progress = self.orchestrator.get_progress(job_id)
        self.assertIsNotNone(progress)
        self.assertEqual(progress.config.course_id, "test-course-123")

    def test_import_pipeline_completes(self):
        """Test that the import pipeline runs to completion."""
        config = ImportConfig(
            source_id="mock_source",
            course_id="test-course-456",
            output_name="test-course-456",
        )

        job_id = run_async(self.orchestrator.start_import(config))
        progress = self.wait_for_job(job_id)

        self.assertEqual(progress.status, ImportStatus.COMPLETE, f"Import failed: {progress.error}")
        self.assertEqual(progress.overall_progress, 100.0)
        self.assertIsNotNone(progress.result)

    def test_import_generates_valid_umlcf(self):
        """Test that import generates a valid UMLCF file."""
        config = ImportConfig(
            source_id="mock_source",
            course_id="test-course-789",
            output_name="test-course-789",
        )

        job_id = run_async(self.orchestrator.start_import(config))
        progress = self.wait_for_job(job_id)

        self.assertEqual(progress.status, ImportStatus.COMPLETE)

        # Check UMLCF file was created
        umlcf_path = self.output_dir / "curricula" / "test-course-789.umlcf"
        self.assertTrue(umlcf_path.exists(), f"UMLCF file not found at {umlcf_path}")

        # Validate UMLCF structure
        with open(umlcf_path) as f:
            umlcf = json.load(f)

        self.assertEqual(umlcf["umlcf"], "1.0.0")
        self.assertEqual(umlcf["id"]["value"], "test-course-789")
        self.assertEqual(umlcf["title"], "Test Course")
        self.assertIn("content", umlcf)
        self.assertIn("glossary", umlcf)
        self.assertIsInstance(umlcf["glossary"], dict)
        self.assertIn("terms", umlcf["glossary"])

    def test_import_extracts_lectures(self):
        """Test that import correctly extracts lecture content."""
        config = ImportConfig(
            source_id="mock_source",
            course_id="test-course-lectures",
            output_name="test-course-lectures",
        )

        job_id = run_async(self.orchestrator.start_import(config))
        progress = self.wait_for_job(job_id)

        self.assertEqual(progress.status, ImportStatus.COMPLETE)

        # Check UMLCF content
        umlcf_path = self.output_dir / "curricula" / "test-course-lectures.umlcf"
        with open(umlcf_path) as f:
            umlcf = json.load(f)

        content = umlcf["content"]
        self.assertGreater(len(content), 0)

        # Find lectures module
        lectures_module = None
        for module in content:
            if module["id"]["value"] == "lectures":
                lectures_module = module
                break

        self.assertIsNotNone(lectures_module, "Lectures module not found")
        self.assertEqual(len(lectures_module["children"]), 3)

        # Check first lecture has correct title
        first_lecture = lectures_module["children"][0]
        self.assertEqual(first_lecture["id"]["value"], "lecture-1")
        self.assertEqual(first_lecture["title"], "Introduction to Testing")
        self.assertTrue(first_lecture["content"]["hasVideo"])
        self.assertTrue(first_lecture["content"]["hasTranscript"])

    def test_import_extracts_assessments(self):
        """Test that import correctly extracts assignments and exams."""
        config = ImportConfig(
            source_id="mock_source",
            course_id="test-course-assessments",
            output_name="test-course-assessments",
        )

        job_id = run_async(self.orchestrator.start_import(config))
        progress = self.wait_for_job(job_id)

        self.assertEqual(progress.status, ImportStatus.COMPLETE)
        self.assertEqual(progress.result.assessment_count, 2)  # 1 assignment + 1 exam

    def test_list_jobs(self):
        """Test listing import jobs."""
        config = ImportConfig(
            source_id="mock_source",
            course_id="test-list-job",
            output_name="test-list-job",
        )
        job_id = run_async(self.orchestrator.start_import(config))

        jobs = self.orchestrator.list_jobs()
        self.assertGreater(len(jobs), 0)

        job_ids = [j.id for j in jobs]
        self.assertIn(job_id, job_ids)

    def test_progress_callback(self):
        """Test that progress callbacks are called."""
        progress_updates = []

        def on_progress(progress):
            progress_updates.append({
                "status": progress.status.value,
                "progress": progress.overall_progress,
            })

        self.orchestrator.add_progress_callback(on_progress)

        config = ImportConfig(
            source_id="mock_source",
            course_id="test-callback-job",
            output_name="test-callback-job",
        )

        job_id = run_async(self.orchestrator.start_import(config))
        self.wait_for_job(job_id)

        self.assertGreater(len(progress_updates), 0)
        # Check that final progress is 100
        final_update = progress_updates[-1]
        self.assertEqual(final_update["progress"], 100.0)

    def test_import_result_contains_correct_counts(self):
        """Test that import result has correct topic and assessment counts."""
        config = ImportConfig(
            source_id="mock_source",
            course_id="test-counts",
            output_name="test-counts",
        )

        job_id = run_async(self.orchestrator.start_import(config))
        progress = self.wait_for_job(job_id)

        self.assertEqual(progress.status, ImportStatus.COMPLETE)
        self.assertEqual(progress.result.topic_count, 3)  # 3 lectures
        self.assertEqual(progress.result.assessment_count, 2)  # 1 assignment + 1 exam
        self.assertEqual(progress.result.title, "Test Course")


class TestImportConfig(unittest.TestCase):
    """Test cases for ImportConfig."""

    def test_from_dict(self):
        """Test creating ImportConfig from dict."""
        data = {
            "sourceId": "mit_ocw",
            "courseId": "6-001-spring-2005",
            "outputName": "sicp-6001",
            "selectedLectures": ["lecture-1", "lecture-2"],
            "includeTranscripts": True,
            "includeVideos": False,
        }

        config = ImportConfig.from_dict(data)

        self.assertEqual(config.source_id, "mit_ocw")
        self.assertEqual(config.course_id, "6-001-spring-2005")
        self.assertEqual(config.output_name, "sicp-6001")
        self.assertEqual(config.selected_lectures, ["lecture-1", "lecture-2"])
        self.assertTrue(config.include_transcripts)
        self.assertFalse(config.include_videos)

    def test_to_dict(self):
        """Test converting ImportConfig to dict."""
        config = ImportConfig(
            source_id="mit_ocw",
            course_id="test-course",
            output_name="test-output",
        )

        data = config.to_dict()

        self.assertEqual(data["sourceId"], "mit_ocw")
        self.assertEqual(data["courseId"], "test-course")
        self.assertEqual(data["outputName"], "test-output")

    def test_default_values(self):
        """Test ImportConfig default values."""
        config = ImportConfig(
            source_id="test",
            course_id="test",
            output_name="test",
        )

        self.assertEqual(config.selected_lectures, [])
        self.assertTrue(config.include_transcripts)
        self.assertTrue(config.include_lecture_notes)
        self.assertTrue(config.include_assignments)
        self.assertTrue(config.include_exams)
        self.assertFalse(config.include_videos)
        self.assertTrue(config.generate_objectives)


if __name__ == "__main__":
    unittest.main()
