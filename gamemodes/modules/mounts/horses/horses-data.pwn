#define HORSES_LOCI (10)
#define HORSES_GENES_HEX (HORSES_LOCI * 2 + 1)
#define HORSES_PER_CHARACTER (2)
#define HORSES_MUTATION_PERCENT (2)
#define HORSES_STOCK_PER_TRADER (4)
#define HORSES_DAY_MINUTES (1440)
#define HORSES_YEAR_DAYS (360)
#define HORSES_GROWN_DAYS (10)
#define HORSES_YEARLING_DAYS (5)
#define HORSES_GESTATION_DAYS (11)
#define HORSES_GESTATION_NO_GALLOP (8)
#define HORSES_SEASON_CYCLE (12)
#define HORSES_SEASON_DAYS (3)
#define HORSES_STALLION_COVERS (8)
#define HORSES_OLD_YEARS (20)
#define HORSES_LIFE_YEARS (25)
#define HORSES_OLD_DEATH_PERCENT (5)
#define HORSES_PASTURE_FACTOR (0.25)
#define HORSES_HUNGER_DAYS (3.0)
#define HORSES_THIRST_DAYS (2.0)
#define HORSES_STARVE_CONDITION (20.0)
#define HORSES_WINTER_CONDITION (10.0)
#define HORSES_SICK_CONDITION (10.0)
#define HORSES_FED_CONDITION (5.0)
#define HORSES_STABLE_CONDITION (5.0)
#define HORSES_GROOM_CONDITION (10.0)
#define HORSES_OATS (35.0)
#define HORSES_HAY (25.0)
#define HORSES_WATER (60.0)
#define HORSES_HUNGRY_BAND (20.0)
#define HORSES_THIRSTY_BAND (30.0)
#define HORSES_SHOES_LIFE (30000)
#define HORSES_UNSHOD (-1)
#define HORSES_LAME_PER_KM (3)
#define HORSES_LAME_DAYS (2)
#define HORSES_SICK_DAYS (3)
#define HORSES_BOND_TAMED (10)
#define HORSES_BOND_NEW_OWNER (15)
#define HORSES_BOND_RIDE_CAP (6)
#define HORSES_BOND_FEED_CAP (4)
#define HORSES_BOND_FEED (2)
#define HORSES_BOND_GROOM (3)
#define HORSES_BOND_FORCED_CAP (3)
#define HORSES_BOND_STARVING (2)
#define HORSES_BOND_BOLT (2)
#define HORSES_UNTOUCHED_DAYS (10)
#define HORSES_STABLE_FEE (2)
#define HORSES_STABLE_FEE_FED (5)
#define HORSES_STABLE_UNPAID_DAYS (10)
#define HORSES_STABLE_HOLD_DAYS (30)
#define HORSES_STABLE_CAPACITY (12)
#define HORSES_LOST_DAYS (3)
#define HORSES_READING_FEE (30)
#define HORSES_GELDING_FEE (12)
#define HORSES_TREAT_FEE (8)
#define HORSES_GULDEN (240)
#define HORSES_HUD_RANGE (8.0)
#define HORSES_CARE_RANGE (3.0)
#define HORSES_TAME_COOLDOWN_MS (600000)
#define HORSES_TAME_PLAYER_MS (180000)
#define HORSES_WILD_RESPAWN_MS (1200000)
#define HORSES_SPOOK_RANGE (25.0)
#define HORSES_SPOOK_SECONDS (60)
#define HORSES_CALL_COOLDOWN_MS (10000)
#define HORSES_CALL_HOLD_MS (700)
#define HORSES_CALL_SPEED (3.2)
#define HORSES_BOLT_SPEED (5.0)
#define HORSES_LEAD_GAP (3.0)
#define HORSES_LEAD_LOSE (40.0)
#define HORSES_SAVE_MS (300000)
#define HORSES_NAME_LEN (MOUNT_NAME_LEN)
#define HORSES_WORD_LEN (24)

forward Task:Horses_TameDone(playerid,horseid,total);
forward Task:Horses_TellWhere(playerid,characterid);
forward Task:Horses_BuyStock(playerid,stable,slot);
forward bool:Horses_AskText(playerid,const title[],const prompt[],dest[],size);

enum
{
	HORSES_LOCUS_SPD,
	HORSES_LOCUS_STA,
	HORSES_LOCUS_HLT,
	HORSES_LOCUS_TMP,
	HORSES_LOCUS_BASE,
	HORSES_LOCUS_AGOUTI,
	HORSES_LOCUS_GREY,
	HORSES_LOCUS_ROAN,
	HORSES_LOCUS_PATT,
	HORSES_LOCUS_DUN,
}

enum E_HORSES_BREED
{
	HORSES_BREED_WILD,
	HORSES_BREED_DUTCH,
	HORSES_BREED_TENNESSEE,
	HORSES_BREED_APPALOOSA,
	HORSES_BREED_MUSTANG,
	HORSES_BREED_DONKEY,
	HORSES_BREED_MIXED,
	HORSES_BREED_COUNT,
}

enum
{
	HORSES_SEX_MARE,
	HORSES_SEX_STALLION,
	HORSES_SEX_GELDING,
}

