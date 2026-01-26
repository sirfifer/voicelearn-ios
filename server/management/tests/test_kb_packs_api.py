"""
Tests for KB Packs API routes.

Comprehensive tests for question pack management functionality including:
- Utility functions (validation, file I/O, ID generation)
- Stats calculation and domain grouping
- API handlers (CRUD for packs and questions)
- Bundle creation and deduplication preview
"""
import json
import pytest
from pathlib import Path
from unittest.mock import MagicMock, AsyncMock, patch, mock_open
from aiohttp import web

import kb_packs_api


# =============================================================================
# Utility Function Tests
# =============================================================================


class TestValidatePackId:
    """Tests for validate_pack_id function."""

    def test_valid_alphanumeric(self):
        """Should accept alphanumeric IDs."""
        assert kb_packs_api.validate_pack_id("packtest") is True

    def test_valid_with_hyphens(self):
        """Should accept IDs with hyphens."""
        assert kb_packs_api.validate_pack_id("pack-test-1") is True

    def test_valid_with_underscores(self):
        """Should accept IDs with underscores."""
        assert kb_packs_api.validate_pack_id("pack_test_1") is True

    def test_valid_mixed(self):
        """Should accept mixed alphanumeric, hyphens, and underscores."""
        assert kb_packs_api.validate_pack_id("pack-2024_v1-test") is True

    def test_invalid_empty(self):
        """Should reject empty string."""
        assert kb_packs_api.validate_pack_id("") is False

    def test_invalid_none(self):
        """Should reject None."""
        assert kb_packs_api.validate_pack_id(None) is False

    def test_invalid_with_dots(self):
        """Should reject IDs with dots (path traversal risk)."""
        assert kb_packs_api.validate_pack_id("../etc/passwd") is False

    def test_invalid_with_slashes(self):
        """Should reject IDs with slashes."""
        assert kb_packs_api.validate_pack_id("path/to/pack") is False

    def test_invalid_with_spaces(self):
        """Should reject IDs with spaces."""
        assert kb_packs_api.validate_pack_id("pack name") is False


class TestValidateQuestionId:
    """Tests for validate_question_id function."""

    def test_valid_alphanumeric(self):
        """Should accept alphanumeric IDs."""
        assert kb_packs_api.validate_question_id("q12345") is True

    def test_valid_with_hyphens(self):
        """Should accept IDs with hyphens."""
        assert kb_packs_api.validate_question_id("sci-phys-001") is True

    def test_valid_with_underscores(self):
        """Should accept IDs with underscores."""
        assert kb_packs_api.validate_question_id("sci_phys_001") is True

    def test_invalid_empty(self):
        """Should reject empty string."""
        assert kb_packs_api.validate_question_id("") is False

    def test_invalid_none(self):
        """Should reject None."""
        assert kb_packs_api.validate_question_id(None) is False

    def test_invalid_with_dots(self):
        """Should reject IDs with dots."""
        assert kb_packs_api.validate_question_id("q.test") is False


class TestGetPacksRegistryPath:
    """Tests for get_packs_registry_path function."""

    def test_returns_path_object(self):
        """Should return a Path object."""
        result = kb_packs_api.get_packs_registry_path()
        assert isinstance(result, Path)

    def test_path_ends_with_registry_json(self):
        """Should return path ending with registry.json."""
        result = kb_packs_api.get_packs_registry_path()
        assert result.name == "registry.json"


class TestGetQuestionsStorePath:
    """Tests for get_questions_store_path function."""

    def test_returns_path_object(self):
        """Should return a Path object."""
        result = kb_packs_api.get_questions_store_path()
        assert isinstance(result, Path)

    def test_path_ends_with_questions_json(self):
        """Should return path ending with questions.json."""
        result = kb_packs_api.get_questions_store_path()
        assert result.name == "questions.json"


class TestEnsurePacksDirectory:
    """Tests for ensure_packs_directory function."""

    @patch.object(Path, 'mkdir')
    def test_creates_directory(self, mock_mkdir):
        """Should call mkdir with correct parameters."""
        kb_packs_api.ensure_packs_directory()
        mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)


class TestLoadPacksRegistry:
    """Tests for load_packs_registry function."""

    @patch.object(Path, 'exists', return_value=False)
    def test_returns_default_when_not_exists(self, mock_exists):
        """Should return default registry when file doesn't exist."""
        result = kb_packs_api.load_packs_registry()
        assert result == {"packs": [], "version": "1.0.0"}

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', mock_open(read_data='{"packs": [{"id": "test"}], "version": "2.0.0"}'))
    def test_loads_existing_registry(self, mock_exists):
        """Should load registry from file when it exists."""
        result = kb_packs_api.load_packs_registry()
        assert result["version"] == "2.0.0"
        assert len(result["packs"]) == 1

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', side_effect=Exception("Read error"))
    def test_returns_default_on_error(self, mock_open_err, mock_exists):
        """Should return default registry on read error."""
        result = kb_packs_api.load_packs_registry()
        assert result == {"packs": [], "version": "1.0.0"}


