#define ORDERS_MAX (60)
#define ORDERS_PER_GIVER (3)
#define ORDERS_LIFE_DAYS (2)
#define ORDERS_TAKEN_MAX (3)
#define ORDERS_DAILY_DELIVERIES (6)
#define ORDERS_PAY_PERCENT (75)
#define ORDERS_REACH (4.0)
#define ORDERS_GOODWILL_MAX (30)
#define ORDERS_GOODWILL_SLOTS (16)
#define ORDERS_TEXT_LEN (64)
#define ORDERS_PANEL_WIDTH (420.0)
#define ORDERS_BOARD_ROWS (9)
#define ORDERS_CONTRACTS_MAX (40)
#define ORDERS_CONTRACT_DAYS (4)
#define ORDERS_CONTRACT_PAY_MAX (2400)
#define ORDERS_CONTRACT_QTY_MAX (40)
#define ORDERS_LEDGER_MAX (8)
#define ORDERS_SUGGEST_MAX (4)
#define ORDERS_LEDGER_LEN (80)
#define ORDERS_TRIAL_NEEDED (3)
#define ORDERS_TRIAL_STARS (3)
#define ORDERS_TRIAL_LEVEL (5)
#define ORDERS_DUTY_GOODWILL (2)
#define ORDERS_DUTY_PAY_PERCENT (25)
#define ORDERS_BONUS_STARS (2)
#define ORDERS_PICK_TAKE (1000)
#define ORDERS_PICK_DELIVER (2000)
#define ORDERS_PICK_DUTY (3000)
#define ORDERS_PICK_CONTRACT (4000)
#define ORDERS_PICK_GOAL (5000)
#define ORDERS_PICK_SUGGEST (6000)
#define ORDERS_PICK_POST (7000)
#define ORDERS_PICK_WRITE (7001)
#define ORDERS_PICK_WARRANT (7002)
#define ORDERS_PICK_NEXT (7003)
#define ORDERS_PICK_PREV (7004)
#define ORDERS_SEASONS_ALL (15)
#define ORDERS_SEASON(%0) (1 << _:(%0))

enum _:E_ORDER_GIVERS
{
	ORDER_GIVER_INNKEEPER,
	ORDER_GIVER_PRIEST,
	ORDER_GIVER_YARD,
	ORDER_GIVER_REEVE,
	ORDER_GIVER_BAILIFF,
	ORDER_GIVER_HERDER,
	ORDER_GIVER_COUNT,
}

new const E_ACTOR_ROLE:g_OrderGiverRoles[ORDER_GIVER_COUNT] = {ACTOR_ROLE_INNKEEPER, ACTOR_ROLE_PRIEST, ACTOR_ROLE_YARD_MASTER, ACTOR_ROLE_REEVE, ACTOR_ROLE_BAILIFF, ACTOR_ROLE_HERDER};
new const g_OrderGiverNames[ORDER_GIVER_COUNT][16] = {"innkeeper", "priest", "yard master", "reeve", "bailiff", "herdsman"};

new const g_OrderGiverCaps[ORDER_GIVER_COUNT] = {2, 1, 3, 1, 1, 1};

enum E_ORDER_DEF
{
	E_ORDER_DEF_GIVER,
	E_ORDER_DEF_ITEM,
	E_ORDER_DEF_QTY_MIN,
	E_ORDER_DEF_QTY_MAX,
	E_ORDER_DEF_STARS,
	E_ORDER_DEF_SEASONS,
	E_ORDER_DEF_GOODWILL,
	E_ORDER_DEF_TEXT[48],
}

