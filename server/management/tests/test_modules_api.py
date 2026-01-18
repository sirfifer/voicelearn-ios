"""
Tests for Modules API routes.

Comprehensive tests for module management functionality including:
- Utility functions (validation, file I/O)
- API handlers (list, get, download, create, delete, update)
- Domain creation for Knowledge Bowl
- KB audio prefetch functionality
"""
import json
import pytest
from pathlib import Path
from unittest.mock import MagicMock, AsyncMock, patch, mock_open
from aiohttp import web

import modules_api


# =============================================================================
# Utility Function Tests
# =============================================================================


class TestGetModulesRegistryPath:
    """Tests for get_modules_registry_path function."""

    def test_returns_path_object(self):
        """Should return a Path object."""
        result = modules_api.get_modules_registry_path()
        assert isinstance(result, Path)

    def test_path_ends_with_registry_json(self):
        """Should return path ending with registry.json."""
        result = modules_api.get_modules_registry_path()
        assert result.name == "registry.json"


class TestValidateModuleId:
    """Tests for validate_module_id function."""

    def test_valid_alphanumeric(self):
        """Should accept alphanumeric IDs."""
        assert modules_api.validate_module_id("knowledgebowl") is True

    def test_valid_with_hyphens(self):
        """Should accept IDs with hyphens."""
        assert modules_api.validate_module_id("knowledge-bowl") is True

    def test_valid_with_underscores(self):
        """Should accept IDs with underscores."""
        assert modules_api.validate_module_id("knowledge_bowl") is True

    def test_valid_mixed(self):
        """Should accept mixed alphanumeric, hyphens, and underscores."""
        assert modules_api.validate_module_id("kb-2024_v1") is True

    def test_invalid_empty(self):
        """Should reject empty string."""
        assert modules_api.validate_module_id("") is False

    def test_invalid_none(self):
        """Should reject None (converted to falsy)."""
        assert modules_api.validate_module_id(None) is False

    def test_invalid_with_dots(self):
        """Should reject IDs with dots (path traversal risk)."""
        assert modules_api.validate_module_id("../etc/passwd") is False

    def test_invalid_with_slashes(self):
        """Should reject IDs with slashes."""
        assert modules_api.validate_module_id("path/to/module") is False

    def test_invalid_with_spaces(self):
        """Should reject IDs with spaces."""
        assert modules_api.validate_module_id("knowledge bowl") is False


class TestGetModuleContentPath:
    """Tests for get_module_content_path function."""

    def test_valid_id_returns_path(self):
        """Should return path for valid ID."""
        result = modules_api.get_module_content_path("knowledge-bowl")
        assert isinstance(result, Path)
        assert result.name == "knowledge-bowl.json"

    def test_invalid_id_raises_error(self):
        """Should raise ValueError for invalid ID."""
        with pytest.raises(ValueError, match="Invalid module_id"):
            modules_api.get_module_content_path("../etc/passwd")

    def test_empty_id_raises_error(self):
        """Should raise ValueError for empty ID."""
        with pytest.raises(ValueError, match="Invalid module_id"):
            modules_api.get_module_content_path("")


class TestEnsureModulesDirectory:
    """Tests for ensure_modules_directory function."""

    @patch.object(Path, 'mkdir')
    def test_creates_directory(self, mock_mkdir):
        """Should call mkdir with correct parameters."""
        modules_api.ensure_modules_directory()
        mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)


class TestLoadModulesRegistry:
    """Tests for load_modules_registry function."""

    @patch.object(Path, 'exists', return_value=False)
    def test_returns_default_when_not_exists(self, mock_exists):
        """Should return default registry when file doesn't exist."""
        result = modules_api.load_modules_registry()
        assert result == {"modules": [], "version": "1.0.0"}

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', mock_open(read_data='{"modules": [{"id": "test"}], "version": "2.0.0"}'))
    def test_loads_existing_registry(self, mock_exists):
        """Should load registry from file when it exists."""
        result = modules_api.load_modules_registry()
        assert result["version"] == "2.0.0"
        assert len(result["modules"]) == 1

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', side_effect=Exception("Read error"))
    def test_returns_default_on_error(self, mock_open_err, mock_exists):
        """Should return default registry on read error."""
        result = modules_api.load_modules_registry()
        assert result == {"modules": [], "version": "1.0.0"}