class TestSavePacksRegistry:
    """Tests for save_packs_registry function."""

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', mock_open())
    def test_saves_registry(self, mock_mkdir):
        """Should save registry to file."""
        registry = {"packs": [{"id": "test"}], "version": "1.0.0"}
        kb_packs_api.save_packs_registry(registry)
        # No assertion needed - just verify no exception

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', side_effect=Exception("Write error"))
    def test_handles_write_error(self, mock_open_err, mock_mkdir):
        """Should handle write error gracefully."""
        registry = {"packs": [], "version": "1.0.0"}
        kb_packs_api.save_packs_registry(registry)


class TestLoadQuestionsStore:
    """Tests for load_questions_store function."""

    @patch.object(Path, 'exists', return_value=False)
    def test_returns_default_when_not_exists(self, mock_exists):
        """Should return default store when file doesn't exist."""
        result = kb_packs_api.load_questions_store()
        assert result == {"questions": {}, "version": "1.0.0"}

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', mock_open(read_data='{"questions": {"q1": {}}, "version": "2.0.0"}'))
    def test_loads_existing_store(self, mock_exists):
        """Should load store from file when it exists."""
        result = kb_packs_api.load_questions_store()
        assert result["version"] == "2.0.0"
        assert "q1" in result["questions"]

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', side_effect=Exception("Read error"))
    def test_returns_default_on_error(self, mock_open_err, mock_exists):
        """Should return default store on read error."""
        result = kb_packs_api.load_questions_store()
        assert result == {"questions": {}, "version": "1.0.0"}


class TestSaveQuestionsStore:
    """Tests for save_questions_store function."""

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', mock_open())
    def test_saves_store(self, mock_mkdir):
        """Should save store to file."""
        store = {"questions": {"q1": {}}, "version": "1.0.0"}
        kb_packs_api.save_questions_store(store)

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', side_effect=Exception("Write error"))
    def test_handles_write_error(self, mock_open_err, mock_mkdir):
        """Should handle write error gracefully."""
        store = {"questions": {}, "version": "1.0.0"}
        kb_packs_api.save_questions_store(store)


class TestGeneratePackId:
    """Tests for generate_pack_id function."""

    def test_returns_string(self):
        """Should return a string."""
        result = kb_packs_api.generate_pack_id()
        assert isinstance(result, str)

    def test_starts_with_pack_prefix(self):
        """Should start with 'pack-' prefix."""
        result = kb_packs_api.generate_pack_id()
        assert result.startswith("pack-")

    def test_generates_unique_ids(self):
        """Should generate unique IDs."""
        ids = [kb_packs_api.generate_pack_id() for _ in range(100)]
        assert len(set(ids)) == 100


class TestGenerateQuestionId:
    """Tests for generate_question_id function."""

    def test_returns_string(self):
        """Should return a string."""
        result = kb_packs_api.generate_question_id("science", "physics")
        assert isinstance(result, str)

    def test_contains_domain_prefix(self):
        """Should contain domain prefix."""
        result = kb_packs_api.generate_question_id("science", "physics")
        assert result.startswith("sci-")

    def test_contains_subcategory(self):
        """Should contain subcategory."""
        result = kb_packs_api.generate_question_id("science", "physics")
        assert "phys" in result

    def test_generates_unique_ids(self):
        """Should generate unique IDs."""
        ids = [kb_packs_api.generate_question_id("science", "physics") for _ in range(100)]
        assert len(set(ids)) == 100


# =============================================================================
# Stats Calculation Tests
# =============================================================================


class TestCalculatePackStats:
    """Tests for calculate_pack_stats function."""

    def test_empty_pack(self):
        """Should handle empty pack."""
        pack = {"id": "test", "question_ids": []}
        store = {"questions": {}}
        stats = kb_packs_api.calculate_pack_stats(pack, store)
        assert stats["question_count"] == 0
        assert stats["domain_count"] == 0
        assert stats["audio_coverage_percent"] == 0
        assert stats["missing_audio_count"] == 0

    def test_pack_with_questions(self):
        """Should calculate correct stats for pack with questions."""
        pack = {"id": "test", "question_ids": ["q1", "q2", "q3"]}
        store = {
            "questions": {
                "q1": {"difficulty": 1, "domain_id": "science", "question_type": "toss_up", "has_audio": True},
                "q2": {"difficulty": 2, "domain_id": "science", "question_type": "toss_up", "has_audio": False},
                "q3": {"difficulty": 3, "domain_id": "math", "question_type": "bonus", "has_audio": True},
            }
        }
        stats = kb_packs_api.calculate_pack_stats(pack, store)
        assert stats["question_count"] == 3
        assert stats["domain_count"] == 2
        assert stats["difficulty_distribution"][1] == 1
        assert stats["difficulty_distribution"][2] == 1
        assert stats["difficulty_distribution"][3] == 1
        assert "toss_up" in stats["question_types"]
        assert "bonus" in stats["question_types"]
        assert stats["audio_coverage_percent"] == pytest.approx(66.7, rel=0.1)
        assert stats["missing_audio_count"] == 1

    def test_handles_missing_questions(self):
        """Should handle question IDs not in store."""
        pack = {"id": "test", "question_ids": ["q1", "q_missing"]}
        store = {
            "questions": {
                "q1": {"difficulty": 1, "domain_id": "science", "question_type": "toss_up"},
            }
        }
        stats = kb_packs_api.calculate_pack_stats(pack, store)
        assert stats["question_count"] == 1

    def test_handles_invalid_difficulty(self):
        """Should handle questions with invalid difficulty."""
        pack = {"id": "test", "question_ids": ["q1"]}
        store = {
            "questions": {
                "q1": {"difficulty": 10, "domain_id": "science"},  # Invalid difficulty
            }
        }
        stats = kb_packs_api.calculate_pack_stats(pack, store)
        # Invalid difficulty should not be counted in distribution
        assert sum(stats["difficulty_distribution"].values()) == 0