new const g_OrderDefs[][E_ORDER_DEF] = {
	{ORDER_GIVER_INNKEEPER, ITEM_BREAD, 4, 8, 1, ORDERS_SEASONS_ALL, 0, "%d loaves for the common table"},
	{ORDER_GIVER_INNKEEPER, ITEM_FIREWOOD, 4, 8, 1, ORDERS_SEASONS_ALL, 0, "%d bundles of firewood for the hearth"},
	{ORDER_GIVER_INNKEEPER, ITEM_CABBAGE, 3, 6, 1, ORDERS_SEASON(SEASON_SUMMER) | ORDERS_SEASON(SEASON_AUTUMN), 0, "%d cabbages for the pottage"},
	{ORDER_GIVER_INNKEEPER, ITEM_ONION, 3, 6, 1, ORDERS_SEASON(SEASON_SUMMER) | ORDERS_SEASON(SEASON_AUTUMN), 0, "%d onions for the stew"},
	{ORDER_GIVER_INNKEEPER, ITEM_TURNIP, 3, 6, 1, ORDERS_SEASON(SEASON_AUTUMN) | ORDERS_SEASON(SEASON_WINTER), 0, "%d turnips for the stew pot"},
	{ORDER_GIVER_INNKEEPER, ITEM_FISH, 3, 5, 1, ORDERS_SEASONS_ALL & ~ORDERS_SEASON(SEASON_WINTER), 0, "%d fish for a fast day"},
	{ORDER_GIVER_INNKEEPER, ITEM_EGGS, 4, 8, 1, ORDERS_SEASON(SEASON_SPRING) | ORDERS_SEASON(SEASON_SUMMER), 0, "%d eggs for the kitchen"},
	{ORDER_GIVER_INNKEEPER, ITEM_MEAT_PORK, 2, 4, 2, ORDERS_SEASONS_ALL, 2, "%d cuts of pork, two stars or better"},
	{ORDER_GIVER_INNKEEPER, ITEM_CHEESE, 2, 3, 2, ORDERS_SEASONS_ALL, 3, "%d cheeses for travellers"},
	{ORDER_GIVER_INNKEEPER, ITEM_BARREL_ALE, 1, 1, 3, ORDERS_SEASONS_ALL, 6, "a barrel of good ale"},
	{ORDER_GIVER_PRIEST, ITEM_CANDLE, 3, 6, 1, ORDERS_SEASONS_ALL, 0, "%d candles for the altar"},
	{ORDER_GIVER_PRIEST, ITEM_WAX, 2, 4, 1, ORDERS_SEASONS_ALL, 0, "%d cakes of wax for the chandler"},
	{ORDER_GIVER_PRIEST, ITEM_HERBS, 2, 5, 1, ORDERS_SEASONS_ALL & ~ORDERS_SEASON(SEASON_WINTER), 0, "%d bunches of herbs for the infirmary"},
	{ORDER_GIVER_PRIEST, ITEM_BREAD, 2, 4, 1, ORDERS_SEASONS_ALL, 0, "%d loaves for the poor"},
	{ORDER_GIVER_PRIEST, ITEM_HONEY, 1, 2, 2, ORDERS_SEASON(SEASON_SUMMER) | ORDERS_SEASON(SEASON_AUTUMN), 2, "%d jars of honey for the brothers"},
	{ORDER_GIVER_PRIEST, ITEM_CANDLE_WAX, 2, 4, 2, ORDERS_SEASONS_ALL, 3, "%d beeswax candles for the high altar"},
	{ORDER_GIVER_YARD, ITEM_CHARCOAL, 6, 10, 2, ORDERS_SEASONS_ALL, 0, "%d sacks of charcoal, two stars or better"},
	{ORDER_GIVER_YARD, ITEM_IRON_ORE, 4, 8, 1, ORDERS_SEASONS_ALL, 0, "%d baskets of iron ore"},
	{ORDER_GIVER_YARD, ITEM_CLAY, 4, 8, 1, ORDERS_SEASONS_ALL & ~ORDERS_SEASON(SEASON_WINTER), 0, "%d loads of clay"},
	{ORDER_GIVER_YARD, ITEM_PLANK, 4, 8, 1, ORDERS_SEASONS_ALL, 0, "%d planks for the benches"},
	{ORDER_GIVER_YARD, ITEM_HIDE_COW, 1, 3, 1, ORDERS_SEASONS_ALL, 0, "%d cow hides for the tanner"},
	{ORDER_GIVER_YARD, ITEM_LEATHER, 1, 2, 2, ORDERS_SEASONS_ALL, 3, "%d pieces of leather, two stars or better"},
	{ORDER_GIVER_YARD, ITEM_IRON_BAR, 1, 3, 3, ORDERS_SEASONS_ALL, 5, "%d iron bars, three stars or better"},
	{ORDER_GIVER_REEVE, ITEM_SEED, 3, 6, 1, ORDERS_SEASON(SEASON_SPRING), 0, "%d bags of seed corn for the strips"},
	{ORDER_GIVER_REEVE, ITEM_PLANK, 3, 6, 1, ORDERS_SEASONS_ALL, 0, "%d planks to mend the fences"},
	{ORDER_GIVER_REEVE, ITEM_ROPE, 1, 3, 1, ORDERS_SEASONS_ALL, 0, "%d lengths of rope for the well"},
	{ORDER_GIVER_REEVE, ITEM_STONE_BLOCK, 3, 6, 1, ORDERS_SEASON(SEASON_SPRING) | ORDERS_SEASON(SEASON_SUMMER), 0, "%d stone blocks to mend the well"},
	{ORDER_GIVER_REEVE, ITEM_STRAW, 4, 8, 1, ORDERS_SEASON(SEASON_SUMMER) | ORDERS_SEASON(SEASON_AUTUMN), 0, "%d bundles of straw for the scarecrows"},
	{ORDER_GIVER_REEVE, ITEM_WHEAT, 4, 8, 1, ORDERS_SEASON(SEASON_AUTUMN), 0, "%d sacks of wheat for the demesne barn"},
	{ORDER_GIVER_BAILIFF, ITEM_RYE, 4, 8, 1, ORDERS_SEASON(SEASON_AUTUMN) | ORDERS_SEASON(SEASON_WINTER), 0, "%d sacks of rye for the castle"},
	{ORDER_GIVER_BAILIFF, ITEM_LOG_SOFTWOOD, 4, 8, 1, ORDERS_SEASONS_ALL, 0, "%d logs for the castle works"},
	{ORDER_GIVER_BAILIFF, ITEM_LOG_OAK, 2, 4, 2, ORDERS_SEASONS_ALL, 2, "%d oak logs, two stars or better"},
	{ORDER_GIVER_BAILIFF, ITEM_STONE_BLOCK, 4, 8, 1, ORDERS_SEASONS_ALL, 0, "%d stone blocks for the road"},
	{ORDER_GIVER_BAILIFF, ITEM_CHARCOAL, 4, 8, 1, ORDERS_SEASON(SEASON_WINTER), 0, "%d sacks of charcoal for the guardroom"},
	{ORDER_GIVER_BAILIFF, ITEM_SALT, 2, 4, 1, ORDERS_SEASON(SEASON_AUTUMN) | ORDERS_SEASON(SEASON_WINTER), 0, "%d measures of salt for the larder"},
	{ORDER_GIVER_BAILIFF, ITEM_CURED_MEAT, 2, 4, 2, ORDERS_SEASON(SEASON_WINTER), 2, "%d sides of cured meat for the garrison"},
	{ORDER_GIVER_HERDER, ITEM_HAY, 4, 8, 1, ORDERS_SEASONS_ALL & ~ORDERS_SEASON(SEASON_SPRING), 0, "%d bales of hay for the herd"},
	{ORDER_GIVER_HERDER, ITEM_OATS_FEED, 2, 4, 1, ORDERS_SEASON(SEASON_WINTER), 0, "%d sacks of feed oats"}
};

