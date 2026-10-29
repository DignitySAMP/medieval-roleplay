#define FIRE_TICK_MS (5000)
#define FIRE_PROMPT_MS (500)
#define FIRE_START_HEAT (20)
#define FIRE_SPREAD_HEAT (15)
#define FIRE_BURNING_AT (40)
#define FIRE_ROARING_AT (80)
#define FIRE_HEAT_MAX (100)
#define FIRE_GUT_TICKS (12)
#define FIRE_GROWTH (3)
#define FIRE_GROWTH_DRY (2)
#define FIRE_SPREAD_RANGE (16.0)
#define FIRE_SPREAD_AT (60)
#define FIRE_SPREAD_PERCENT (8)
#define FIRE_THROW (9)
#define FIRE_CHAIN_BONUS (4)
#define FIRE_CHAIN_MS (4000)
#define FIRE_CHAIN_MAX (3)
#define FIRE_THROW_REACH (9.0)
#define FIRE_DOOR_REACH (3.0)
#define FIRE_BURN_DAMAGE (4.0)
#define FIRE_SMOKE_DAMAGE (2.0)
#define FIRE_SMOKE_RANGE (14.0)
#define FIRE_COUGH_PERCENT (20)
#define FIRE_ALARM_RANGE (300.0)
#define FIRE_HEARTH_ODDS (14000)
#define FIRE_TORCH_PERCENT (25)
#define FIRE_TORCH_REACH (5.0)
#define FIRE_REBUILD_FEE (240)
#define FIRE_REBUILD_FEE_STABLE (120)
#define FIRE_FILL_MS (2500)
#define FIRE_STREAM (240.0)
#define FIRE_CRIER_KIND "fire"
#define FIRE_ALARM_TITLE "Fire!"
#define FIRE_EMITTER_LIFT (1.611)
#define FIRE_FLAME_SEEK (1.5)
#define FIRE_FLAME_DROP (5.5)
#define FIRE_FLAME_THATCH (0.5)
#define FIRE_FLAMES_BURNING (4)
#define FIRE_FLAMES (8)
#define FIRE_MEDIUM_MODEL (18688)
#define FIRE_LARGE_MODEL (18691)
#define FIRE_BLAZE_ALONG (2.2)
#define FIRE_RIDGE_PROBE (1.5)
#define FIRE_GLOW_LIFT (2.5)
#define FIRE_SLOT_BLAZE (1 + FIRE_FLAMES)
#define FIRE_SLOT_GLOW (FIRE_SLOT_BLAZE + 3)
#define FIRE_SMOKE_MODEL (18727)
#define FIRE_RUIN_MODEL (18726)
#define FIRE_OBJECTS (FIRE_SLOT_GLOW + 1)

enum _:E_FIRE_STATES
{
	FIRE_STATE_SOUND,
	FIRE_STATE_SMOKING,
	FIRE_STATE_BURNING,
	FIRE_STATE_GUTTED,
	FIRE_STATE_COUNT,
}

new const g_FireStateNames[FIRE_STATE_COUNT][12] = {"sound", "smoking", "burning", "gutted"};

enum _:E_FIRE_CAUSES
{
	FIRE_CAUSE_HEARTH,
	FIRE_CAUSE_TORCH,
	FIRE_CAUSE_LIGHTNING,
	FIRE_CAUSE_ARSON,
	FIRE_CAUSE_STAFF,
	FIRE_CAUSE_SPREAD,
	FIRE_CAUSE_COUNT,
}

new const g_FireCauseNames[FIRE_CAUSE_COUNT][24] = {"an unwatched hearth", "a dropped torch", "lightning", "arson", "the staff", "sparks from next door"};

new const Float:g_FireFlameSpots[FIRE_FLAMES][2] = {
	{1.4, 0.6},
	{-1.2, -0.8},
	{0.3, -1.3},
	{-0.4, 1.2},
	{2.4, -0.4},
	{-2.3, 0.5},
	{0.9, 2.0},
	{-1.0, -2.1}
};
