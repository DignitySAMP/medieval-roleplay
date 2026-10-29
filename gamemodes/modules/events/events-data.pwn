#define EVENTS_MAX (4)
#define EVENTS_ENTRIES (16)
#define EVENTS_BETS (64)
#define EVENTS_TICK_MS (250)
#define EVENTS_MINUTE_MS (60000)
#define EVENTS_CALL_MS (60000)
#define EVENTS_LISTS_RANGE (35.0)
#define EVENTS_LINE_RANGE (5.0)
#define EVENTS_PASS_MS (3000)
#define EVENTS_PASS_GAP_MS (4000)
#define EVENTS_PASSES (3)
#define EVENTS_WRESTLE_MS (60000)
#define EVENTS_FIGHT_POINTS (20)
#define EVENTS_ARMED_BLOW (3)
#define EVENTS_RING_GRACE_MS (3000)
#define EVENTS_YIELD_MS (3000)
#define EVENTS_STAND_DOWN_MS (4500)
#define EVENTS_MARK_X (1.5)
#define EVENTS_MARK_Y (3.0)
#define EVENTS_LISTS_HALF_LENGTH (18.5)
#define EVENTS_LISTS_HALF_WIDTH (6.5)
#define EVENTS_BLOCK_CONE_BARE (60.0)
#define EVENTS_BLOCK_CONE_SHIELD (80.0)
#define EVENTS_MELEE_MS (120000)
#define EVENTS_ARCHERY_MS (45000)
#define EVENTS_ARROWS (3)
#define EVENTS_TOSS_MS (20000)
#define EVENTS_DRINK_MS (20000)
#define EVENTS_DRINK_ROUNDS (12)
#define EVENTS_BAR_PERIOD (1600)
#define EVENTS_BAR_GOOD (85.0)
#define EVENTS_BAR_CLEAN (96.0)
#define EVENTS_HOUSE_CUT (10)
#define EVENTS_FAIR_MINUTES (300)
#define EVENTS_CROWD (6)
#define EVENTS_CROWD_KIND (WALKERS_KIND_ACTOR)
#define EVENTS_FAIR_BUY_PERCENT (120)
#define EVENTS_PANEL_WIDTH (300.0)
#define EVENTS_NOTICE_DAYS (2)

enum _:E_EVENT_KINDS
{
	EVENT_TOURNAMENT,
	EVENT_FAIR,
	EVENT_FESTIVAL,
	EVENT_KIND_COUNT,
}

new const g_EventKindNames[EVENT_KIND_COUNT][16] = {"tournament", "fair", "festival"};

enum _:E_EVENT_STATES
{
	EVENT_OPEN,
	EVENT_RUNNING,
	EVENT_DONE,
}

enum _:E_CONTEST_KINDS
{
	CONTEST_JOUST,
	CONTEST_ARCHERY,
	CONTEST_MELEE,
	CONTEST_WRESTLING,
	CONTEST_LOG_TOSS,
	CONTEST_DRINKING,
	CONTEST_PRODUCE,
	CONTEST_COUNT,
}

enum E_CONTEST_DEF
{
	E_CONTEST_DEF_KEY[12],
	E_CONTEST_DEF_NAME[24],
	bool:E_CONTEST_DEF_BOUTS,
	E_CONTEST_DEF_TROPHY,
	E_CONTEST_DEF_CALL[96],
}

new const g_ContestDefs[CONTEST_COUNT][E_CONTEST_DEF] = {
	{"joust", "the joust", true, ITEM_CIRCLET, "mounted, with a lance, at either end of the tilt"},
	{"archery", "the archery", false, ITEM_GOLDEN_ARROW, "at the archers' line with a bow"},
	{"melee", "the sword bout", true, ITEM_CIRCLET, "to the ring, armed: the weapons are blunted"},
	{"wrestling", "the wrestling", true, -1, "to the ring, bare-handed"},
	{"logtoss", "the log toss", false, -1, "at the archers' line"},
	{"drinking", "the drinking match", false, -1, "at the lists, thirsty"},
	{"produce", "the best produce", false, -1, "with your best produce"}
};