enum E_ORDER_DUTY_DEF
{
	E_ORDER_DUTY_DEF_SEASON,
	E_ORDER_DUTY_DEF_GIVER,
	E_ORDER_DUTY_DEF_ITEM,
	E_ORDER_DUTY_DEF_QTY,
	bool:E_ORDER_DUTY_DEF_FULL_MOON,
	bool:E_ORDER_DUTY_DEF_OWED,
	bool:E_ORDER_DUTY_DEF_FEAST,
	E_ORDER_DUTY_DEF_TEXT[48],
}

new const g_OrderDutyDefs[][E_ORDER_DUTY_DEF] = {
	{_:SEASON_SPRING, ORDER_GIVER_REEVE, ITEM_SEED, 4, false, false, false, "seed corn to sow the demesne strips"},
	{_:SEASON_SPRING, ORDER_GIVER_REEVE, ITEM_PLANK, 4, false, false, false, "planks for the demesne fences"},
	{_:SEASON_SUMMER, ORDER_GIVER_HERDER, ITEM_HAY, 6, false, false, false, "hay for the common herd"},
	{_:SEASON_SUMMER, ORDER_GIVER_PRIEST, ITEM_HERBS, 3, true, false, false, "herbs gathered under the full moon"},
	{_:SEASON_AUTUMN, ORDER_GIVER_REEVE, ITEM_WHEAT, 6, false, false, false, "your days on the demesne harvest"},
	{_:SEASON_AUTUMN, ORDER_GIVER_PRIEST, ITEM_WHEAT, 2, false, true, false, "the tithe of your harvest"},
	{_:SEASON_WINTER, ORDER_GIVER_PRIEST, ITEM_FIREWOOD, 6, false, false, false, "firewood for the chapel"},
	{_:SEASON_WINTER, ORDER_GIVER_BAILIFF, ITEM_FIREWOOD, 4, false, false, false, "firewood for the gaol"},
	{_:SEASON_WINTER, ORDER_GIVER_BAILIFF, ITEM_CURED_MEAT, 2, false, false, false, "food laid in for the castle"},
	{-1, ORDER_GIVER_PRIEST, ITEM_BREAD, 2, false, false, true, "bread for the feast"}
};

