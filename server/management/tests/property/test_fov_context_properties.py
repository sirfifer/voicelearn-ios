"""
Property-based tests for FOV Context Models.

Tests invariants that should always hold:
- Budget sums never exceed total budget
- Tier classification is deterministic and follows ordering
- Token budgets maintain tier hierarchy (CLOUD > MID_RANGE > ON_DEVICE > TINY)
- Model configuration lookups always return valid configs
"""

import pytest
from hypothesis import given, strategies as st, assume, example

from fov_context.models import (
    ModelTier,
    TokenBudgets,
    AdaptiveBudgetConfig,
    MODEL_CONTEXT_WINDOWS,
    ConversationTurn,
    MessageRole,
    TopicSummary,
    ImmediateBuffer,
    WorkingBuffer,
    EpisodicBuffer,
    SemanticBuffer,
    FOVContext,
    LearnerSignals,
)


# --- Property Tests: ModelTier ---

class TestModelTierProperties:
    """Property tests for ModelTier classification."""

    @given(st.integers(min_value=0, max_value=1_000_000))
    def test_from_context_window_is_idempotent(self, context_window: int):
        """Same context window should always produce same tier."""
        tier1 = ModelTier.from_context_window(context_window)
        tier2 = ModelTier.from_context_window(context_window)
        assert tier1 == tier2

    @given(st.integers(min_value=0, max_value=1_000_000))
    def test_from_context_window_returns_valid_tier(self, context_window: int):
        """Should always return a valid ModelTier enum value."""
        tier = ModelTier.from_context_window(context_window)
        assert tier in ModelTier
        assert isinstance(tier, ModelTier)

    @given(st.integers(min_value=100_000, max_value=1_000_000))
    def test_large_context_is_cloud(self, context_window: int):
        """Context windows >= 100K should be CLOUD tier."""
        tier = ModelTier.from_context_window(context_window)
        assert tier == ModelTier.CLOUD

    @given(st.integers(min_value=32_000, max_value=99_999))
    def test_medium_context_is_midrange(self, context_window: int):
        """Context windows 32K-100K should be MID_RANGE tier."""
        tier = ModelTier.from_context_window(context_window)
        assert tier == ModelTier.MID_RANGE

    @given(st.integers(min_value=8_000, max_value=31_999))
    def test_small_context_is_ondevice(self, context_window: int):
        """Context windows 8K-32K should be ON_DEVICE tier."""
        tier = ModelTier.from_context_window(context_window)
        assert tier == ModelTier.ON_DEVICE

    @given(st.integers(min_value=0, max_value=7_999))
    def test_tiny_context_is_tiny(self, context_window: int):
        """Context windows <8K should be TINY tier."""
        tier = ModelTier.from_context_window(context_window)
        assert tier == ModelTier.TINY

    # Boundary tests with explicit examples
    @example(99_999)
    @example(100_000)
    @example(31_999)
    @example(32_000)
    @example(7_999)
    @example(8_000)
    @given(st.integers(min_value=0, max_value=200_000))
    def test_tier_boundaries_are_consistent(self, context_window: int):
        """Tier boundaries should follow documented thresholds."""
        tier = ModelTier.from_context_window(context_window)

        if context_window >= 100_000:
            assert tier == ModelTier.CLOUD
        elif context_window >= 32_000:
            assert tier == ModelTier.MID_RANGE
        elif context_window >= 8_000:
            assert tier == ModelTier.ON_DEVICE
        else:
            assert tier == ModelTier.TINY


# --- Property Tests: TokenBudgets ---

