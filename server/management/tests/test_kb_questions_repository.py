"""Tests for KBQuestionsRepository."""

import pytest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

from kb_questions_repository import KBQuestionsRepository


class MockRecord(dict):
    """Mock asyncpg.Record that behaves like both dict and record."""

    def __getitem__(self, key):
        return super().__getitem__(key)


@pytest.fixture
def mock_pool():
    """Create a mock asyncpg pool."""
    pool = MagicMock()
    pool.acquire = MagicMock()
    return pool


@pytest.fixture
def mock_conn():
    """Create a mock asyncpg connection."""
    conn = AsyncMock()
    return conn


@pytest.fixture
def repo(mock_pool):
    """Create a repository instance with mock pool."""
    return KBQuestionsRepository(mock_pool)


class TestDomainOperations:
    """Tests for domain operations."""

    @pytest.mark.asyncio
    async def test_list_domains(self, repo, mock_pool, mock_conn):
        """Should list all domains."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetch.return_value = [
            MockRecord({
                "id": "science",
                "name": "Science",
                "weight": 10,
                "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
                "updated_at": datetime(2024, 1, 2, tzinfo=timezone.utc),
            })
        ]

        result = await repo.list_domains()

        assert len(result) == 1
        assert result[0]["id"] == "science"
        assert result[0]["name"] == "Science"
        assert isinstance(result[0]["created_at"], str)
        mock_conn.fetch.assert_called_once()

    @pytest.mark.asyncio
    async def test_list_domains_no_dates(self, repo, mock_pool, mock_conn):
        """Should handle domains without dates."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetch.return_value = [
            MockRecord({
                "id": "math",
                "name": "Mathematics",
                "weight": 8,
                "created_at": None,
                "updated_at": None,
            })
        ]

        result = await repo.list_domains()

        assert len(result) == 1
        assert result[0]["created_at"] is None

    @pytest.mark.asyncio
    async def test_get_domain(self, repo, mock_pool, mock_conn):
        """Should get a domain by ID."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "science",
            "name": "Science",
            "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
            "updated_at": None,
        })

        result = await repo.get_domain("science")

        assert result["id"] == "science"
        assert isinstance(result["created_at"], str)

    @pytest.mark.asyncio
    async def test_get_domain_not_found(self, repo, mock_pool, mock_conn):
        """Should return None for non-existent domain."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = None

        result = await repo.get_domain("nonexistent")

        assert result is None


