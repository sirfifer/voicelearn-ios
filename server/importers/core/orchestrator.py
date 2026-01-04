"""
Import orchestrator - coordinates the full import pipeline.

Pipeline stages:
1. Download - Fetch content from source
2. Validate - Check license and structure
3. Extract - Parse content into intermediate format
4. Enrich - Run AI enrichment pipeline
5. Generate - Create UMCF output
6. Store - Save to curriculum storage
"""

import asyncio
import json
import logging
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

from .base import CurriculumSourceHandler, LicenseRestrictionError
from .models import (
    ImportConfig,
    ImportLogEntry,
    ImportProgress,
    ImportResult,
    ImportStage,
    ImportStatus,
    LicenseInfo,
)
from .registry import SourceRegistry

logger = logging.getLogger(__name__)


class ImportOrchestrator:
    """
    Orchestrates the full curriculum import pipeline.

    Manages:
    - Import job queue
    - Progress tracking
    - Pipeline stage execution
    - Error handling and recovery
    """

    def __init__(
        self,
        output_dir: Path,
        enrichment_enabled: bool = True,
    ):
        """
        Initialize the orchestrator.

        Args:
            output_dir: Directory for import outputs
            enrichment_enabled: Whether to run AI enrichment
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.enrichment_enabled = enrichment_enabled

        # Active jobs
        self._jobs: Dict[str, ImportProgress] = {}
        self._tasks: Dict[str, asyncio.Task] = {}

        # Callbacks for progress updates
        self._progress_callbacks: List[Callable[[ImportProgress], None]] = []

    # =========================================================================
    # Job Management
    # =========================================================================

    async def start_import(self, config: ImportConfig) -> str:
        """
        Start a new import job.

        Args:
            config: Import configuration

        Returns:
            Job ID for tracking progress
        """
        # Generate job ID
        job_id = str(uuid.uuid4())

        # Create progress tracker
        progress = ImportProgress(
            id=job_id,
            config=config,
            status=ImportStatus.QUEUED,
            stages=self._create_stages(config),
        )
        progress.add_log("info", f"Import job created for {config.source_id}/{config.course_id}")

        self._jobs[job_id] = progress

        # Start import task
        task = asyncio.create_task(self._run_import(progress))
        self._tasks[job_id] = task

        logger.info(f"Started import job {job_id} for {config.course_id}")
        return job_id

    def get_progress(self, job_id: str) -> Optional[ImportProgress]:
        """Get current progress for a job."""
        return self._jobs.get(job_id)

    def list_jobs(self, status: Optional[ImportStatus] = None) -> List[ImportProgress]:
        """List all jobs, optionally filtered by status."""
        jobs = list(self._jobs.values())
        if status:
            jobs = [j for j in jobs if j.status == status]
        return sorted(jobs, key=lambda j: j.created_at, reverse=True)

    async def cancel_import(self, job_id: str) -> bool:
        """
        Cancel an import job.

        Args:
            job_id: Job to cancel

        Returns:
            True if cancelled successfully
        """
        progress = self._jobs.get(job_id)
        if not progress:
            return False

        # Only cancel if not already complete/failed
        if progress.status in [ImportStatus.COMPLETE, ImportStatus.FAILED, ImportStatus.CANCELLED]:
            return False

        # Cancel the task
        task = self._tasks.get(job_id)
        if task and not task.done():
            task.cancel()

        progress.status = ImportStatus.CANCELLED
        progress.add_log("info", "Import cancelled by user")
        self._notify_progress(progress)

        logger.info(f"Cancelled import job {job_id}")
        return True

    def add_progress_callback(self, callback: Callable[[ImportProgress], None]):
        """Add a callback for progress updates."""
        self._progress_callbacks.append(callback)

    def _notify_progress(self, progress: ImportProgress):
        """Notify all callbacks of progress update."""
        for callback in self._progress_callbacks:
            try:
                callback(progress)
            except Exception as e:
                logger.error(f"Progress callback error: {e}")

    # =========================================================================
    # Pipeline Execution
    # =========================================================================

    async def _run_import(self, progress: ImportProgress):
        """Run the full import pipeline."""
        config = progress.config

        try:
            # Get source handler
            handler = SourceRegistry.get_handler(config.source_id)
            if not handler:
                raise ValueError(f"Unknown source: {config.source_id}")

            # Stage 1: Download
            await self._run_download_stage(progress, handler)

            # Stage 2: Validate
            await self._run_validate_stage(progress, handler)

            # Stage 3: Extract
            await self._run_extract_stage(progress)

            # Stage 4: Enrich (if enabled)
            if self.enrichment_enabled:
                await self._run_enrich_stage(progress, config)

            # Stage 5: Generate UMCF
            await self._run_generate_stage(progress)

            # Stage 6: Store
            output_path = await self._run_store_stage(progress)

            # Complete
            progress.status = ImportStatus.COMPLETE
            progress.overall_progress = 100.0
            progress.add_log("info", "Import completed successfully")

            # Get counts from extracted content
            extracted_content = getattr(progress, "_extracted_content", {})
            topic_count = len(extracted_content.get("lectures", []))
            assessment_count = (
                len(extracted_content.get("assignments", []))
                + len(extracted_content.get("exams", []))
            )
            course_title = getattr(progress, "_course_title", config.output_name)

            # Create result
            progress.result = ImportResult(
                curriculum_id=config.output_name,
                title=course_title,
                topic_count=topic_count,
                assessment_count=assessment_count,
                output_path=str(output_path),
                output_size=self._get_file_size(output_path),
                license=handler.default_license,
            )

            logger.info(f"Import job {progress.id} completed: {output_path}")

        except asyncio.CancelledError:
            progress.status = ImportStatus.CANCELLED
            progress.add_log("info", "Import was cancelled")
            raise

        except LicenseRestrictionError as e:
            progress.status = ImportStatus.FAILED
            progress.error = f"License restriction: {str(e)}"
            progress.add_log("error", progress.error)
            logger.error(f"Import job {progress.id} failed (license): {e}")

        except Exception as e:
            progress.status = ImportStatus.FAILED
            progress.error = str(e)
            progress.add_log("error", f"Import failed: {e}")
            logger.exception(f"Import job {progress.id} failed: {e}")

        finally:
            self._notify_progress(progress)

    # =========================================================================
    # Individual Stages
    # =========================================================================

    async def _run_download_stage(
        self,
        progress: ImportProgress,
        handler: CurriculumSourceHandler,
    ):
        """Download content from source."""
        progress.status = ImportStatus.DOWNLOADING
        progress.current_stage = "download"
        progress.current_activity = "Downloading course content..."
        progress.update_stage("download", "running")
        self._notify_progress(progress)

        config = progress.config

        def update_download_progress(pct: float, msg: str):
            progress.update_stage("download", "running", pct, msg)
            progress.overall_progress = pct * 0.2  # Download is 20% of total
            self._notify_progress(progress)

        # Download content
        download_dir = self.output_dir / "downloads" / config.course_id
        content_path = await handler.download_course(
            config.course_id,
            download_dir,
            progress_callback=update_download_progress,
        )

        progress.update_stage("download", "complete", 100, f"Downloaded to {content_path}")
        progress.add_log("info", f"Downloaded content to {content_path}")
        progress.overall_progress = 20.0
        self._notify_progress(progress)

        # Store path for later stages
        progress._content_path = content_path

    async def _run_validate_stage(
        self,
        progress: ImportProgress,
        handler: CurriculumSourceHandler,
    ):
        """Validate downloaded content and license."""
        progress.status = ImportStatus.VALIDATING
        progress.current_stage = "validate"
        progress.current_activity = "Validating content and license..."
        progress.update_stage("validate", "running")
        self._notify_progress(progress)

        config = progress.config

        # Validate license
        license_result = handler.validate_license(config.course_id)
        if not license_result.can_import:
            raise LicenseRestrictionError(license_result.warnings[0])

        progress.add_log("info", f"License validated: {license_result.license.type}")

        # Validate content
        content_path = getattr(progress, "_content_path", None)
        if content_path:
            validation = await handler.validate_content(content_path)
            if not validation.is_valid:
                raise ValueError(f"Content validation failed: {validation.errors}")

            if validation.warnings:
                for warning in validation.warnings:
                    progress.add_log("warning", warning)

        progress.update_stage("validate", "complete", 100, f"License: {license_result.license.type}")
        progress.overall_progress = 30.0
        self._notify_progress(progress)

        # Store license for later
        progress._license = license_result.license
        progress._attribution = license_result.attribution_text

    async def _run_extract_stage(self, progress: ImportProgress):
        """Extract content from downloaded files."""
        progress.status = ImportStatus.EXTRACTING
        progress.current_stage = "extract"
        progress.current_activity = "Extracting content..."
        progress.update_stage("extract", "running")
        self._notify_progress(progress)

        # Load course_metadata.json from download directory
        content_path = getattr(progress, "_content_path", None)
        extracted_content = None

        if content_path:
            metadata_file = Path(content_path) / "course_metadata.json"
            if metadata_file.exists():
                try:
                    with open(metadata_file, "r") as f:
                        metadata = json.load(f)
                        extracted_content = metadata.get("content", {})
                        # Also capture course metadata for UMCF generation
                        progress._course_title = metadata.get("title", progress.config.output_name)
                        progress._course_description = metadata.get("description", "")
                        progress._instructors = metadata.get("instructors", [])
                        progress._department = metadata.get("department", "")
                        progress._level = metadata.get("level", "intermediate")
                        progress._keywords = metadata.get("keywords", [])

                        # Log what was extracted
                        lectures = extracted_content.get("lectures", [])
                        assignments = extracted_content.get("assignments", [])
                        exams = extracted_content.get("exams", [])
                        resources = extracted_content.get("resources", [])

                        progress.add_log(
                            "info",
                            f"Extracted: {len(lectures)} lectures, "
                            f"{len(assignments)} assignments, "
                            f"{len(exams)} exams, "
                            f"{len(resources)} resources"
                        )
                except Exception as e:
                    progress.add_log("warning", f"Failed to parse course metadata: {e}")

        # Store extracted content for generate stage
        progress._extracted_content = extracted_content or {
            "lectures": [],
            "assignments": [],
            "exams": [],
            "resources": [],
        }

        progress.update_stage("extract", "complete", 100, "Content extracted")
        progress.add_log("info", "Content extraction complete")
        progress.overall_progress = 50.0
        self._notify_progress(progress)

    async def _run_enrich_stage(self, progress: ImportProgress, config: ImportConfig):
        """Run AI enrichment pipeline."""
        progress.status = ImportStatus.ENRICHING
        progress.current_stage = "enrich"
        progress.current_activity = "Running AI enrichment..."
        progress.update_stage("enrich", "running")
        self._notify_progress(progress)

        # Enrichment substages (now including image acquisition and media generation)
        enrichment_stages = [
            ("enrich_analysis", "Content Analysis", config.generate_objectives),
            ("enrich_structure", "Structure Inference", True),
            ("enrich_segment", "Content Segmentation", config.create_checkpoints),
            ("enrich_objectives", "Learning Objectives", config.generate_objectives),
            ("enrich_assessments", "Assessment Enhancement", True),
            ("enrich_images", "Image Acquisition", True),
            ("enrich_media", "Media Generation", config.generate_media),  # Maps, diagrams, formulas
            ("enrich_tutoring", "Tutoring Enhancement", config.generate_spoken_text),
            ("enrich_kg", "Knowledge Graph", config.build_knowledge_graph),
        ]

        base_progress = 50.0
        progress_per_stage = 30.0 / len(enrichment_stages)

        for i, (stage_id, stage_name, enabled) in enumerate(enrichment_stages):
            if not enabled:
                progress.update_stage(stage_id, "skipped")
                progress.add_log("info", f"Skipped: {stage_name}")
                continue

            progress.current_activity = f"Running {stage_name}..."
            progress.update_stage(stage_id, "running")
            self._notify_progress(progress)

            # Run specific enrichment stages
            if stage_id == "enrich_images":
                await self._run_image_acquisition(progress, config)
            elif stage_id == "enrich_media":
                await self._run_media_generation(progress, config)
            else:
                # Simulate other enrichment stages (in production, call actual enrichment pipeline)
                await asyncio.sleep(0.5)

            progress.update_stage(stage_id, "complete", 100, f"{stage_name} complete")
            progress.add_log("info", f"Completed: {stage_name}")
            progress.overall_progress = base_progress + (i + 1) * progress_per_stage
            self._notify_progress(progress)

        progress.update_stage("enrich", "complete", 100, "Enrichment complete")
        progress.overall_progress = 80.0
        self._notify_progress(progress)

    async def _run_image_acquisition(self, progress: ImportProgress, config: ImportConfig):  # noqa: ARG002
        """Acquire and validate images for the curriculum."""
        try:
            from ..enrichment.image_acquisition import (
                ImageAcquisitionService,
                ImageAssetInfo,
                ImageSourceType,
            )

            extracted_content = getattr(progress, "_extracted_content", {})
            content_path = getattr(progress, "_content_path", None)

            if not content_path:
                progress.add_log("warning", "No content path for image acquisition")
                return

            output_dir = Path(content_path)
            service = ImageAcquisitionService(cache_dir=output_dir / "images")

            try:
                # Collect image assets from extracted content
                # Look for media collections in the content structure
                assets = []
                lectures = extracted_content.get("lectures", [])

                for lecture in lectures:
                    media = lecture.get("media", {})
                    for embedded in media.get("embedded", []):
                        if embedded.get("type") in ("image", "diagram", "chart", "slideImage"):
                            assets.append(ImageAssetInfo(
                                id=embedded.get("id", f"img-{len(assets)}"),
                                url=embedded.get("url"),
                                local_path=embedded.get("localPath"),
                                title=embedded.get("title"),
                                alt=embedded.get("alt"),
                                caption=embedded.get("caption"),
                                audio_description=embedded.get("audioDescription"),
                                asset_type=embedded.get("type", "image"),
                                width=embedded.get("dimensions", {}).get("width", 0),
                                height=embedded.get("dimensions", {}).get("height", 0),
                            ))

                if not assets:
                    progress.add_log("info", "No image assets to acquire")
                    return

                # Acquire images
                results = {}
                acquired = 0
                failed = 0
                replaced = 0

                for asset in assets:
                    result = await service.acquire_image(asset)
                    results[asset.id] = result

                    if result.success:
                        acquired += 1
                        if result.source_type == ImageSourceType.WIKIMEDIA_SEARCH:
                            replaced += 1
                            progress.add_log(
                                "info",
                                f"Found replacement for {asset.id} on Wikimedia"
                            )
                        elif result.source_type == ImageSourceType.GENERATED:
                            replaced += 1
                            progress.add_log(
                                "info",
                                f"Generated placeholder for {asset.id}"
                            )
                    else:
                        failed += 1
                        progress.add_log(
                            "warning",
                            f"Failed to acquire {asset.id}: {result.error}"
                        )

                # Store results for generate stage
                progress._acquired_images = results

                # Save acquired images
                images_dir = output_dir / "images"
                images_dir.mkdir(parents=True, exist_ok=True)

                asset_data = {}
                for asset_id, result in results.items():
                    if result.success and result.data:
                        ext_map = {
                            "image/jpeg": ".jpg",
                            "image/png": ".png",
                            "image/gif": ".gif",
                            "image/webp": ".webp",
                            "image/svg+xml": ".svg",
                        }
                        ext = ext_map.get(result.mime_type, ".jpg")

                        file_path = images_dir / f"{asset_id}{ext}"
                        file_path.write_bytes(result.data)

                        import base64
                        asset_data[asset_id] = {
                            "data": base64.b64encode(result.data).decode('utf-8'),
                            "mimeType": result.mime_type,
                            "size": len(result.data),
                            "source": result.source_type.value,
                            "newUrl": result.new_url,
                            "attribution": result.attribution,
                        }

                # Store for later bundling with UMCF
                progress._asset_data = asset_data

                progress.add_log(
                    "info",
                    f"Image acquisition: {acquired} acquired, {replaced} replaced, {failed} failed"
                )

            finally:
                await service.close()

        except ImportError as e:
            progress.add_log("warning", f"Image acquisition not available: {e}")
        except Exception as e:
            progress.add_log("error", f"Image acquisition failed: {e}")

    async def _run_media_generation(self, progress: ImportProgress, config: ImportConfig):  # noqa: ARG002
        """Generate maps, diagrams, and formula fallbacks for the curriculum."""
        try:
            from ..enrichment.media_generation import (
                MediaGenerationConfig,
                MediaGenerationService,
            )

            extracted_content = getattr(progress, "_extracted_content", {})
            content_path = getattr(progress, "_content_path", None)

            if not content_path:
                progress.add_log("warning", "No content path for media generation")
                return

            output_dir = Path(content_path) / "generated_media"
            media_config = MediaGenerationConfig(
                generate_maps=True,
                generate_diagrams=True,
                generate_formula_fallbacks=True,
                output_format="png",
                cache_enabled=True,
            )

            service = MediaGenerationService(output_dir, media_config)

            try:
                # Build content nodes from extracted content
                content_nodes = []

                # Add lectures as content nodes
                for lecture in extracted_content.get("lectures", []):
                    content_nodes.append(lecture)

                # Add any top-level generative media
                if "generativeMedia" in extracted_content:
                    content_nodes.append({
                        "generativeMedia": extracted_content["generativeMedia"]
                    })

                if not content_nodes:
                    progress.add_log("info", "No content nodes for media generation")
                    return

                # Process all media
                def update_progress(media_type: str, pct: float):
                    progress.add_log(
                        "debug",
                        f"Media generation progress: {media_type} {pct:.0f}%"
                    )

                results, stats = await service.process_curriculum_media(
                    content_nodes,
                    progress_callback=update_progress,
                )

                # Store results for generate stage
                progress._generated_media = results

                # Log statistics
                if stats.maps_processed > 0:
                    progress.add_log(
                        "info",
                        f"Maps: {stats.maps_succeeded}/{stats.maps_processed} succeeded"
                    )
                if stats.diagrams_processed > 0:
                    progress.add_log(
                        "info",
                        f"Diagrams: {stats.diagrams_succeeded}/{stats.diagrams_processed} succeeded"
                    )
                if stats.formulas_processed > 0:
                    progress.add_log(
                        "info",
                        f"Formulas: {stats.formulas_valid}/{stats.formulas_processed} valid, "
                        f"{stats.formulas_fallbacks_generated} fallbacks generated"
                    )

                total_processed = (
                    stats.maps_processed + stats.diagrams_processed + stats.formulas_processed
                )
                total_succeeded = (
                    stats.maps_succeeded + stats.diagrams_succeeded + stats.formulas_valid
                )

                if total_processed == 0:
                    progress.add_log("info", "No generative media to process")
                else:
                    progress.add_log(
                        "info",
                        f"Media generation: {total_succeeded}/{total_processed} items succeeded"
                    )

            finally:
                await service.close()

        except ImportError as e:
            progress.add_log("warning", f"Media generation not available: {e}")
        except Exception as e:
            progress.add_log("error", f"Media generation failed: {e}")

    async def _run_generate_stage(self, progress: ImportProgress):
        """Generate UMCF output."""
        progress.status = ImportStatus.GENERATING
        progress.current_stage = "generate"
        progress.current_activity = "Generating UMCF document..."
        progress.update_stage("generate", "running")
        self._notify_progress(progress)

        config = progress.config
        license_info = getattr(progress, "_license", None)
        attribution = getattr(progress, "_attribution", "")
        extracted_content = getattr(progress, "_extracted_content", {})

        # Get course metadata from extract stage
        course_title = getattr(progress, "_course_title", config.output_name)
        course_description = getattr(progress, "_course_description", f"Imported from {config.source_id}")
        instructors = getattr(progress, "_instructors", [])
        department = getattr(progress, "_department", "")
        level = getattr(progress, "_level", "intermediate")
        keywords = getattr(progress, "_keywords", [])

        # Build UMCF content structure from extracted content
        content_modules = []

        # Create lectures module
        lectures = extracted_content.get("lectures", [])
        if lectures:
            lecture_children = []
            for idx, lecture in enumerate(lectures):
                # Use transcript_text if available, otherwise fall back to text_preview
                text_content = lecture.get("transcript_text", "") or lecture.get("text_preview", "")
                has_transcript = bool(lecture.get("transcript_text"))

                lecture_topic = {
                    "id": {"value": lecture.get("id", f"lecture-{idx + 1}")},
                    "title": lecture.get("title", f"Lecture {lecture.get('number', idx + 1)}"),
                    "type": "topic",
                    "orderIndex": idx,
                    "content": {
                        "text": text_content,
                        "hasVideo": lecture.get("has_video", False),
                        "hasTranscript": has_transcript or lecture.get("has_transcript", False),
                    },
                }
                if lecture.get("file"):
                    lecture_topic["content"]["sourceFile"] = lecture["file"]
                if lecture.get("transcript_url"):
                    lecture_topic["content"]["transcriptUrl"] = lecture["transcript_url"]
                lecture_children.append(lecture_topic)

            content_modules.append({
                "id": {"value": "lectures"},
                "title": "Lectures",
                "type": "module",
                "orderIndex": 0,
                "children": lecture_children,
            })

        # Create assignments module
        assignments = extracted_content.get("assignments", [])
        if assignments:
            assignment_children = []
            for idx, assignment in enumerate(assignments):
                assignment_item = {
                    "id": {"value": f"assignment-{idx + 1}"},
                    "title": assignment.get("name", f"Assignment {idx + 1}"),
                    "type": "assessment",
                    "orderIndex": idx,
                    "content": {
                        "assessmentType": "assignment",
                    },
                }
                if assignment.get("file"):
                    assignment_item["content"]["sourceFile"] = assignment["file"]
                assignment_children.append(assignment_item)

            content_modules.append({
                "id": {"value": "assignments"},
                "title": "Assignments",
                "type": "module",
                "orderIndex": 1,
                "children": assignment_children,
            })

        # Create exams module
        exams = extracted_content.get("exams", [])
        if exams:
            exam_children = []
            for idx, exam in enumerate(exams):
                exam_item = {
                    "id": {"value": f"exam-{idx + 1}"},
                    "title": exam.get("name", f"Exam {idx + 1}"),
                    "type": "assessment",
                    "orderIndex": idx,
                    "content": {
                        "assessmentType": "exam",
                    },
                }
                if exam.get("file"):
                    exam_item["content"]["sourceFile"] = exam["file"]
                exam_children.append(exam_item)

            content_modules.append({
                "id": {"value": "exams"},
                "title": "Exams",
                "type": "module",
                "orderIndex": 2,
                "children": exam_children,
            })

        # Create resources module
        resources = extracted_content.get("resources", [])
        if resources:
            resource_children = []
            for idx, resource in enumerate(resources):
                resource_item = {
                    "id": {"value": f"resource-{idx + 1}"},
                    "title": resource.get("name", f"Resource {idx + 1}"),
                    "type": "resource",
                    "orderIndex": idx,
                }
                if resource.get("file"):
                    resource_item["content"] = {"sourceFile": resource["file"]}
                resource_children.append(resource_item)

            content_modules.append({
                "id": {"value": "resources"},
                "title": "Additional Resources",
                "type": "module",
                "orderIndex": 3,
                "children": resource_children,
            })

        # Fallback if no content was extracted
        if not content_modules:
            content_modules = [{
                "id": {"value": "imported-content"},
                "title": "Imported Content",
                "type": "module",
                "orderIndex": 0,
                "children": [],
            }]

        # Map level to educational level
        level_map = {
            "introductory": "undergraduate-lower",
            "intermediate": "undergraduate-upper",
            "advanced": "graduate",
        }
        educational_level = level_map.get(level, "collegiate")

        # Build contributors list
        contributors = [
            {
                "role": "publisher",
                "name": "UnaMentis Importer",
            }
        ]
        for instructor in instructors:
            contributors.append({
                "role": "instructor",
                "name": instructor,
            })

        # Create UMCF document
        umcf = {
            "umcf": "1.0.0",
            "id": {
                "catalog": "UnaMentis",
                "value": config.output_name,
            },
            "title": course_title,
            "description": course_description,
            "version": {
                "number": "1.0.0",
                "date": datetime.utcnow().strftime("%Y-%m-%d"),
            },
            "lifecycle": {
                "status": "draft",
                "contributors": contributors,
            },
            "metadata": {
                "language": "en-US",
                "keywords": keywords,
                "department": department,
            },
            "educational": {
                "audience": {
                    "type": "learner",
                    "educationalLevel": educational_level,
                },
            },
            "rights": license_info.to_dict() if license_info else {},
            "content": content_modules,
            "glossary": {"terms": []},
            "_import_metadata": {
                "source": config.source_id,
                "course_id": config.course_id,
                "imported_at": datetime.utcnow().isoformat(),
                "attribution": attribution,
                "stats": {
                    "lectures": len(lectures),
                    "assignments": len(assignments),
                    "exams": len(exams),
                    "resources": len(resources),
                },
            },
        }

        # Save UMCF file
        output_path = self.output_dir / "curricula" / f"{config.output_name}.umcf"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, "w") as f:
            json.dump(umcf, f, indent=2)

        progress.update_stage("generate", "complete", 100, f"Generated {output_path.name}")
        progress.add_log(
            "info",
            f"Generated UMCF with {len(lectures)} lectures, "
            f"{len(assignments)} assignments, {len(exams)} exams"
        )
        progress.overall_progress = 95.0
        progress._output_path = output_path
        self._notify_progress(progress)

    async def _run_store_stage(self, progress: ImportProgress) -> Path:
        """Store the generated curriculum."""
        import shutil

        progress.current_stage = "store"
        progress.current_activity = "Storing curriculum..."
        progress.update_stage("store", "running")
        self._notify_progress(progress)

        output_path = getattr(progress, "_output_path", None)
        if not output_path:
            raise ValueError("No output path available")

        # Copy to the main curriculum directory where the server loads from
        # This is PROJECT_ROOT / "curriculum" / "examples" / "realistic"
        project_root = Path(__file__).parent.parent.parent.parent
        curriculum_dir = project_root / "curriculum" / "examples" / "realistic"
        curriculum_dir.mkdir(parents=True, exist_ok=True)

        final_path = curriculum_dir / output_path.name
        shutil.copy2(output_path, final_path)

        progress.update_stage("store", "complete", 100, "Stored successfully")
        progress.add_log("info", f"Curriculum stored at {final_path}")
        progress.overall_progress = 100.0
        self._notify_progress(progress)

        return final_path

    # =========================================================================
    # Helper Methods
    # =========================================================================

    def _create_stages(self, config: ImportConfig) -> List[ImportStage]:
        """Create stage list for progress tracking."""
        stages = [
            ImportStage(id="download", name="Download"),
            ImportStage(id="validate", name="Validate License"),
            ImportStage(id="extract", name="Extract Content"),
        ]

        # Enrichment stages
        if self.enrichment_enabled:
            enrich_stage = ImportStage(
                id="enrich",
                name="AI Enrichment",
                substages=[
                    ImportStage(id="enrich_analysis", name="Content Analysis"),
                    ImportStage(id="enrich_structure", name="Structure Inference"),
                    ImportStage(id="enrich_segment", name="Segmentation"),
                    ImportStage(id="enrich_objectives", name="Learning Objectives"),
                    ImportStage(id="enrich_assessments", name="Assessment Enhancement"),
                    ImportStage(id="enrich_images", name="Image Acquisition"),
                    ImportStage(id="enrich_media", name="Media Generation"),
                    ImportStage(id="enrich_tutoring", name="Tutoring Enhancement"),
                    ImportStage(id="enrich_kg", name="Knowledge Graph"),
                ],
            )
            stages.append(enrich_stage)

        stages.extend([
            ImportStage(id="generate", name="Generate UMCF"),
            ImportStage(id="store", name="Store Curriculum"),
        ])

        return stages

    def _get_file_size(self, path: Path) -> str:
        """Get human-readable file size."""
        if not path or not path.exists():
            return "Unknown"

        size = path.stat().st_size
        for unit in ["B", "KB", "MB", "GB"]:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"