class TestTokenBudgetsProperties:
    """Property tests for TokenBudgets."""

    @given(st.sampled_from(list(ModelTier)))
    def test_budget_sum_does_not_exceed_total(self, tier: ModelTier):
        """Sum of component budgets should not exceed total."""
        budgets = TokenBudgets.for_tier(tier)

        component_sum = (
            budgets.immediate +
            budgets.working +
            budgets.episodic +
            budgets.semantic
        )

        assert component_sum <= budgets.total, (
            f"Budget sum {component_sum} exceeds total {budgets.total} for {tier}"
        )

    @given(st.sampled_from(list(ModelTier)))
    def test_all_budgets_are_positive(self, tier: ModelTier):
        """All budget values should be positive."""
        budgets = TokenBudgets.for_tier(tier)

        assert budgets.immediate > 0, "Immediate budget should be positive"
        assert budgets.working > 0, "Working budget should be positive"
        assert budgets.episodic > 0, "Episodic budget should be positive"
        assert budgets.semantic > 0, "Semantic budget should be positive"
        assert budgets.total > 0, "Total budget should be positive"

    def test_tier_ordering_for_budgets(self):
        """Higher tiers should have larger or equal budgets."""
        cloud = TokenBudgets.for_tier(ModelTier.CLOUD)
        mid = TokenBudgets.for_tier(ModelTier.MID_RANGE)
        device = TokenBudgets.for_tier(ModelTier.ON_DEVICE)
        tiny = TokenBudgets.for_tier(ModelTier.TINY)

        # Total should follow tier ordering
        assert cloud.total >= mid.total >= device.total >= tiny.total, (
            "Total budgets should follow tier ordering"
        )

        # Immediate should follow tier ordering
        assert cloud.immediate >= mid.immediate >= device.immediate >= tiny.immediate, (
            "Immediate budgets should follow tier ordering"
        )

        # Working should follow tier ordering
        assert cloud.working >= mid.working >= device.working >= tiny.working, (
            "Working budgets should follow tier ordering"
        )

    @given(st.sampled_from(list(ModelTier)))
    def test_for_tier_is_idempotent(self, tier: ModelTier):
        """Same tier should always return same budgets."""
        budgets1 = TokenBudgets.for_tier(tier)
        budgets2 = TokenBudgets.for_tier(tier)

        assert budgets1.total == budgets2.total
        assert budgets1.immediate == budgets2.immediate
        assert budgets1.working == budgets2.working
        assert budgets1.episodic == budgets2.episodic
        assert budgets1.semantic == budgets2.semantic


# --- Property Tests: AdaptiveBudgetConfig ---

class TestAdaptiveBudgetConfigProperties:
    """Property tests for AdaptiveBudgetConfig."""

    @given(st.integers(min_value=1000, max_value=500_000))
    def test_from_context_window_produces_valid_config(self, context_window: int):
        """Config should always be valid for any context window."""
        config = AdaptiveBudgetConfig.from_context_window(context_window)

        assert config.tier in ModelTier
        assert config.budgets is not None
        assert config.max_conversation_turns > 0
        assert config.model_context_window == context_window

    @given(st.integers(min_value=1000, max_value=500_000))
    def test_from_context_window_is_idempotent(self, context_window: int):
        """Same context window should produce identical config."""
        config1 = AdaptiveBudgetConfig.from_context_window(context_window)
        config2 = AdaptiveBudgetConfig.from_context_window(context_window)

        assert config1.tier == config2.tier
        assert config1.max_conversation_turns == config2.max_conversation_turns
        assert config1.budgets.total == config2.budgets.total

    @given(st.integers(min_value=1000, max_value=500_000))
    def test_max_turns_follows_tier_ordering(self, context_window: int):
        """Higher tiers should allow more conversation turns."""
        config = AdaptiveBudgetConfig.from_context_window(context_window)

        tier_max_turns = {
            ModelTier.CLOUD: 20,
            ModelTier.MID_RANGE: 12,
            ModelTier.ON_DEVICE: 6,
            ModelTier.TINY: 3,
        }

        expected_turns = tier_max_turns[config.tier]
        assert config.max_conversation_turns == expected_turns

    def test_all_known_models_have_valid_configs(self):
        """All models in MODEL_CONTEXT_WINDOWS should produce valid configs."""
        for model_name, context_window in MODEL_CONTEXT_WINDOWS.items():
            config = AdaptiveBudgetConfig.for_model(model_name)

            assert config.tier in ModelTier, f"Invalid tier for {model_name}"
            assert config.budgets.total > 0, f"Invalid budget for {model_name}"
            assert config.max_conversation_turns > 0, f"Invalid turns for {model_name}"

    @given(st.text(min_size=1, max_size=100))
    def test_unknown_model_gets_default_config(self, unknown_model: str):
        """Unknown models should get a reasonable default config."""
        assume(unknown_model not in MODEL_CONTEXT_WINDOWS)

        config = AdaptiveBudgetConfig.for_model(unknown_model)

        # Should get default 32K context window behavior
        assert config.tier == ModelTier.MID_RANGE
        assert config.model_context_window == 32_000