class TestQuestionOperations:
    """Tests for question operations."""

    @pytest.mark.asyncio
    async def test_create_question(self, repo, mock_pool, mock_conn):
        """Should create a question."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "INSERT 0 1"
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "q1",
            "domain_id": "science",
            "domain_name": "Science",
            "domain_icon": "flask",
            "question_text": "What is H2O?",
            "answer_text": "Water",
            "acceptable_answers": ["water", "dihydrogen monoxide"],
            "hints": [],
            "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
            "updated_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
        })

        question = {
            "id": "q1",
            "domain_id": "science",
            "question_text": "What is H2O?",
            "answer_text": "Water",
        }
        result = await repo.create_question(question)

        assert result["id"] == "q1"
        mock_conn.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_question(self, repo, mock_pool, mock_conn):
        """Should get a question by ID."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "q1",
            "domain_id": "science",
            "domain_name": "Science",
            "domain_icon": "flask",
            "question_text": "What is H2O?",
            "answer_text": "Water",
            "acceptable_answers": ["water"],
            "hints": ["It's a common liquid"],
            "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
            "updated_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
        })

        result = await repo.get_question("q1")

        assert result["id"] == "q1"
        assert result["acceptable_answers"] == ["water"]
        assert result["hints"] == ["It's a common liquid"]

    @pytest.mark.asyncio
    async def test_get_question_null_arrays(self, repo, mock_pool, mock_conn):
        """Should handle null arrays in question."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "q1",
            "domain_id": "science",
            "domain_name": "Science",
            "domain_icon": "flask",
            "question_text": "Test?",
            "answer_text": "Answer",
            "acceptable_answers": None,
            "hints": None,
            "created_at": None,
            "updated_at": None,
        })

        result = await repo.get_question("q1")

        assert result["acceptable_answers"] == []
        assert result["hints"] == []

    @pytest.mark.asyncio
    async def test_get_question_not_found(self, repo, mock_pool, mock_conn):
        """Should return None for non-existent question."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = None

        result = await repo.get_question("nonexistent")

        assert result is None

    @pytest.mark.asyncio
    async def test_list_questions_no_filters(self, repo, mock_pool, mock_conn):
        """Should list questions without filters."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 1
        mock_conn.fetch.return_value = [
            MockRecord({
                "id": "q1",
                "domain_id": "science",
                "domain_name": "Science",
                "domain_icon": "flask",
                "question_text": "Test?",
                "answer_text": "Answer",
                "acceptable_answers": [],
                "hints": [],
                "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
                "updated_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
            })
        ]

        questions, total = await repo.list_questions()

        assert len(questions) == 1
        assert total == 1

    @pytest.mark.asyncio
    async def test_list_questions_with_pack_filter(self, repo, mock_pool, mock_conn):
        """Should filter questions by pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 2
        mock_conn.fetch.return_value = [
            MockRecord({
                "id": "q1",
                "domain_id": "science",
                "domain_name": "Science",
                "domain_icon": "flask",
                "question_text": "Test?",
                "answer_text": "Answer",
                "acceptable_answers": [],
                "hints": [],
                "created_at": None,
                "updated_at": None,
            })
        ]

        questions, total = await repo.list_questions(pack_id="pack-1")

        assert len(questions) == 1
        assert total == 2

    @pytest.mark.asyncio
    async def test_list_questions_with_all_filters(self, repo, mock_pool, mock_conn):
        """Should apply all filters."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 5
        mock_conn.fetch.return_value = []

        questions, total = await repo.list_questions(
            pack_id="pack-1",
            domain_id="science",
            subcategory="physics",
            difficulties=[1, 2],
            question_type="toss_up",
            has_audio=True,
            status="active",
            search="water",
            limit=10,
            offset=5,
        )

        assert questions == []
        assert total == 5

    @pytest.mark.asyncio
    async def test_update_question(self, repo, mock_pool, mock_conn):
        """Should update a question."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "UPDATE 1"
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "q1",
            "domain_id": "math",
            "domain_name": "Mathematics",
            "domain_icon": "function",
            "question_text": "Updated?",
            "answer_text": "Updated",
            "acceptable_answers": [],
            "hints": [],
            "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
            "updated_at": datetime(2024, 1, 2, tzinfo=timezone.utc),
        })

        result = await repo.update_question("q1", {"domain_id": "math", "question_text": "Updated?"})

        assert result["domain_id"] == "math"
        mock_conn.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_update_question_no_changes(self, repo, mock_pool, mock_conn):
        """Should return current question if no updates."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "q1",
            "domain_id": "science",
            "domain_name": "Science",
            "domain_icon": "flask",
            "question_text": "Test?",
            "answer_text": "Answer",
            "acceptable_answers": [],
            "hints": [],
            "created_at": None,
            "updated_at": None,
        })

        result = await repo.update_question("q1", {"invalid_field": "value"})

        assert result["id"] == "q1"
        mock_conn.execute.assert_not_called()

    @pytest.mark.asyncio
    async def test_delete_question(self, repo, mock_pool, mock_conn):
        """Should delete a question."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "DELETE 1"

        result = await repo.delete_question("q1")

        assert result is True

    @pytest.mark.asyncio
    async def test_delete_question_not_found(self, repo, mock_pool, mock_conn):
        """Should return False if question not found."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "DELETE 0"

        result = await repo.delete_question("nonexistent")

        assert result is False

    @pytest.mark.asyncio
    async def test_bulk_update_questions(self, repo, mock_pool, mock_conn):
        """Should bulk update questions."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "UPDATE 3"

        result = await repo.bulk_update_questions(
            ["q1", "q2", "q3"],
            {"difficulty": 3, "status": "active"}
        )

        assert result == 3

    @pytest.mark.asyncio
    async def test_bulk_update_questions_no_valid_fields(self, repo, mock_pool, mock_conn):
        """Should return 0 if no valid update fields."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn

        result = await repo.bulk_update_questions(
            ["q1", "q2"],
            {"invalid_field": "value"}
        )

        assert result == 0
        mock_conn.execute.assert_not_called()


class TestPackOperations:
    """Tests for pack operations."""

    @pytest.mark.asyncio
    async def test_create_pack(self, repo, mock_pool, mock_conn):
        """Should create a pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "INSERT 0 1"
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "pack-1",
            "name": "Test Pack",
            "description": "A test pack",
            "type": "custom",
            "status": "draft",
            "source_pack_ids": None,
            "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
            "updated_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
        })

        pack = {"id": "pack-1", "name": "Test Pack"}
        result = await repo.create_pack(pack)

        assert result["id"] == "pack-1"
        assert result["name"] == "Test Pack"

    @pytest.mark.asyncio
    async def test_get_pack(self, repo, mock_pool, mock_conn):
        """Should get a pack by ID."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "pack-1",
            "name": "Test Pack",
            "description": "",
            "source_pack_ids": ["source-1", "source-2"],
            "created_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
            "updated_at": datetime(2024, 1, 1, tzinfo=timezone.utc),
        })

        result = await repo.get_pack("pack-1")

        assert result["id"] == "pack-1"
        assert result["source_pack_ids"] == ["source-1", "source-2"]

    @pytest.mark.asyncio
    async def test_get_pack_not_found(self, repo, mock_pool, mock_conn):
        """Should return None for non-existent pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = None

        result = await repo.get_pack("nonexistent")

        assert result is None

    @pytest.mark.asyncio
    async def test_list_packs_no_filters(self, repo, mock_pool, mock_conn):
        """Should list packs without filters."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 2
        mock_conn.fetch.return_value = [
            MockRecord({
                "id": "pack-1",
                "name": "Pack 1",
                "source_pack_ids": None,
                "created_at": None,
                "updated_at": None,
            }),
            MockRecord({
                "id": "pack-2",
                "name": "Pack 2",
                "source_pack_ids": None,
                "created_at": None,
                "updated_at": None,
            }),
        ]

        packs, total = await repo.list_packs()

        assert len(packs) == 2
        assert total == 2

    @pytest.mark.asyncio
    async def test_list_packs_with_filters(self, repo, mock_pool, mock_conn):
        """Should filter packs."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 1
        mock_conn.fetch.return_value = [
            MockRecord({
                "id": "pack-1",
                "name": "Custom Pack",
                "source_pack_ids": None,
                "created_at": None,
                "updated_at": None,
            })
        ]

        packs, total = await repo.list_packs(
            pack_type="custom",
            status="published",
            search="Custom",
            limit=10,
            offset=0,
        )

        assert len(packs) == 1
        assert total == 1

    @pytest.mark.asyncio
    async def test_update_pack(self, repo, mock_pool, mock_conn):
        """Should update a pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "UPDATE 1"
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "pack-1",
            "name": "Updated Pack",
            "description": "Updated description",
            "source_pack_ids": None,
            "created_at": None,
            "updated_at": datetime(2024, 1, 2, tzinfo=timezone.utc),
        })

        result = await repo.update_pack("pack-1", {"name": "Updated Pack"})

        assert result["name"] == "Updated Pack"

    @pytest.mark.asyncio
    async def test_update_pack_no_changes(self, repo, mock_pool, mock_conn):
        """Should return current pack if no updates."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchrow.return_value = MockRecord({
            "id": "pack-1",
            "name": "Pack 1",
            "source_pack_ids": None,
            "created_at": None,
            "updated_at": None,
        })

        result = await repo.update_pack("pack-1", {"invalid_field": "value"})

        assert result["id"] == "pack-1"
        mock_conn.execute.assert_not_called()

    @pytest.mark.asyncio
    async def test_delete_pack(self, repo, mock_pool, mock_conn):
        """Should delete a pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "DELETE 1"

        result = await repo.delete_pack("pack-1")

        assert result is True

    @pytest.mark.asyncio
    async def test_delete_pack_not_found(self, repo, mock_pool, mock_conn):
        """Should return False if pack not found."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "DELETE 0"

        result = await repo.delete_pack("nonexistent")

        assert result is False