class TestGetDomainGroups:
    """Tests for get_domain_groups function."""

    def test_empty_pack(self):
        """Should return empty list for empty pack."""
        pack = {"id": "test", "question_ids": []}
        store = {"questions": {}}
        result = kb_packs_api.get_domain_groups(pack, store)
        assert result == []

    def test_pack_with_questions(self):
        """Should group questions by domain."""
        pack = {"id": "test", "question_ids": ["q1", "q2", "q3"]}
        store = {
            "questions": {
                "q1": {"domain_id": "science", "subcategory": "physics"},
                "q2": {"domain_id": "science", "subcategory": "chemistry"},
                "q3": {"domain_id": "math", "subcategory": "algebra"},
            }
        }
        result = kb_packs_api.get_domain_groups(pack, store)
        assert len(result) == 2

        # Find science domain
        science = next((d for d in result if d["domain_id"] == "science"), None)
        assert science is not None
        assert science["question_count"] == 2
        assert len(science["subcategories"]) == 2

    def test_sorts_domains_alphabetically(self):
        """Should sort domains alphabetically."""
        pack = {"id": "test", "question_ids": ["q1", "q2"]}
        store = {
            "questions": {
                "q1": {"domain_id": "science", "subcategory": "physics"},
                "q2": {"domain_id": "math", "subcategory": "algebra"},
            }
        }
        result = kb_packs_api.get_domain_groups(pack, store)
        assert result[0]["domain_id"] == "math"
        assert result[1]["domain_id"] == "science"


# =============================================================================
# API Handler Tests
# =============================================================================


class TestHandleListPacks:
    """Tests for handle_list_packs handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.query = {}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_empty_list(self, mock_store, mock_registry, mock_request):
        """Should return empty list when no packs exist."""
        mock_registry.return_value = {"packs": [], "version": "1.0.0"}
        mock_store.return_value = {"questions": {}, "version": "1.0.0"}

        response = await kb_packs_api.handle_list_packs(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["packs"] == []
        assert data["total"] == 0

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_packs(self, mock_store, mock_registry, mock_request):
        """Should return list of packs."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Test Pack", "type": "custom", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": ""}
            ],
            "version": "1.0.0"
        }
        mock_store.return_value = {"questions": {}, "version": "1.0.0"}

        response = await kb_packs_api.handle_list_packs(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert len(data["packs"]) == 1
        assert data["packs"][0]["id"] == "pack-1"

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_filters_by_type(self, mock_store, mock_registry, mock_request):
        """Should filter packs by type."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Custom Pack", "type": "custom", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": ""},
                {"id": "pack-2", "name": "System Pack", "type": "system", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": ""},
            ],
            "version": "1.0.0"
        }
        mock_store.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.query = {"type": "custom"}

        response = await kb_packs_api.handle_list_packs(mock_request)
        data = json.loads(response.body)

        assert len(data["packs"]) == 1
        assert data["packs"][0]["type"] == "custom"

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_filters_by_status(self, mock_store, mock_registry, mock_request):
        """Should filter packs by status."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Active Pack", "type": "custom", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": ""},
                {"id": "pack-2", "name": "Archived Pack", "type": "custom", "status": "archived",
                 "difficulty_tier": "varsity", "question_ids": [], "description": ""},
            ],
            "version": "1.0.0"
        }
        mock_store.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.query = {"status": "archived"}

        response = await kb_packs_api.handle_list_packs(mock_request)
        data = json.loads(response.body)

        assert len(data["packs"]) == 1
        assert data["packs"][0]["status"] == "archived"

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_search_filter(self, mock_store, mock_registry, mock_request):
        """Should filter packs by search query."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Science Pack", "type": "custom", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": "Physics questions"},
                {"id": "pack-2", "name": "Math Pack", "type": "custom", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": "Algebra"},
            ],
            "version": "1.0.0"
        }
        mock_store.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.query = {"search": "science"}

        response = await kb_packs_api.handle_list_packs(mock_request)
        data = json.loads(response.body)

        assert len(data["packs"]) == 1
        assert data["packs"][0]["name"] == "Science Pack"


class TestHandleCreatePack:
    """Tests for handle_create_pack handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    async def test_creates_pack(self, mock_save, mock_load, mock_request):
        """Should create a new pack."""
        mock_load.return_value = {"packs": [], "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={
            "name": "New Pack",
            "description": "Test description",
            "type": "custom",
            "difficulty_tier": "varsity"
        })

        response = await kb_packs_api.handle_create_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 200  # API returns 200 for successful creation
        assert data["success"] is True
        assert data["pack"]["name"] == "New Pack"
        mock_save.assert_called_once()

    @pytest.mark.asyncio
    async def test_rejects_missing_name(self, mock_request):
        """Should reject request without name."""
        mock_request.json = AsyncMock(return_value={
            "description": "Test",
            "type": "custom"
        })

        response = await kb_packs_api.handle_create_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False
        assert "name" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_rejects_invalid_type(self, mock_request):
        """Should reject invalid pack type."""
        mock_request.json = AsyncMock(return_value={
            "name": "Test",
            "type": "invalid_type"
        })

        response = await kb_packs_api.handle_create_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False

    @pytest.mark.asyncio
    async def test_rejects_invalid_difficulty_tier(self, mock_request):
        """Should reject invalid difficulty tier."""
        mock_request.json = AsyncMock(return_value={
            "name": "Test",
            "type": "custom",
            "difficulty_tier": "invalid_tier"
        })

        response = await kb_packs_api.handle_create_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False