# --- Property Tests: ConversationTurn ---

class TestConversationTurnProperties:
    """Property tests for ConversationTurn."""

    @given(st.text(min_size=0, max_size=10000))
    def test_token_estimate_is_non_negative(self, content: str):
        """Token estimate should always be non-negative."""
        turn = ConversationTurn(content=content)
        assert turn.token_estimate >= 0

    @given(st.text(min_size=1, max_size=10000))
    def test_token_estimate_scales_with_content(self, content: str):
        """Longer content should generally have higher token estimates."""
        turn = ConversationTurn(content=content)

        # Rough check: estimate should be within reasonable range
        # Upper bound: 1 token per char (worst case)
        max_expected = len(content)

        assert turn.token_estimate >= 0
        assert turn.token_estimate <= max_expected

    @given(st.sampled_from(list(MessageRole)))
    def test_all_roles_create_valid_turns(self, role: MessageRole):
        """All message roles should create valid turns."""
        turn = ConversationTurn(role=role, content="Test")

        assert turn.role == role
        assert turn.content == "Test"
        assert turn.id is not None


# --- Property Tests: TopicSummary ---

class TestTopicSummaryProperties:
    """Property tests for TopicSummary mastery levels."""

    @given(st.floats(min_value=0.0, max_value=1.0, allow_nan=False))
    def test_mastery_level_bounds(self, mastery: float):
        """Mastery level should stay within bounds when set correctly."""
        summary = TopicSummary(
            topic_id="test-topic",
            title="Test Topic",
            summary="A test summary",
            mastery_level=mastery,
        )

        assert 0.0 <= summary.mastery_level <= 1.0


# --- Property Tests: Buffer Rendering ---

class TestBufferRenderingProperties:
    """Property tests for buffer rendering within token budgets."""

    @given(st.integers(min_value=10, max_value=10000))
    def test_immediate_buffer_respects_budget(self, budget: int):
        """Immediate buffer rendering should respect token budget."""
        buffer = ImmediateBuffer(
            recent_turns=[
                ConversationTurn(content="Hello " * 100),
                ConversationTurn(content="World " * 100),
            ],
            barge_in_utterance="Interruption " * 50,
        )

        rendered = buffer.render(token_budget=budget)

        # Rough token estimate (4 chars per token)
        estimated_tokens = len(rendered) // 4
        # Allow some slack for truncation boundary
        assert estimated_tokens <= budget + 10, (
            f"Rendered {estimated_tokens} tokens exceeds budget {budget}"
        )

    @given(st.integers(min_value=10, max_value=10000))
    def test_working_buffer_respects_budget(self, budget: int):
        """Working buffer rendering should respect token budget."""
        buffer = WorkingBuffer(
            topic_title="Test Topic " * 10,
            topic_content="Content " * 500,
            learning_objectives=["Objective " * 20 for _ in range(5)],
        )

        rendered = buffer.render(token_budget=budget)
        estimated_tokens = len(rendered) // 4

        assert estimated_tokens <= budget + 10

    @given(st.integers(min_value=10, max_value=10000))
    def test_episodic_buffer_respects_budget(self, budget: int):
        """Episodic buffer rendering should respect token budget."""
        buffer = EpisodicBuffer(
            topic_summaries=[
                TopicSummary(
                    topic_id=f"topic-{i}",
                    title=f"Topic {i} " * 10,
                    summary="Summary " * 50,
                    mastery_level=0.8,
                )
                for i in range(10)
            ],
            user_questions=["Question " * 20 for _ in range(5)],
        )

        rendered = buffer.render(token_budget=budget)
        estimated_tokens = len(rendered) // 4

        assert estimated_tokens <= budget + 10

    @given(st.integers(min_value=10, max_value=10000))
    def test_semantic_buffer_respects_budget(self, budget: int):
        """Semantic buffer rendering should respect token budget."""
        buffer = SemanticBuffer(
            curriculum_outline="Outline " * 200,
            prerequisite_topics=["Prereq " * 10 for _ in range(5)],
            upcoming_topics=["Upcoming " * 10 for _ in range(5)],
        )

        rendered = buffer.render(token_budget=budget)
        estimated_tokens = len(rendered) // 4

        assert estimated_tokens <= budget + 10