class TestSaveModulesRegistry:
    """Tests for save_modules_registry function."""

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', mock_open())
    def test_saves_registry(self, mock_mkdir):
        """Should save registry to file."""
        registry = {"modules": [{"id": "test"}], "version": "1.0.0"}
        modules_api.save_modules_registry(registry)
        # No assertion needed - just verify no exception

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', side_effect=Exception("Write error"))
    def test_handles_write_error(self, mock_open_err, mock_mkdir):
        """Should handle write error gracefully."""
        registry = {"modules": [], "version": "1.0.0"}
        # Should not raise, just log error
        modules_api.save_modules_registry(registry)


class TestLoadModuleContent:
    """Tests for load_module_content function."""

    @patch.object(Path, 'exists', return_value=False)
    def test_returns_none_when_not_exists(self, mock_exists):
        """Should return None when file doesn't exist."""
        result = modules_api.load_module_content("knowledge-bowl")
        assert result is None

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', mock_open(read_data='{"domains": []}'))
    def test_loads_existing_content(self, mock_exists):
        """Should load content from file when it exists."""
        result = modules_api.load_module_content("knowledge-bowl")
        assert result == {"domains": []}

    @patch.object(Path, 'exists', return_value=True)
    @patch('builtins.open', side_effect=Exception("Read error"))
    def test_returns_none_on_error(self, mock_open_err, mock_exists):
        """Should return None on read error."""
        result = modules_api.load_module_content("knowledge-bowl")
        assert result is None


class TestSaveModuleContent:
    """Tests for save_module_content function."""

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', mock_open())
    def test_saves_content(self, mock_mkdir):
        """Should save content to file."""
        content = {"domains": [{"id": "science"}]}
        modules_api.save_module_content("knowledge-bowl", content)
        # No assertion needed - just verify no exception

    @patch.object(Path, 'mkdir')
    @patch('builtins.open', side_effect=Exception("Write error"))
    def test_handles_write_error(self, mock_open_err, mock_mkdir):
        """Should handle write error gracefully."""
        content = {"domains": []}
        # Should not raise, just log error
        modules_api.save_module_content("knowledge-bowl", content)


# =============================================================================
# Feature Flags Tests
# =============================================================================


class TestResolveFeatureFlags:
    """Tests for resolve_feature_flags function."""

    def test_all_features_enabled_no_overrides(self):
        """Should return all True when base flags are True and no overrides."""
        module = {
            "supports_team_mode": True,
            "supports_speed_training": True,
            "supports_competition_sim": True,
        }
        result = modules_api.resolve_feature_flags(module)
        assert result["supports_team_mode"] is True
        assert result["supports_speed_training"] is True
        assert result["supports_competition_sim"] is True

    def test_all_features_disabled_base(self):
        """Should return all False when base flags are False."""
        module = {
            "supports_team_mode": False,
            "supports_speed_training": False,
            "supports_competition_sim": False,
        }
        result = modules_api.resolve_feature_flags(module)
        assert result["supports_team_mode"] is False
        assert result["supports_speed_training"] is False
        assert result["supports_competition_sim"] is False

    def test_overrides_disable_features(self):
        """Should disable features when override is False."""
        module = {
            "supports_team_mode": True,
            "supports_speed_training": True,
            "supports_competition_sim": True,
            "feature_overrides": {
                "team_mode": False,
                "speed_training": True,
            }
        }
        result = modules_api.resolve_feature_flags(module)
        assert result["supports_team_mode"] is False  # Disabled by override
        assert result["supports_speed_training"] is True
        assert result["supports_competition_sim"] is True

    def test_missing_base_flags_default_to_false(self):
        """Should default to False for missing base flags."""
        module = {}
        result = modules_api.resolve_feature_flags(module)
        assert result["supports_team_mode"] is False
        assert result["supports_speed_training"] is False
        assert result["supports_competition_sim"] is False


# =============================================================================
# API Handler Tests - List Modules
# =============================================================================


@pytest.fixture
def mock_app():
    """Create a mock aiohttp application."""
    return web.Application()


@pytest.fixture
def mock_request(mock_app):
    """Create a factory for mock requests."""
    def _make_request(method="GET", json_data=None, query=None, match_info=None):
        request = MagicMock(spec=web.Request)
        request.app = mock_app
        request.method = method
        request.query = query or {}
        request.match_info = match_info or {}

        if json_data is not None:
            async def mock_json():
                return json_data
            request.json = mock_json
        else:
            async def mock_json():
                raise json.JSONDecodeError("No JSON", "", 0)
            request.json = mock_json

        return request
    return _make_request