enum
{
	HORSES_STATUS_ALIVE,
	HORSES_STATUS_DEAD,
	HORSES_STATUS_SOLD,
}

enum
{
	HORSES_PLACE_WORLD,
	HORSES_PLACE_STABLED,
	HORSES_PLACE_PASTURE,
	HORSES_PLACE_LOST,
}

enum
{
	HORSES_KIND_NONE,
	HORSES_KIND_OWNED,
	HORSES_KIND_WILD,
}

enum
{
	HORSES_TIER_STRANGER,
	HORSES_TIER_WARY,
	HORSES_TIER_FAMILIAR,
	HORSES_TIER_TRUSTING,
	HORSES_TIER_DEVOTED,
}

enum
{
	HORSES_DEATH_AGE,
	HORSES_DEATH_NEGLECT,
	HORSES_DEATH_STAFF,
}

enum
{
	HORSES_EVENT_BORN,
	HORSES_EVENT_TAMED,
	HORSES_EVENT_BOUGHT,
	HORSES_EVENT_SOLD,
	HORSES_EVENT_STABLED,
	HORSES_EVENT_RETRIEVED,
	HORSES_EVENT_COVERED,
	HORSES_EVENT_FOALED,
	HORSES_EVENT_GELDED,
	HORSES_EVENT_READ,
	HORSES_EVENT_STOLEN,
	HORSES_EVENT_INHERITED,
	HORSES_EVENT_DIED,
	HORSES_EVENT_SHOD,
	HORSES_EVENT_SOLD_ON,
}

new const g_HorsesBreedNames[HORSES_BREED_COUNT][HORSES_WORD_LEN] = {
	"Wild", "Dutch Warmblood", "Tennessee Walker", "Chestnut Appaloosa", "Dapple Mustang", "Donkey", "Mixed"
};

new const g_HorsesBreedPrice[HORSES_BREED_COUNT] = {960, 2400, 2160, 1440, 1200, 720, 1200};

new const g_HorsesStatWords[4][3][HORSES_WORD_LEN] = {
	{"Slow", "Steady", "Swift"},
	{"Winded", "Sound", "Tireless"},
	{"Frail", "Healthy", "Hardy"},
	{"Skittish", "Bold", "Steady"}
};

new const g_HorsesStatNames[4][HORSES_WORD_LEN] = {"Speed", "Stamina", "Health", "Temper"};

new const g_HorsesStatLines[4][3][80] = {
	{"Falls behind a common horse on the road.", "Keeps a common horse's pace.", "Outruns most horses on the road."},
	{"Tires early at a gallop.", "Gallops as long as a common horse.", "Gallops a long way before it tires."},
	{"Falls sick easily and feels the cold.", "Stands the weather like most horses.", "Shrugs off cold and sickness and lives longer."},
	{"Gentles easily, but throws often and flees a fight until it trusts you.", "Hard to tame, but never flees a fight once it knows you.", "Easy to tame, rarely throws, holds under fire once it knows you."}
};

new const g_HorsesTierNames[5][HORSES_WORD_LEN] = {"Stranger", "Wary", "Familiar", "Trusting", "Devoted"};
new const Float:g_HorsesTierCall[5] = {30.0, 60.0, 100.0, 150.0, 250.0};
new const g_HorsesSexNames[3][12] = {"mare", "stallion", "gelding"};
new const Float:g_HorsesSpeedTier[3] = {0.94, 1.0, 1.06};
new const g_HorsesStaminaTier[3] = {80, 100, 125};
new const g_HorsesThrowPercent[3] = {25, 15, 8};
new const g_HorsesSickPercent[3] = {30, 15, 5};

new const g_HorsesStatPool[HORSES_BREED_COUNT][4][3] = {
	{{30, 60, 10}, {30, 60, 10}, {25, 65, 10}, {35, 40, 25}},
	{{10, 55, 35}, {5, 45, 50}, {5, 45, 50}, {10, 40, 50}},
	{{5, 45, 50}, {10, 55, 35}, {10, 60, 30}, {10, 30, 60}},
	{{20, 55, 25}, {20, 55, 25}, {20, 55, 25}, {20, 55, 25}},
	{{30, 60, 10}, {20, 55, 25}, {5, 45, 50}, {30, 45, 25}},
	{{60, 40, 0}, {0, 40, 60}, {10, 50, 40}, {10, 30, 60}},
	{{20, 55, 25}, {20, 55, 25}, {20, 55, 25}, {20, 55, 25}}
};

new const g_HorsesCoatPool[HORSES_BREED_COUNT][5] = {
	{55, 5, 5, 5, 15},
	{70, 10, 0, 0, 0},
	{60, 5, 15, 10, 5},
	{30, 0, 5, 35, 5},
	{55, 25, 10, 10, 20},
	{50, 0, 0, 0, 0},
	{55, 8, 7, 10, 10}
};

new const g_HorsesAgoutiPool[HORSES_BREED_COUNT][3] = {
	{40, 25, 35}, {50, 30, 20}, {30, 20, 50}, {40, 20, 40}, {40, 20, 40}, {34, 33, 33}, {38, 24, 38}
};