class TestHandleGetPack:
    """Tests for handle_get_pack handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"pack_id": "pack-1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_pack(self, mock_store, mock_registry, mock_request):
        """Should return pack by ID."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Test Pack", "type": "custom", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": ""}
            ],
            "version": "1.0.0"
        }
        mock_store.return_value = {"questions": {}, "version": "1.0.0"}

        response = await kb_packs_api.handle_get_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["pack"]["id"] == "pack-1"

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    async def test_returns_404_for_missing_pack(self, mock_registry, mock_request):
        """Should return 404 for non-existent pack."""
        mock_registry.return_value = {"packs": [], "version": "1.0.0"}
        mock_request.match_info = {"pack_id": "nonexistent"}

        response = await kb_packs_api.handle_get_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert data["success"] is False

    @pytest.mark.asyncio
    async def test_rejects_invalid_pack_id(self, mock_request):
        """Should reject invalid pack ID."""
        mock_request.match_info = {"pack_id": "../etc/passwd"}

        response = await kb_packs_api.handle_get_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False


class TestHandleUpdatePack:
    """Tests for handle_update_pack handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"pack_id": "pack-1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_updates_pack(self, mock_store, mock_save, mock_registry, mock_request):
        """Should update pack fields."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Old Name", "type": "custom", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": [], "description": ""}
            ],
            "version": "1.0.0"
        }
        mock_store.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={"name": "New Name"})

        response = await kb_packs_api.handle_update_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["pack"]["name"] == "New Name"
        mock_save.assert_called_once()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    async def test_rejects_system_pack_update(self, mock_registry, mock_request):
        """Should reject update to system pack."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "System Pack", "type": "system", "status": "active",
                 "difficulty_tier": "varsity", "question_ids": []}
            ],
            "version": "1.0.0"
        }
        mock_request.json = AsyncMock(return_value={"name": "New Name"})

        response = await kb_packs_api.handle_update_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 403
        assert data["success"] is False


class TestHandleDeletePack:
    """Tests for handle_delete_pack handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"pack_id": "pack-1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    async def test_deletes_pack(self, mock_save, mock_registry, mock_request):
        """Should delete pack."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Test Pack", "type": "custom", "status": "active"}
            ],
            "version": "1.0.0"
        }

        response = await kb_packs_api.handle_delete_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        mock_save.assert_called_once()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    async def test_rejects_system_pack_delete(self, mock_registry, mock_request):
        """Should reject delete of system pack."""
        mock_registry.return_value = {
            "packs": [
                {"id": "pack-1", "name": "System Pack", "type": "system", "status": "active"}
            ],
            "version": "1.0.0"
        }

        response = await kb_packs_api.handle_delete_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 403
        assert data["success"] is False


class TestHandleCreateQuestion:
    """Tests for handle_create_question handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    async def test_creates_question(self, mock_save_reg, mock_load_reg, mock_save, mock_load, mock_request):
        """Should create a new question."""
        mock_load.return_value = {"questions": {}, "version": "1.0.0"}
        mock_load_reg.return_value = {"packs": [], "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={
            "domain_id": "science",
            "subcategory": "physics",
            "question_text": "What is the SI unit of force?",
            "answer_text": "Newton",
            "difficulty": 2
        })

        response = await kb_packs_api.handle_create_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 200  # API returns 200 for successful creation
        assert data["success"] is True
        assert data["question"]["question_text"] == "What is the SI unit of force?"
        mock_save.assert_called_once()

    @pytest.mark.asyncio
    async def test_rejects_missing_fields(self, mock_request):
        """Should reject request with missing required fields."""
        mock_request.json = AsyncMock(return_value={
            "question_text": "Incomplete question"
        })

        response = await kb_packs_api.handle_create_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False