enum _:E_ORDER_DUTY_STATES
{
	ORDER_DUTY_OPEN,
	ORDER_DUTY_DONE,
	ORDER_DUTY_MISSED,
	ORDER_DUTY_OWED,
	ORDER_DUTY_PAID_LATE,
}

enum _:E_ORDER_RESULTS
{
	ORDER_OK,
	ORDER_GONE,
	ORDER_TAKEN,
	ORDER_TOO_MANY,
	ORDER_GOODWILL,
	ORDER_NOT_YOURS,
	ORDER_MISSING_GOODS,
	ORDER_TOO_FAR,
	ORDER_DAILY_CAP,
	ORDER_PURSE,
	ORDER_GIVER_DEAD,
	ORDER_NOT_NOW,
	ORDER_DONE_ALREADY,
	ORDER_NO_COIN,
	ORDER_NO_BOARD,
	ORDER_BAD_INPUT,
}

new const g_OrderResultTexts[][72] = {
	"",
	"That order is gone.",
	"Someone else has taken that order.",
	"You already carry three orders. Deliver or drop one first.",
	"They don't know you well enough for that one yet.",
	"That isn't your order.",
	"You don't have enough of it at the stars asked.",
	"Hand it over in person: go to them.",
	"That's enough deliveries for one day. Come back tomorrow.",
	"The county can't pay for that just now.",
	"They can't take anything from you now.",
	"That isn't asked of you now.",
	"You've already done that this season.",
	"You don't have the coin for that.",
	"Do that at a notice board.",
	"That can't be posted as written."
};

enum _:E_CONTRACT_STATES
{
	CONTRACT_OPEN,
	CONTRACT_TAKEN,
	CONTRACT_DONE,
	CONTRACT_CANCELLED,
}