# --- Property Tests: FOVContext ---

class TestFOVContextProperties:
    """Property tests for complete FOV context."""

    @given(
        st.text(min_size=1, max_size=1000),  # system_prompt
        st.text(max_size=500),  # immediate
        st.text(max_size=500),  # working
        st.text(max_size=500),  # episodic
        st.text(max_size=500),  # semantic
    )
    def test_token_estimate_is_reasonable(
        self, system_prompt, immediate, working, episodic, semantic
    ):
        """Token estimate should be reasonable based on content length."""
        context = FOVContext(
            system_prompt=system_prompt,
            immediate_context=immediate,
            working_context=working,
            episodic_context=episodic,
            semantic_context=semantic,
        )

        total_chars = (
            len(system_prompt) + len(immediate) +
            len(working) + len(episodic) + len(semantic)
        )

        # Token estimate should be roughly total_chars / 4
        # Allow 50% variance for calculation differences
        expected_min = total_chars // 8
        expected_max = total_chars

        assert context.total_token_estimate >= expected_min
        assert context.total_token_estimate <= expected_max

    @given(
        st.text(min_size=1, max_size=100),
        st.text(max_size=100),
        st.text(max_size=100),
        st.text(max_size=100),
        st.text(max_size=100),
    )
    def test_to_system_message_includes_prompt(
        self, system_prompt, immediate, working, episodic, semantic
    ):
        """System message should always include the system prompt."""
        context = FOVContext(
            system_prompt=system_prompt,
            immediate_context=immediate,
            working_context=working,
            episodic_context=episodic,
            semantic_context=semantic,
        )

        message = context.to_system_message()

        assert system_prompt in message

    @given(
        st.text(min_size=1, max_size=100),
        st.text(max_size=100),
        st.text(max_size=100),
        st.text(max_size=100),
        st.text(max_size=100),
    )
    def test_to_messages_returns_valid_format(
        self, system_prompt, immediate, working, episodic, semantic
    ):
        """to_messages should return valid LLM message format."""
        context = FOVContext(
            system_prompt=system_prompt,
            immediate_context=immediate,
            working_context=working,
            episodic_context=episodic,
            semantic_context=semantic,
        )

        messages = context.to_messages()

        assert isinstance(messages, list)
        assert len(messages) == 1
        assert messages[0]["role"] == "system"
        assert "content" in messages[0]


# --- Property Tests: LearnerSignals ---

class TestLearnerSignalsProperties:
    """Property tests for LearnerSignals tracking."""

    @given(
        st.integers(min_value=0, max_value=1000),
        st.integers(min_value=0, max_value=1000),
        st.integers(min_value=0, max_value=1000),
    )
    def test_signal_counts_stay_non_negative(
        self, clarifications, repetitions, confusion
    ):
        """All signal counters should stay non-negative."""
        signals = LearnerSignals(
            clarification_requests=clarifications,
            repetition_requests=repetitions,
            confusion_indicators=confusion,
        )

        assert signals.clarification_requests >= 0
        assert signals.repetition_requests >= 0
        assert signals.confusion_indicators >= 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