class TestHandleListQuestions:
    """Tests for handle_list_questions handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.query = {}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.get_kb_repo')
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_questions(self, mock_load, mock_get_repo, mock_request):
        """Should return list of questions."""
        mock_get_repo.return_value = None  # Fall back to JSON store
        mock_load.return_value = {
            "questions": {
                "q1": {
                    "id": "q1",
                    "domain_id": "science",
                    "subcategory": "physics",
                    "question_text": "Test question",
                    "answer_text": "Test answer",
                    "difficulty": 2,
                    "status": "active",
                    "pack_ids": []
                }
            },
            "version": "1.0.0"
        }

        response = await kb_packs_api.handle_list_questions(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert len(data["questions"]) == 1

    @pytest.mark.asyncio
    @patch('kb_packs_api.get_kb_repo')
    @patch('kb_packs_api.load_questions_store')
    async def test_filters_by_domain(self, mock_load, mock_get_repo, mock_request):
        """Should filter questions by domain."""
        mock_get_repo.return_value = None  # Fall back to JSON store
        mock_load.return_value = {
            "questions": {
                "q1": {"id": "q1", "domain_id": "science", "status": "active", "pack_ids": []},
                "q2": {"id": "q2", "domain_id": "math", "status": "active", "pack_ids": []},
            },
            "version": "1.0.0"
        }
        mock_request.query = {"domain_id": "science"}

        response = await kb_packs_api.handle_list_questions(mock_request)
        data = json.loads(response.body)

        assert len(data["questions"]) == 1
        assert data["questions"][0]["domain_id"] == "science"

    @pytest.mark.asyncio
    @patch('kb_packs_api.get_kb_repo')
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_filters_by_pack(self, mock_load_q, mock_load_p, mock_get_repo, mock_request):
        """Should filter questions by pack_id."""
        mock_get_repo.return_value = None  # Fall back to JSON store
        mock_load_p.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Pack 1", "question_ids": ["q1"]}
            ],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {
            "questions": {
                "q1": {"id": "q1", "domain_id": "science", "status": "active", "pack_ids": ["pack-1"]},
                "q2": {"id": "q2", "domain_id": "math", "status": "active", "pack_ids": ["pack-2"]},
            },
            "version": "1.0.0"
        }
        mock_request.query = {"pack_id": "pack-1"}

        response = await kb_packs_api.handle_list_questions(mock_request)
        data = json.loads(response.body)

        assert len(data["questions"]) == 1
        assert "pack-1" in data["questions"][0]["pack_ids"]


class TestHandleAddQuestionsToPack:
    """Tests for handle_add_questions_to_pack handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"pack_id": "pack-1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    async def test_adds_questions(self, mock_save_q, mock_load_q, mock_save_p, mock_load_p, mock_request):
        """Should add questions to pack."""
        mock_load_p.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Test", "type": "custom", "status": "active",
                 "question_ids": [], "difficulty_tier": "varsity"}
            ],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {
            "questions": {
                "q1": {"id": "q1", "pack_ids": [], "status": "active"},
                "q2": {"id": "q2", "pack_ids": [], "status": "active"},
            },
            "version": "1.0.0"
        }
        mock_request.json = AsyncMock(return_value={"question_ids": ["q1", "q2"]})

        response = await kb_packs_api.handle_add_questions_to_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["added_count"] == 2


class TestHandleRemoveQuestionFromPack:
    """Tests for handle_remove_question_from_pack handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"pack_id": "pack-1", "question_id": "q1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    async def test_removes_question(self, mock_save_q, mock_load_q, mock_save_p, mock_load_p, mock_request):
        """Should remove question from pack."""
        mock_load_p.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Test", "type": "custom", "status": "active",
                 "question_ids": ["q1", "q2"], "difficulty_tier": "varsity"}
            ],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {
            "questions": {
                "q1": {"id": "q1", "pack_ids": ["pack-1"]},
                "q2": {"id": "q2", "pack_ids": ["pack-1"]},
            },
            "version": "1.0.0"
        }

        response = await kb_packs_api.handle_remove_question_from_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True


class TestHandleCreateBundle:
    """Tests for handle_create_bundle handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_creates_bundle(self, mock_load_q, mock_save_p, mock_load_p, mock_request):
        """Should create a bundle from multiple packs."""
        mock_load_p.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Pack 1", "type": "custom", "status": "active",
                 "question_ids": ["q1"], "difficulty_tier": "varsity"},
                {"id": "pack-2", "name": "Pack 2", "type": "custom", "status": "active",
                 "question_ids": ["q2"], "difficulty_tier": "varsity"},
            ],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {
            "questions": {
                "q1": {"id": "q1", "question_text": "Q1"},
                "q2": {"id": "q2", "question_text": "Q2"},
            },
            "version": "1.0.0"
        }
        mock_request.json = AsyncMock(return_value={
            "name": "Test Bundle",
            "source_pack_ids": ["pack-1", "pack-2"],
            "difficulty_tier": "varsity",
            "deduplication_strategy": "keep_first"
        })

        response = await kb_packs_api.handle_create_bundle(mock_request)
        data = json.loads(response.body)

        assert response.status == 200  # API returns 200 for successful creation
        assert data["success"] is True
        assert data["pack"]["type"] == "bundle"