class TestHandleListModules:
    """Tests for handle_list_modules endpoint."""

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_list_modules_success(self, mock_load, mock_request):
        """Should return list of enabled modules."""
        mock_load.return_value = {
            "version": "1.0.0",
            "modules": [
                {
                    "id": "knowledge-bowl",
                    "name": "Knowledge Bowl",
                    "description": "Academic competition prep",
                    "icon_name": "brain.head.profile",
                    "theme_color_hex": "#9B59B6",
                    "version": "1.0.0",
                    "enabled": True,
                    "supports_team_mode": True,
                    "supports_speed_training": True,
                    "supports_competition_sim": True,
                    "download_size": 2097152,
                }
            ]
        }

        request = mock_request(query={})
        response = await modules_api.handle_list_modules(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert len(data["modules"]) == 1
        assert data["modules"][0]["id"] == "knowledge-bowl"

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_list_modules_excludes_disabled(self, mock_load, mock_request):
        """Should exclude disabled modules by default."""
        mock_load.return_value = {
            "version": "1.0.0",
            "modules": [
                {
                    "id": "enabled-module",
                    "name": "Enabled",
                    "description": "Test",
                    "icon_name": "star",
                    "theme_color_hex": "#000000",
                    "version": "1.0.0",
                    "enabled": True,
                },
                {
                    "id": "disabled-module",
                    "name": "Disabled",
                    "description": "Test",
                    "icon_name": "star",
                    "theme_color_hex": "#000000",
                    "version": "1.0.0",
                    "enabled": False,
                }
            ]
        }

        request = mock_request(query={})
        response = await modules_api.handle_list_modules(request)

        data = json.loads(response.body)
        assert len(data["modules"]) == 1
        assert data["modules"][0]["id"] == "enabled-module"

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_list_modules_include_disabled(self, mock_load, mock_request):
        """Should include disabled modules when requested."""
        mock_load.return_value = {
            "version": "1.0.0",
            "modules": [
                {
                    "id": "enabled-module",
                    "name": "Enabled",
                    "description": "Test",
                    "icon_name": "star",
                    "theme_color_hex": "#000000",
                    "version": "1.0.0",
                    "enabled": True,
                },
                {
                    "id": "disabled-module",
                    "name": "Disabled",
                    "description": "Test",
                    "icon_name": "star",
                    "theme_color_hex": "#000000",
                    "version": "1.0.0",
                    "enabled": False,
                }
            ]
        }

        request = mock_request(query={"include_disabled": "true"})
        response = await modules_api.handle_list_modules(request)

        data = json.loads(response.body)
        assert len(data["modules"]) == 2

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry', side_effect=Exception("DB error"))
    async def test_list_modules_error(self, mock_load, mock_request):
        """Should return 500 on error."""
        request = mock_request(query={})
        response = await modules_api.handle_list_modules(request)

        assert response.status == 500


# =============================================================================
# API Handler Tests - Get Module
# =============================================================================


class TestHandleGetModule:
    """Tests for handle_get_module endpoint."""

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.load_module_content')
    async def test_get_module_success(self, mock_content, mock_registry, mock_request):
        """Should return module details."""
        mock_registry.return_value = {
            "modules": [
                {
                    "id": "knowledge-bowl",
                    "name": "Knowledge Bowl",
                    "description": "Academic competition prep",
                    "icon_name": "brain.head.profile",
                    "theme_color_hex": "#9B59B6",
                    "version": "1.0.0",
                    "enabled": True,
                    "supports_team_mode": True,
                    "supports_speed_training": True,
                    "supports_competition_sim": True,
                }
            ]
        }
        mock_content.return_value = {
            "domains": [{"id": "science", "name": "Science", "weight": 0.2, "icon_name": "atom", "questions": []}],
            "study_modes": [{"name": "Diagnostic"}],
            "estimated_study_hours": 40.0,
        }

        request = mock_request(match_info={"module_id": "knowledge-bowl"})
        response = await modules_api.handle_get_module(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert data["id"] == "knowledge-bowl"
        assert data["domains"][0]["id"] == "science"

    @pytest.mark.asyncio
    async def test_get_module_invalid_id(self, mock_request):
        """Should return 400 for invalid module ID."""
        request = mock_request(match_info={"module_id": "../etc/passwd"})
        response = await modules_api.handle_get_module(request)

        assert response.status == 400

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_get_module_not_found(self, mock_registry, mock_request):
        """Should return 404 when module not found."""
        mock_registry.return_value = {"modules": []}

        request = mock_request(match_info={"module_id": "nonexistent"})
        response = await modules_api.handle_get_module(request)

        assert response.status == 404

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry', side_effect=Exception("Error"))
    async def test_get_module_error(self, mock_registry, mock_request):
        """Should return 500 on error."""
        request = mock_request(match_info={"module_id": "knowledge-bowl"})
        response = await modules_api.handle_get_module(request)

        assert response.status == 500


# =============================================================================
# API Handler Tests - Download Module
# =============================================================================


class TestHandleDownloadModule:
    """Tests for handle_download_module endpoint."""

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.load_module_content')
    async def test_download_module_success(self, mock_content, mock_registry, mock_request):
        """Should return full module content for download."""
        mock_registry.return_value = {
            "modules": [
                {
                    "id": "knowledge-bowl",
                    "name": "Knowledge Bowl",
                    "description": "Academic competition prep",
                    "icon_name": "brain.head.profile",
                    "theme_color_hex": "#9B59B6",
                    "version": "1.0.0",
                    "enabled": True,
                    "supports_team_mode": True,
                    "supports_speed_training": True,
                    "supports_competition_sim": True,
                }
            ]
        }
        mock_content.return_value = {
            "domains": [{"id": "science", "questions": [{"id": "q1"}]}],
            "study_modes": [{"name": "Diagnostic"}],
            "settings": {"enable_spoken_questions": True},
        }

        request = mock_request(match_info={"module_id": "knowledge-bowl"})
        response = await modules_api.handle_download_module(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert data["id"] == "knowledge-bowl"
        assert "downloaded_at" in data
        assert data["total_questions"] == 1

    @pytest.mark.asyncio
    async def test_download_module_invalid_id(self, mock_request):
        """Should return 400 for invalid module ID."""
        request = mock_request(match_info={"module_id": "../etc/passwd"})
        response = await modules_api.handle_download_module(request)

        assert response.status == 400

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_download_module_not_found(self, mock_registry, mock_request):
        """Should return 404 when module not found."""
        mock_registry.return_value = {"modules": []}

        request = mock_request(match_info={"module_id": "nonexistent"})
        response = await modules_api.handle_download_module(request)

        assert response.status == 404

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.load_module_content')
    async def test_download_module_no_content(self, mock_content, mock_registry, mock_request):
        """Should return 404 when content not available."""
        mock_registry.return_value = {
            "modules": [{"id": "knowledge-bowl", "name": "KB", "description": "", "icon_name": "", "theme_color_hex": "", "version": "1.0.0"}]
        }
        mock_content.return_value = None

        request = mock_request(match_info={"module_id": "knowledge-bowl"})
        response = await modules_api.handle_download_module(request)

        assert response.status == 404

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry', side_effect=Exception("Error"))
    async def test_download_module_error(self, mock_registry, mock_request):
        """Should return 500 on error."""
        request = mock_request(match_info={"module_id": "knowledge-bowl"})
        response = await modules_api.handle_download_module(request)

        assert response.status == 500


# =============================================================================
# API Handler Tests - Create Module
# =============================================================================


class TestHandleCreateModule:
    """Tests for handle_create_module endpoint."""

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    async def test_create_module_success(self, mock_save, mock_load, mock_request):
        """Should create new module."""
        mock_load.return_value = {"modules": [], "version": "1.0.0"}

        request = mock_request(json_data={
            "id": "new-module",
            "name": "New Module",
            "description": "A new module",
            "icon_name": "star",
            "theme_color_hex": "#FF0000",
        })
        response = await modules_api.handle_create_module(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert data["success"] is True
        assert data["created"] is True
        mock_save.assert_called_once()

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    async def test_update_existing_module(self, mock_save, mock_load, mock_request):
        """Should update existing module."""
        mock_load.return_value = {
            "modules": [{"id": "existing-module", "name": "Existing", "description": "", "icon_name": "", "theme_color_hex": "", "version": "1.0.0"}],
            "version": "1.0.0"
        }

        request = mock_request(json_data={
            "id": "existing-module",
            "name": "Updated Module",
            "description": "Updated description",
            "icon_name": "star",
            "theme_color_hex": "#00FF00",
        })
        response = await modules_api.handle_create_module(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert data["success"] is True
        assert data["created"] is False

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    @patch('modules_api.save_module_content')
    async def test_create_module_with_content(self, mock_save_content, mock_save_reg, mock_load, mock_request):
        """Should save content when provided."""
        mock_load.return_value = {"modules": [], "version": "1.0.0"}

        request = mock_request(json_data={
            "id": "new-module",
            "name": "New Module",
            "description": "A new module",
            "icon_name": "star",
            "theme_color_hex": "#FF0000",
            "content": {"domains": []},
        })
        response = await modules_api.handle_create_module(request)

        assert response.status == 200
        mock_save_content.assert_called_once()

    @pytest.mark.asyncio
    async def test_create_module_missing_required_field(self, mock_request):
        """Should return 400 when required field is missing."""
        request = mock_request(json_data={
            "id": "new-module",
            "name": "New Module",
            # Missing description, icon_name, theme_color_hex
        })
        response = await modules_api.handle_create_module(request)

        assert response.status == 400
        data = json.loads(response.body)
        assert "Missing required field" in data["error"]

    @pytest.mark.asyncio
    async def test_create_module_invalid_json(self, mock_request):
        """Should return 400 for invalid JSON."""
        request = mock_request(json_data=None)  # Will raise JSONDecodeError
        response = await modules_api.handle_create_module(request)

        assert response.status == 400

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry', side_effect=Exception("Error"))
    async def test_create_module_error(self, mock_load, mock_request):
        """Should return 500 on error."""
        request = mock_request(json_data={
            "id": "new-module",
            "name": "New Module",
            "description": "A new module",
            "icon_name": "star",
            "theme_color_hex": "#FF0000",
        })
        response = await modules_api.handle_create_module(request)

        assert response.status == 500


# =============================================================================
# API Handler Tests - Delete Module
# =============================================================================


class TestHandleDeleteModule:
    """Tests for handle_delete_module endpoint."""

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    @patch('modules_api.get_module_content_path')
    async def test_delete_module_success(self, mock_path, mock_save, mock_load, mock_request):
        """Should delete module and content."""
        mock_load.return_value = {
            "modules": [{"id": "to-delete", "name": "Delete Me"}],
            "version": "1.0.0"
        }
        mock_path_obj = MagicMock()
        mock_path_obj.exists.return_value = True
        mock_path.return_value = mock_path_obj

        request = mock_request(match_info={"module_id": "to-delete"})
        response = await modules_api.handle_delete_module(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert data["success"] is True
        mock_path_obj.unlink.assert_called_once()

    @pytest.mark.asyncio
    async def test_delete_module_invalid_id(self, mock_request):
        """Should return 400 for invalid module ID."""
        request = mock_request(match_info={"module_id": "../etc/passwd"})
        response = await modules_api.handle_delete_module(request)

        assert response.status == 400

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_delete_module_not_found(self, mock_load, mock_request):
        """Should return 404 when module not found."""
        mock_load.return_value = {"modules": [], "version": "1.0.0"}

        request = mock_request(match_info={"module_id": "nonexistent"})
        response = await modules_api.handle_delete_module(request)

        assert response.status == 404

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry', side_effect=Exception("Error"))
    async def test_delete_module_error(self, mock_load, mock_request):
        """Should return 500 on error."""
        request = mock_request(match_info={"module_id": "knowledge-bowl"})
        response = await modules_api.handle_delete_module(request)

        assert response.status == 500


# =============================================================================
# API Handler Tests - Update Module Settings
# =============================================================================


class TestHandleUpdateModuleSettings:
    """Tests for handle_update_module_settings endpoint."""

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    async def test_update_enabled_state(self, mock_save, mock_load, mock_request):
        """Should update enabled state."""
        mock_load.return_value = {
            "modules": [{"id": "knowledge-bowl", "name": "KB", "enabled": True, "supports_team_mode": True, "supports_speed_training": True, "supports_competition_sim": True}],
            "version": "1.0.0"
        }

        request = mock_request(
            match_info={"module_id": "knowledge-bowl"},
            json_data={"enabled": False}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert data["success"] is True
        assert data["enabled"] is False

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    async def test_update_feature_overrides(self, mock_save, mock_load, mock_request):
        """Should update feature overrides."""
        mock_load.return_value = {
            "modules": [{"id": "knowledge-bowl", "name": "KB", "supports_team_mode": True, "supports_speed_training": True, "supports_competition_sim": True}],
            "version": "1.0.0"
        }

        request = mock_request(
            match_info={"module_id": "knowledge-bowl"},
            json_data={"feature_overrides": {"team_mode": False}}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 200
        data = json.loads(response.body)
        assert data["effective_features"]["supports_team_mode"] is False

    @pytest.mark.asyncio
    async def test_update_settings_invalid_id(self, mock_request):
        """Should return 400 for invalid module ID."""
        request = mock_request(
            match_info={"module_id": "../etc/passwd"},
            json_data={"enabled": False}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 400

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_update_settings_not_found(self, mock_load, mock_request):
        """Should return 404 when module not found."""
        mock_load.return_value = {"modules": [], "version": "1.0.0"}

        request = mock_request(
            match_info={"module_id": "nonexistent"},
            json_data={"enabled": False}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 404

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_update_settings_invalid_override_key(self, mock_load, mock_request):
        """Should return 400 for invalid override key."""
        mock_load.return_value = {
            "modules": [{"id": "knowledge-bowl", "name": "KB"}],
            "version": "1.0.0"
        }

        request = mock_request(
            match_info={"module_id": "knowledge-bowl"},
            json_data={"feature_overrides": {"invalid_key": True}}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 400
        data = json.loads(response.body)
        assert "Invalid feature override key" in data["error"]

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_update_settings_invalid_override_value(self, mock_load, mock_request):
        """Should return 400 for non-boolean override value."""
        mock_load.return_value = {
            "modules": [{"id": "knowledge-bowl", "name": "KB"}],
            "version": "1.0.0"
        }

        request = mock_request(
            match_info={"module_id": "knowledge-bowl"},
            json_data={"feature_overrides": {"team_mode": "yes"}}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 400
        data = json.loads(response.body)
        assert "boolean" in data["error"]

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry')
    async def test_update_settings_invalid_overrides_type(self, mock_load, mock_request):
        """Should return 400 when feature_overrides is not a dict."""
        mock_load.return_value = {
            "modules": [{"id": "knowledge-bowl", "name": "KB"}],
            "version": "1.0.0"
        }

        request = mock_request(
            match_info={"module_id": "knowledge-bowl"},
            json_data={"feature_overrides": "not a dict"}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 400

    @pytest.mark.asyncio
    async def test_update_settings_invalid_json(self, mock_request):
        """Should return 400 for invalid JSON."""
        request = mock_request(
            match_info={"module_id": "knowledge-bowl"},
            json_data=None
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 400

    @pytest.mark.asyncio
    @patch('modules_api.load_modules_registry', side_effect=Exception("Error"))
    async def test_update_settings_error(self, mock_load, mock_request):
        """Should return 500 on error."""
        request = mock_request(
            match_info={"module_id": "knowledge-bowl"},
            json_data={"enabled": False}
        )
        response = await modules_api.handle_update_module_settings(request)

        assert response.status == 500


# =============================================================================
# Route Registration Tests
# =============================================================================


class TestRegisterModulesRoutes:
    """Tests for register_modules_routes function."""

    @patch('modules_api.ensure_modules_directory')
    @patch('modules_api.seed_knowledge_bowl_module')
    def test_registers_routes(self, mock_seed, mock_ensure):
        """Should register all module routes."""
        app = web.Application()
        modules_api.register_modules_routes(app)

        # Check that routes were registered
        routes = [r.resource.canonical for r in app.router.routes()]
        assert "/api/modules" in routes
        assert "/api/modules/{module_id}" in routes
        assert "/api/modules/{module_id}/download" in routes
        assert "/api/modules/{module_id}/settings" in routes

        mock_ensure.assert_called_once()
        mock_seed.assert_called_once()


# =============================================================================
# Seed Knowledge Bowl Tests
# =============================================================================


class TestSeedKnowledgeBowlModule:
    """Tests for seed_knowledge_bowl_module function."""

    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    @patch('modules_api.save_module_content')
    def test_seeds_when_not_exists(self, mock_save_content, mock_save_reg, mock_load):
        """Should seed KB module when it doesn't exist."""
        mock_load.return_value = {"modules": [], "version": "1.0.0"}

        modules_api.seed_knowledge_bowl_module()

        mock_save_reg.assert_called_once()
        mock_save_content.assert_called_once()

    @patch('modules_api.load_modules_registry')
    @patch('modules_api.save_modules_registry')
    def test_skips_when_exists(self, mock_save_reg, mock_load):
        """Should skip seeding when KB already exists."""
        mock_load.return_value = {
            "modules": [{"id": "knowledge-bowl", "name": "KB"}],
            "version": "1.0.0"
        }

        modules_api.seed_knowledge_bowl_module()

        mock_save_reg.assert_not_called()


# =============================================================================
# Domain Creation Tests
# =============================================================================


class TestCreateKnowledgeBowlContent:
    """Tests for create_knowledge_bowl_content function."""

    def test_creates_all_domains(self):
        """Should create all 12 domains."""
        content = modules_api.create_knowledge_bowl_content()

        assert "domains" in content
        assert len(content["domains"]) == 12

        domain_ids = [d["id"] for d in content["domains"]]
        assert "science" in domain_ids
        assert "mathematics" in domain_ids
        assert "literature" in domain_ids
        assert "history" in domain_ids
        assert "social-studies" in domain_ids
        assert "arts" in domain_ids
        assert "current-events" in domain_ids
        assert "language" in domain_ids
        assert "technology" in domain_ids
        assert "pop-culture" in domain_ids
        assert "religion-philosophy" in domain_ids
        assert "miscellaneous" in domain_ids

    def test_creates_study_modes(self):
        """Should create all study modes."""
        content = modules_api.create_knowledge_bowl_content()

        assert "study_modes" in content
        assert len(content["study_modes"]) == 6

        mode_ids = [m["id"] for m in content["study_modes"]]
        assert "diagnostic" in mode_ids
        assert "targeted" in mode_ids
        assert "breadth" in mode_ids
        assert "speed" in mode_ids
        assert "competition" in mode_ids
        assert "team" in mode_ids

    def test_creates_settings(self):
        """Should include settings."""
        content = modules_api.create_knowledge_bowl_content()

        assert "settings" in content
        assert "default_time_per_question" in content["settings"]


class TestCreateDomainFunctions:
    """Tests for individual domain creation functions."""

    def test_create_science_domain(self):
        """Should create science domain with questions."""
        domain = modules_api.create_science_domain()

        assert domain["id"] == "science"
        assert domain["name"] == "Science"
        assert len(domain["questions"]) > 0
        assert "subcategories" in domain

    def test_create_mathematics_domain(self):
        """Should create mathematics domain with questions."""
        domain = modules_api.create_mathematics_domain()

        assert domain["id"] == "mathematics"
        assert len(domain["questions"]) > 0

    def test_create_literature_domain(self):
        """Should create literature domain with questions."""
        domain = modules_api.create_literature_domain()

        assert domain["id"] == "literature"
        assert len(domain["questions"]) > 0

    def test_create_history_domain(self):
        """Should create history domain with questions."""
        domain = modules_api.create_history_domain()

        assert domain["id"] == "history"
        assert len(domain["questions"]) > 0

    def test_create_social_studies_domain(self):
        """Should create social studies domain with questions."""
        domain = modules_api.create_social_studies_domain()

        assert domain["id"] == "social-studies"
        assert len(domain["questions"]) > 0

    def test_create_arts_domain(self):
        """Should create arts domain with questions."""
        domain = modules_api.create_arts_domain()

        assert domain["id"] == "arts"
        assert len(domain["questions"]) > 0

    def test_create_current_events_domain(self):
        """Should create current events domain."""
        domain = modules_api.create_current_events_domain()

        assert domain["id"] == "current-events"
        assert len(domain["questions"]) > 0

    def test_create_language_domain(self):
        """Should create language domain with questions."""
        domain = modules_api.create_language_domain()

        assert domain["id"] == "language"
        assert len(domain["questions"]) > 0

    def test_create_technology_domain(self):
        """Should create technology domain with questions."""
        domain = modules_api.create_technology_domain()

        assert domain["id"] == "technology"
        assert len(domain["questions"]) > 0

    def test_create_pop_culture_domain(self):
        """Should create pop culture domain with questions."""
        domain = modules_api.create_pop_culture_domain()

        assert domain["id"] == "pop-culture"
        assert len(domain["questions"]) > 0

    def test_create_religion_philosophy_domain(self):
        """Should create religion/philosophy domain with questions."""
        domain = modules_api.create_religion_philosophy_domain()

        assert domain["id"] == "religion-philosophy"
        assert len(domain["questions"]) > 0

    def test_create_miscellaneous_domain(self):
        """Should create miscellaneous domain with questions."""
        domain = modules_api.create_miscellaneous_domain()

        assert domain["id"] == "miscellaneous"
        assert len(domain["questions"]) > 0


# =============================================================================
# KB Audio Prefetch Tests
# =============================================================================


class TestCheckAndPrefetchKbAudio:
    """Tests for check_and_prefetch_kb_audio function."""

    @pytest.mark.asyncio
    @patch('modules_api.load_module_content')
    async def test_returns_none_when_no_content(self, mock_load):
        """Should return None when module content not found."""
        mock_load.return_value = None
        mock_manager = MagicMock()

        result = await modules_api.check_and_prefetch_kb_audio(mock_manager)

        assert result is None

    @pytest.mark.asyncio
    @patch('modules_api.load_module_content')
    async def test_returns_none_when_fully_covered(self, mock_load):
        """Should return None when audio is fully covered."""
        mock_load.return_value = {"domains": []}

        mock_coverage = MagicMock()
        mock_coverage.coverage_percent = 100.0
        mock_coverage.covered_segments = 100
        mock_coverage.total_segments = 100

        mock_manager = MagicMock()
        mock_manager.get_coverage_status.return_value = mock_coverage

        result = await modules_api.check_and_prefetch_kb_audio(mock_manager)

        assert result is None

    @pytest.mark.asyncio
    @patch('modules_api.load_module_content')
    async def test_starts_prefetch_when_incomplete(self, mock_load):
        """Should start prefetch when coverage is incomplete."""
        mock_load.return_value = {"domains": []}

        mock_coverage = MagicMock()
        mock_coverage.coverage_percent = 50.0
        mock_coverage.covered_segments = 50
        mock_coverage.total_segments = 100

        mock_manager = MagicMock()
        mock_manager.get_coverage_status.return_value = mock_coverage
        mock_manager.prefetch_module = AsyncMock(return_value="job-123")

        result = await modules_api.check_and_prefetch_kb_audio(mock_manager)

        assert result == "job-123"
        mock_manager.prefetch_module.assert_called_once()

    @pytest.mark.asyncio
    @patch('modules_api.load_module_content')
    async def test_force_regenerate(self, mock_load):
        """Should start prefetch when force_regenerate is True."""
        mock_load.return_value = {"domains": []}

        mock_coverage = MagicMock()
        mock_coverage.coverage_percent = 100.0
        mock_coverage.covered_segments = 100
        mock_coverage.total_segments = 100

        mock_manager = MagicMock()
        mock_manager.get_coverage_status.return_value = mock_coverage
        mock_manager.prefetch_module = AsyncMock(return_value="job-456")

        result = await modules_api.check_and_prefetch_kb_audio(
            mock_manager, force_regenerate=True
        )

        assert result == "job-456"


class TestScheduleKbAudioPrefetch:
    """Tests for schedule_kb_audio_prefetch function."""

    @pytest.mark.asyncio
    @patch('modules_api.check_and_prefetch_kb_audio')
    @patch('asyncio.sleep', new_callable=AsyncMock)
    async def test_skips_when_no_manager(self, mock_sleep, mock_check):
        """Should skip when KB audio manager not available."""
        app = web.Application()

        await modules_api.schedule_kb_audio_prefetch(app)

        mock_check.assert_not_called()

    @pytest.mark.asyncio
    @patch('modules_api.check_and_prefetch_kb_audio')
    @patch('asyncio.sleep', new_callable=AsyncMock)
    async def test_calls_prefetch_when_manager_available(self, mock_sleep, mock_check):
        """Should call prefetch when manager is available."""
        mock_check.return_value = "job-789"

        app = web.Application()
        app["kb_audio_manager"] = MagicMock()

        await modules_api.schedule_kb_audio_prefetch(app)

        mock_check.assert_called_once()

    @pytest.mark.asyncio
    @patch('modules_api.check_and_prefetch_kb_audio', side_effect=Exception("Error"))
    @patch('asyncio.sleep', new_callable=AsyncMock)
    async def test_handles_prefetch_error(self, mock_sleep, mock_check):
        """Should handle prefetch errors gracefully."""
        app = web.Application()
        app["kb_audio_manager"] = MagicMock()

        # Should not raise
        await modules_api.schedule_kb_audio_prefetch(app)