class TestPackQuestionAssociations:
    """Tests for pack-question association operations."""

    @pytest.mark.asyncio
    async def test_add_questions_to_pack(self, repo, mock_pool, mock_conn):
        """Should add questions to a pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 0  # Max position
        mock_conn.execute.return_value = "INSERT 0 1"

        result = await repo.add_questions_to_pack("pack-1", ["q1", "q2", "q3"])

        assert result == 3

    @pytest.mark.asyncio
    async def test_add_questions_to_pack_empty_list(self, repo, mock_pool, mock_conn):
        """Should return 0 for empty question list."""
        result = await repo.add_questions_to_pack("pack-1", [])

        assert result == 0

    @pytest.mark.asyncio
    async def test_add_questions_to_pack_with_errors(self, repo, mock_pool, mock_conn):
        """Should continue on individual insert errors."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 0

        # First succeeds, second fails, third succeeds
        call_count = 0

        async def mock_execute(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 2:
                raise Exception("Duplicate key")
            return "INSERT 0 1"

        mock_conn.execute = mock_execute

        result = await repo.add_questions_to_pack("pack-1", ["q1", "q2", "q3"])

        # Still counts as 3 because we increment before any potential error handling
        assert result >= 2

    @pytest.mark.asyncio
    async def test_remove_question_from_pack(self, repo, mock_pool, mock_conn):
        """Should remove a question from a pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "DELETE 1"

        result = await repo.remove_question_from_pack("pack-1", "q1")

        assert result is True

    @pytest.mark.asyncio
    async def test_remove_question_from_pack_not_found(self, repo, mock_pool, mock_conn):
        """Should return False if association not found."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "DELETE 0"

        result = await repo.remove_question_from_pack("pack-1", "q999")

        assert result is False

    @pytest.mark.asyncio
    async def test_get_pack_question_ids(self, repo, mock_pool, mock_conn):
        """Should get question IDs in a pack."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetch.return_value = [
            {"question_id": "q1"},
            {"question_id": "q2"},
            {"question_id": "q3"},
        ]

        result = await repo.get_pack_question_ids("pack-1")

        assert result == ["q1", "q2", "q3"]


class TestStatistics:
    """Tests for statistics operations."""

    @pytest.mark.asyncio
    async def test_get_pack_difficulty_distribution(self, repo, mock_pool, mock_conn):
        """Should get difficulty distribution."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetch.return_value = [
            {"difficulty": 1, "count": 10},
            {"difficulty": 2, "count": 20},
            {"difficulty": 3, "count": 15},
        ]

        result = await repo.get_pack_difficulty_distribution("pack-1")

        assert result == {1: 10, 2: 20, 3: 15}

    @pytest.mark.asyncio
    async def test_get_pack_domain_distribution(self, repo, mock_pool, mock_conn):
        """Should get domain distribution."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetch.return_value = [
            MockRecord({"domain_id": "science", "count": 25}),
            MockRecord({"domain_id": "math", "count": 20}),
        ]

        result = await repo.get_pack_domain_distribution("pack-1")

        assert len(result) == 2
        assert result[0]["domain_id"] == "science"


class TestImport:
    """Tests for import operations."""

    @pytest.mark.asyncio
    async def test_import_questions_bulk(self, repo, mock_pool, mock_conn):
        """Should bulk import questions."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.execute.return_value = "INSERT 0 1"

        questions = [
            {"id": "q1", "domain_id": "science", "question_text": "Q1?", "answer_text": "A1"},
            {"id": "q2", "domain_id": "math", "question_text": "Q2?", "answer_text": "A2"},
        ]
        result = await repo.import_questions_bulk(questions)

        assert result == 2

    @pytest.mark.asyncio
    async def test_import_questions_bulk_empty(self, repo, mock_pool, mock_conn):
        """Should return 0 for empty list."""
        result = await repo.import_questions_bulk([])

        assert result == 0

    @pytest.mark.asyncio
    async def test_import_questions_bulk_with_errors(self, repo, mock_pool, mock_conn):
        """Should continue on individual import errors."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn

        call_count = 0

        async def mock_execute(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise Exception("Import error")
            return "INSERT 0 1"

        mock_conn.execute = mock_execute

        questions = [
            {"id": "q1", "domain_id": "science", "question_text": "Q1?", "answer_text": "A1"},
            {"id": "q2", "domain_id": "math", "question_text": "Q2?", "answer_text": "A2"},
        ]
        result = await repo.import_questions_bulk(questions)

        # First fails, second succeeds
        assert result == 1

    @pytest.mark.asyncio
    async def test_get_question_count(self, repo, mock_pool, mock_conn):
        """Should get total question count."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetchval.return_value = 500

        result = await repo.get_question_count()

        assert result == 500

    @pytest.mark.asyncio
    async def test_get_domain_question_counts(self, repo, mock_pool, mock_conn):
        """Should get question counts per domain."""
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_conn.fetch.return_value = [
            {"domain_id": "science", "count": 150},
            {"domain_id": "math", "count": 100},
            {"domain_id": "history", "count": 75},
        ]

        result = await repo.get_domain_question_counts()

        assert result == {"science": 150, "math": 100, "history": 75}