class TestHandlePreviewDeduplication:
    """Tests for handle_preview_deduplication handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_detects_duplicates(self, mock_load_q, mock_load_p, mock_request):
        """Should detect duplicate questions (by question_text)."""
        mock_load_p.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Pack 1", "question_ids": ["q1", "q2"]},
                {"id": "pack-2", "name": "Pack 2", "question_ids": ["q3", "q4"]},
            ],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {
            "questions": {
                "q1": {"id": "q1", "question_text": "Same question text"},  # Duplicate
                "q2": {"id": "q2", "question_text": "Unique question 1"},
                "q3": {"id": "q3", "question_text": "Same question text"},  # Duplicate
                "q4": {"id": "q4", "question_text": "Unique question 2"},
            },
            "version": "1.0.0"
        }
        mock_request.json = AsyncMock(return_value={
            "source_pack_ids": ["pack-1", "pack-2"]
        })

        response = await kb_packs_api.handle_preview_deduplication(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        # q1 and q3 have same question_text, so 1 duplicate (the extra occurrence)
        assert data["total_duplicates"] == 1  # Extra occurrences
        assert data["unique_questions_after_dedup"] == 3  # Unique question texts
        assert len(data["duplicate_groups"]) == 1  # One group of duplicates


class TestHandleGetQuestion:
    """Tests for handle_get_question handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"question_id": "q1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_question(self, mock_load, mock_request):
        """Should return question by ID."""
        mock_load.return_value = {
            "questions": {
                "q1": {"id": "q1", "question_text": "Test question", "answer_text": "Answer"}
            },
            "version": "1.0.0"
        }

        response = await kb_packs_api.handle_get_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["question"]["id"] == "q1"

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_404_for_missing_question(self, mock_load, mock_request):
        """Should return 404 for non-existent question."""
        mock_load.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.match_info = {"question_id": "nonexistent"}

        response = await kb_packs_api.handle_get_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert data["success"] is False

    @pytest.mark.asyncio
    async def test_rejects_invalid_question_id(self, mock_request):
        """Should reject invalid question ID."""
        mock_request.match_info = {"question_id": "../etc/passwd"}

        response = await kb_packs_api.handle_get_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False


class TestHandleUpdateQuestion:
    """Tests for handle_update_question handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"question_id": "q1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    async def test_updates_question(self, mock_save, mock_load, mock_request):
        """Should update question fields."""
        mock_load.return_value = {
            "questions": {
                "q1": {"id": "q1", "question_text": "Old text", "answer_text": "Answer", "difficulty": 2}
            },
            "version": "1.0.0"
        }
        mock_request.json = AsyncMock(return_value={"question_text": "New text"})

        response = await kb_packs_api.handle_update_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["question"]["question_text"] == "New text"

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_404_for_missing_question(self, mock_load, mock_request):
        """Should return 404 for non-existent question."""
        mock_load.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={"question_text": "New text"})

        response = await kb_packs_api.handle_update_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert data["success"] is False

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    async def test_rejects_invalid_difficulty(self, mock_load, mock_request):
        """Should reject invalid difficulty value."""
        mock_load.return_value = {
            "questions": {
                "q1": {"id": "q1", "question_text": "Test", "answer_text": "Answer", "difficulty": 2}
            },
            "version": "1.0.0"
        }
        mock_request.json = AsyncMock(return_value={"difficulty": 10})

        response = await kb_packs_api.handle_update_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "difficulty" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_rejects_invalid_question_id(self, mock_request):
        """Should reject invalid question ID."""
        mock_request.match_info = {"question_id": "../etc/passwd"}
        mock_request.json = AsyncMock(return_value={"question_text": "New text"})

        response = await kb_packs_api.handle_update_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False


class TestHandleDeleteQuestion:
    """Tests for handle_delete_question handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {"question_id": "q1"}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    async def test_deletes_question(self, mock_save_p, mock_load_p, mock_save_q, mock_load_q, mock_request):
        """Should delete a question."""
        mock_load_q.return_value = {
            "questions": {
                "q1": {"id": "q1", "question_text": "Test", "answer_text": "Answer"}
            },
            "version": "1.0.0"
        }
        mock_load_p.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Test Pack", "question_ids": ["q1"]}
            ],
            "version": "1.0.0"
        }

        response = await kb_packs_api.handle_delete_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["question_id"] == "q1"
        mock_save_q.assert_called_once()
        mock_save_p.assert_called_once()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.load_packs_registry')
    async def test_returns_404_for_missing_question(self, mock_load_p, mock_load_q, mock_request):
        """Should return 404 for non-existent question."""
        mock_load_q.return_value = {"questions": {}, "version": "1.0.0"}
        mock_load_p.return_value = {"packs": [], "version": "1.0.0"}
        mock_request.match_info = {"question_id": "nonexistent"}

        response = await kb_packs_api.handle_delete_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert data["success"] is False

    @pytest.mark.asyncio
    async def test_rejects_invalid_question_id(self, mock_request):
        """Should reject invalid question ID."""
        mock_request.match_info = {"question_id": "../etc/passwd"}

        response = await kb_packs_api.handle_delete_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False


