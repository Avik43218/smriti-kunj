"""Pure-logic tests for the 3 pillars' algorithms — no DB/network needed."""
from app.core.bandit import Arm, next_difficulty, performance_score, select_arm
from app.core.drift import compute_drift, detect_anomaly
from app.core.nlu import classify


def test_select_arm_prefers_unplayed():
    arms = [Arm("3x2", 5, 4.0), Arm("4x4", 0, 0.0)]
    assert select_arm(arms) == "4x4"


def test_select_arm_ucb_balances_explore_exploit():
    arms = [Arm("3x2", 20, 18.0), Arm("4x4", 20, 10.0)]
    assert select_arm(arms) == "3x2"


def test_performance_score_penalizes_latency_and_errors():
    high = performance_score(accuracy=0.95, avg_latency_norm=0.1, error_rate=0.05)
    low = performance_score(accuracy=0.5, avg_latency_norm=0.9, error_rate=0.4)
    assert high > low


def test_next_difficulty_shrinks_grid_on_low_score():
    result = next_difficulty(current_grid="4x3", score=0.1, distractors_on=True)
    assert result["grid_size"] == "3x3"
    assert result["distractors_enabled"] is False


def test_next_difficulty_grows_grid_on_high_score():
    result = next_difficulty(current_grid="3x2", score=0.95, distractors_on=False)
    assert result["grid_size"] == "3x3"
    assert result["distractors_enabled"] is True


def test_compute_drift_detects_decline():
    declining_scores = [0.9, 0.85, 0.8, 0.7, 0.6, 0.5]
    result = compute_drift(declining_scores)
    assert result.slope < 0
    assert result.declining is True


def test_compute_drift_stable_scores_not_declining():
    stable_scores = [0.7, 0.72, 0.69, 0.71, 0.70]
    result = compute_drift(stable_scores)
    assert result.declining is False


def test_detect_anomaly_flags_accuracy_drop():
    is_anomaly, message = detect_anomaly(
        baseline_accuracy=0.8, todays_accuracy=0.5,
        baseline_std=50, todays_hesitation=1000, baseline_hesitation=950,
    )
    assert is_anomaly is True
    assert "accuracy" in message.lower()


def test_classify_extracts_medication_entities():
    result = classify("I took my medicine at 09:00")
    assert result["entities"]["Task"] == "medication"
    assert result["entities"]["Status"] == "complete"
    assert result["entities"]["Time"] == "09:00"
