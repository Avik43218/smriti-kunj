"""Glue between the sync ingestion endpoint and the Pillar 1 bandit engine."""
from app.core.bandit import GRID_LADDER, Arm, select_arm
from app.models.analytics import BanditArmState


async def update_bandit(patient_id, game_type: str, arm_key: str, reward: float) -> None:
    state = await BanditArmState.find_one(
        BanditArmState.patient_id == patient_id,
        BanditArmState.game_type == game_type,
        BanditArmState.arm_key == arm_key,
    )
    if not state:
        state = BanditArmState(patient_id=patient_id, game_type=game_type, arm_key=arm_key)
    state.pulls += 1
    state.total_reward += reward
    await state.save()


async def recommend_difficulty(patient_id, game_type: str) -> str:
    states = await BanditArmState.find(
        BanditArmState.patient_id == patient_id,
        BanditArmState.game_type == game_type,
    ).to_list()
    if not states:
        return GRID_LADDER[0]  # cold start: easiest arm
    arms = [Arm(key=s.arm_key, pulls=s.pulls, total_reward=s.total_reward) for s in states]
    return select_arm(arms)
