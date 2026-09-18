"""Pillar 1: Dynamic Difficulty Adaptation.

A UCB1 Multi-Armed Bandit picks which difficulty "arm" (grid size) to serve
next, balancing exploration of new challenge levels against exploiting what's
been working. `next_difficulty` layers the ARCHITECTURE.md threshold rules
(timer/distractor changes) on top of the arm the bandit recommends.
"""
import math
from dataclasses import dataclass
from typing import List

from app.config import settings

GRID_LADDER = ["3x2", "3x3", "4x3", "4x4"]


@dataclass
class Arm:
    key: str
    pulls: int
    total_reward: float

    @property
    def mean_reward(self) -> float:
        return self.total_reward / self.pulls if self.pulls else 0.0


def select_arm(arms: List[Arm]) -> str:
    """UCB1: try every arm once, then pick mean_reward + exploration bonus."""
    if not arms:
        return GRID_LADDER[0]

    for a in arms:
        if a.pulls == 0:
            return a.key

    total_pulls = sum(a.pulls for a in arms)

    def ucb_score(a: Arm) -> float:
        return a.mean_reward + math.sqrt(2 * math.log(total_pulls) / a.pulls)

    return max(arms, key=ucb_score).key


def performance_score(accuracy: float, avg_latency_norm: float, error_rate: float) -> float:
    """S = w1*Accuracy - w2*AvgLatency - w3*ErrorRate (latency pre-normalized to 0..1)."""
    return (
        settings.W1_ACCURACY * accuracy
        - settings.W2_LATENCY * avg_latency_norm
        - settings.W3_ERROR_RATE * error_rate
    )


def next_difficulty(current_grid: str, score: float, distractors_on: bool) -> dict:
    """Threshold execution: S < T_low -> shrink grid / lengthen timer;
    S > T_high -> grow grid / add distractors."""
    idx = GRID_LADDER.index(current_grid) if current_grid in GRID_LADDER else 0
    timer_multiplier = 1.0

    if score < settings.S_LOW_THRESHOLD:
        idx = max(0, idx - 1)
        distractors_on = False
        timer_multiplier = 1.25
    elif score > settings.S_HIGH_THRESHOLD:
        idx = min(len(GRID_LADDER) - 1, idx + 1)
        distractors_on = True

    return {
        "grid_size": GRID_LADDER[idx],
        "distractors_enabled": distractors_on,
        "timer_multiplier": timer_multiplier,
    }