class TestHandleBulkUpdateQuestions:
    """Tests for handle_bulk_update_questions handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    async def test_bulk_updates_questions(self, mock_save, mock_load, mock_request):
        """Should bulk update multiple questions."""
        mock_load.return_value = {
            "questions": {
                "q1": {"id": "q1", "question_text": "Q1", "difficulty": 2},
                "q2": {"id": "q2", "question_text": "Q2", "difficulty": 2},
            },
            "version": "1.0.0"
        }
        mock_request.json = AsyncMock(return_value={
            "question_ids": ["q1", "q2"],
            "updates": {"difficulty": 3}
        })

        response = await kb_packs_api.handle_bulk_update_questions(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["affected_count"] == 2

    @pytest.mark.asyncio
    async def test_rejects_missing_question_ids(self, mock_request):
        """Should reject request without question_ids."""
        mock_request.json = AsyncMock(return_value={
            "updates": {"difficulty": 3}
        })

        response = await kb_packs_api.handle_bulk_update_questions(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False

    @pytest.mark.asyncio
    async def test_rejects_missing_updates(self, mock_request):
        """Should reject request without updates."""
        mock_request.json = AsyncMock(return_value={
            "question_ids": ["q1", "q2"]
        })

        response = await kb_packs_api.handle_bulk_update_questions(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert data["success"] is False

    @pytest.mark.asyncio
    async def test_rejects_invalid_difficulty(self, mock_request):
        """Should reject invalid difficulty in bulk update."""
        mock_request.json = AsyncMock(return_value={
            "question_ids": ["q1"],
            "updates": {"difficulty": 10}
        })

        response = await kb_packs_api.handle_bulk_update_questions(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "difficulty" in data["error"].lower()


class TestHandleImportFromModule:
    """Tests for handle_import_from_module handler."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        return request

    @pytest.mark.asyncio
    async def test_rejects_missing_pack_id(self, mock_request):
        """Should reject request without pack_id."""
        mock_request.json = AsyncMock(return_value={})

        response = await kb_packs_api.handle_import_from_module(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "pack_id" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_rejects_invalid_pack_id(self, mock_request):
        """Should reject invalid pack_id."""
        mock_request.json = AsyncMock(return_value={
            "pack_id": "../etc/passwd"
        })

        response = await kb_packs_api.handle_import_from_module(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "invalid" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_module_content')
    async def test_returns_404_for_missing_module(self, mock_load_module, mock_request):
        """Should return 404 when KB module not found."""
        mock_load_module.return_value = None
        mock_request.json = AsyncMock(return_value={
            "pack_id": "pack-1"
        })

        response = await kb_packs_api.handle_import_from_module(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert "module" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_module_content')
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_returns_404_for_missing_pack(self, mock_load_q, mock_load_p, mock_load_module, mock_request):
        """Should return 404 for non-existent pack."""
        mock_load_module.return_value = {"domains": []}
        mock_load_p.return_value = {"packs": [], "version": "1.0.0"}
        mock_load_q.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={
            "pack_id": "nonexistent"
        })

        response = await kb_packs_api.handle_import_from_module(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert "not found" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_module_content')
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    async def test_imports_questions(self, mock_save_q, mock_load_q, mock_save_p, mock_load_p, mock_load_module, mock_request):
        """Should import questions from module to pack."""
        mock_load_module.return_value = {
            "domains": [
                {
                    "id": "science",
                    "questions": [
                        {
                            "id": "sci-001",
                            "domain_id": "science",
                            "question_text": "What is H2O?",
                            "answer_text": "Water",
                            "difficulty": 2
                        }
                    ]
                }
            ]
        }
        mock_load_p.return_value = {
            "packs": [
                {"id": "pack-1", "name": "Test Pack", "question_ids": []}
            ],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={
            "pack_id": "pack-1"
        })

        response = await kb_packs_api.handle_import_from_module(mock_request)
        data = json.loads(response.body)

        assert response.status == 200
        assert data["success"] is True
        assert data["imported_count"] == 1


class TestErrorHandling:
    """Tests for error handling paths."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {}
        request.query = {}
        return request

    @pytest.mark.asyncio
    async def test_create_pack_json_decode_error(self, mock_request):
        """Should handle JSON decode error in create_pack."""
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_create_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_update_pack_json_decode_error(self, mock_request):
        """Should handle JSON decode error in update_pack."""
        mock_request.match_info = {"pack_id": "pack-1"}
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_update_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_add_questions_json_decode_error(self, mock_request):
        """Should handle JSON decode error in add_questions_to_pack."""
        mock_request.match_info = {"pack_id": "pack-1"}
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_add_questions_to_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_create_bundle_json_decode_error(self, mock_request):
        """Should handle JSON decode error in create_bundle."""
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_create_bundle(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_preview_dedup_json_decode_error(self, mock_request):
        """Should handle JSON decode error in preview_deduplication."""
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_preview_deduplication(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_create_question_json_decode_error(self, mock_request):
        """Should handle JSON decode error in create_question."""
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_create_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_update_question_json_decode_error(self, mock_request):
        """Should handle JSON decode error in update_question."""
        mock_request.match_info = {"question_id": "q1"}
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_update_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_bulk_update_json_decode_error(self, mock_request):
        """Should handle JSON decode error in bulk_update_questions."""
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_bulk_update_questions(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_import_module_json_decode_error(self, mock_request):
        """Should handle JSON decode error in import_from_module."""
        mock_request.json = AsyncMock(side_effect=json.JSONDecodeError("test", "doc", 0))

        response = await kb_packs_api.handle_import_from_module(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "json" in data["error"].lower()


class TestAdditionalEdgeCases:
    """Additional edge case tests for better coverage."""

    @pytest.fixture
    def mock_request(self):
        """Create a mock request."""
        request = MagicMock(spec=web.Request)
        request.match_info = {}
        request.query = {}
        return request

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_add_questions_validates_pack_id(self, mock_load_q, mock_save_p, mock_load_p, mock_request):
        """Should reject invalid pack_id in add_questions."""
        mock_request.match_info = {"pack_id": "../etc/passwd"}
        mock_request.json = AsyncMock(return_value={"question_ids": ["q1"]})

        response = await kb_packs_api.handle_add_questions_to_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "invalid" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.save_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_add_questions_rejects_empty_list(self, mock_load_q, mock_save_p, mock_load_p, mock_request):
        """Should reject empty question_ids list."""
        mock_request.match_info = {"pack_id": "pack-1"}
        mock_request.json = AsyncMock(return_value={"question_ids": []})

        response = await kb_packs_api.handle_add_questions_to_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "question_ids" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_add_questions_pack_not_found(self, mock_load_q, mock_load_p, mock_request):
        """Should return 404 when pack not found."""
        mock_load_p.return_value = {"packs": [], "version": "1.0.0"}
        mock_load_q.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.match_info = {"pack_id": "nonexistent"}
        mock_request.json = AsyncMock(return_value={"question_ids": ["q1"]})

        response = await kb_packs_api.handle_add_questions_to_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert "not found" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_add_questions_rejects_system_pack(self, mock_load_q, mock_load_p, mock_request):
        """Should reject adding to system pack."""
        mock_load_p.return_value = {
            "packs": [{"id": "pack-1", "name": "System", "type": "system", "question_ids": []}],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {"questions": {"q1": {"id": "q1"}}, "version": "1.0.0"}
        mock_request.match_info = {"pack_id": "pack-1"}
        mock_request.json = AsyncMock(return_value={"question_ids": ["q1"]})

        response = await kb_packs_api.handle_add_questions_to_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 403
        assert "system" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_remove_question_pack_not_found(self, mock_load_q, mock_load_p, mock_request):
        """Should return 404 when pack not found for remove."""
        mock_load_p.return_value = {"packs": [], "version": "1.0.0"}
        mock_load_q.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.match_info = {"pack_id": "nonexistent", "question_id": "q1"}

        response = await kb_packs_api.handle_remove_question_from_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert "not found" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_remove_question_rejects_system_pack(self, mock_load_q, mock_load_p, mock_request):
        """Should reject removing from system pack."""
        mock_load_p.return_value = {
            "packs": [{"id": "pack-1", "name": "System", "type": "system", "question_ids": ["q1"]}],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {"questions": {"q1": {"id": "q1", "pack_ids": ["pack-1"]}}, "version": "1.0.0"}
        mock_request.match_info = {"pack_id": "pack-1", "question_id": "q1"}

        response = await kb_packs_api.handle_remove_question_from_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 403
        assert "system" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_packs_registry')
    @patch('kb_packs_api.load_questions_store')
    async def test_remove_question_not_in_pack(self, mock_load_q, mock_load_p, mock_request):
        """Should return 404 when question not in pack."""
        mock_load_p.return_value = {
            "packs": [{"id": "pack-1", "name": "Test", "type": "custom", "question_ids": []}],
            "version": "1.0.0"
        }
        mock_load_q.return_value = {"questions": {"q1": {"id": "q1", "pack_ids": []}}, "version": "1.0.0"}
        mock_request.match_info = {"pack_id": "pack-1", "question_id": "q1"}

        response = await kb_packs_api.handle_remove_question_from_pack(mock_request)
        data = json.loads(response.body)

        assert response.status == 404
        assert "not in pack" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_create_bundle_missing_source_packs(self, mock_request):
        """Should reject bundle without source_pack_ids."""
        mock_request.json = AsyncMock(return_value={
            "name": "Test Bundle",
            "difficulty_tier": "varsity"
        })

        response = await kb_packs_api.handle_create_bundle(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "source_pack_ids" in data["error"].lower()

    @pytest.mark.asyncio
    async def test_preview_dedup_missing_source_packs(self, mock_request):
        """Should reject preview without source_pack_ids."""
        mock_request.json = AsyncMock(return_value={})

        response = await kb_packs_api.handle_preview_deduplication(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "source_pack_ids" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    async def test_create_question_invalid_question_type(self, mock_save, mock_load, mock_request):
        """Should reject invalid question_type."""
        mock_load.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={
            "domain_id": "science",
            "subcategory": "physics",
            "question_text": "Test?",
            "answer_text": "Answer",
            "difficulty": 2,
            "question_type": "invalid_type"
        })

        response = await kb_packs_api.handle_create_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "question_type" in data["error"].lower()

    @pytest.mark.asyncio
    @patch('kb_packs_api.load_questions_store')
    @patch('kb_packs_api.save_questions_store')
    async def test_create_question_invalid_source(self, mock_save, mock_load, mock_request):
        """Should reject invalid question_source."""
        mock_load.return_value = {"questions": {}, "version": "1.0.0"}
        mock_request.json = AsyncMock(return_value={
            "domain_id": "science",
            "subcategory": "physics",
            "question_text": "Test?",
            "answer_text": "Answer",
            "difficulty": 2,
            "question_source": "invalid_source"
        })

        response = await kb_packs_api.handle_create_question(mock_request)
        data = json.loads(response.body)

        assert response.status == 400
        assert "question_source" in data["error"].lower()


class TestRegisterKbPacksRoutes:
    """Tests for register_kb_packs_routes function."""

    def test_registers_all_routes(self):
        """Should register all expected routes."""
        app = MagicMock(spec=web.Application)
        app.router = MagicMock()

        kb_packs_api.register_kb_packs_routes(app)

        # Check that routes were registered
        assert app.router.add_get.call_count >= 4
        assert app.router.add_post.call_count >= 5
        assert app.router.add_patch.call_count >= 2
        assert app.router.add_delete.call_count >= 3
