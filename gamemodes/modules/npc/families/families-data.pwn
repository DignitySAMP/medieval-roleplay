#define FAMILY_KEY_PREFIX "fam:"
#define FAMILY_OUTDOOR_RANGE (150.0)
#define FAMILY_DOOR_RANGE (60.0)
#define FAMILY_SPREAD (1.8)
#define FAMILY_GATHER_GAP (1.5)
#define FAMILY_SPOT_GROUND_UP (1.0)
#define FAMILY_SPOT_GROUND_DOWN (2.0)
#define FAMILY_TICK_MS (1000)
#define FAMILY_GREET_COOLDOWN (300)
#define FAMILY_MEAL_MINUTES (120)
#define FAMILY_MEAL_WINDOW (15)
#define FAMILY_SEAT_SETTLE_MS (500)
#define FAMILY_SEAT_READY_POLL_MS (200)
#define FAMILY_SIT_LIB ("INT_OFFICE")
#define FAMILY_SIT_ANIM ("OFF_Sit_Idle_Loop")
#define FAMILY_BITE_ANIM ("OFF_Sit_Drink")
#define FAMILY_SIT_ROOT_DROP (0.4033)
#define FAMILY_SEAT_NUDGE (0.05)
#define FAMILY_SEAT_NUDGE_MS (400)
#define FAMILY_MEAL_JITTER (12)
#define FAMILY_STAGE_MINUTES (40)
#define FAMILY_GRACE_LATE (30)
#define FAMILY_TALK_MIN (20)
#define FAMILY_TALK_MAX (30)
#define FAMILY_GRACE_DELAY (12)
#define FAMILY_SEAT_REACH (1.6)
#define FAMILY_SEAT_ANYWHERE (50.0)
#define FAMILY_MEAL_COIN (2)
#define FAMILY_ASK_COOLDOWN (3)
#define FAMILY_FAVOUR_MIN (-100)
#define FAMILY_FAVOUR_MAX (100)
#define FAMILY_FAVOUR_NAME (15)
#define FAMILY_FAVOUR_FREE_MEAL (20)
#define FAMILY_FAVOUR_EAT_ALL (3)
#define FAMILY_FAVOUR_RUDE (2)
#define FAMILY_FAVOUR_NEIGHBOUR (2)
#define FAMILY_ERRAND_COOLDOWN (21600)
#define FAMILY_WELL_FED_SECONDS (1800)
#define FAMILY_WELL_FED_TOPUP (1)
#define FAMILY_WELL_FED_EVERY (150)
#define FAMILY_STORES_FULL (100)
#define FAMILY_STORES_MEAGRE (30)
#define FAMILY_GUESTS_MAX (4)
#define FAMILY_INVITES_MAX (6)
#define FAMILY_PANEL_WIDTH (210.0)
#define FAMILY_SEAT_KEY_PRIO (KEYS_PRIO_MENU + 2)
#define FAMILY_TEXT_CHAR_WIDTH (3.5)
#define FAMILY_TEXT_LINE (11.0)
#define FAMILY_PLATE_REACH (0.5)
#define FAMILY_PLATE_REACH_SEATED (0.6)
#define FAMILY_SEAT_TABLE_TOP (0.31)
#define FAMILY_CENTRE_SPREAD (0.35)
#define FAMILY_WEEK_SUNDAY (0)
#define FAMILY_WEEK_FRIDAY (5)
#define FAMILY_WEEK_MARKET (6)
#define FAMILY_PROMPT_MS (500)
#define FAMILY_PED_Z (1.0)
#define FAMILY_SEAT_PED_Z (0.55)
#define FAMILY_SEAT_BACK (0.12)
#define FAMILY_SPOT_RANGE (1.0)
#define FAMILY_SPOT_RANGE_SEATED (0.4)
#define FAMILY_BED_PED_Z (FAMILY_PED_Z)

enum E_FAMILY_PLACE
{
	FAMILY_PLACE_YARD,
	FAMILY_PLACE_DOORSTEP,
	FAMILY_PLACE_FIELD,
	FAMILY_PLACE_SQUARE,
	FAMILY_PLACE_MARKET,
	FAMILY_PLACE_CHURCH,
	FAMILY_PLACE_FOREST,
	FAMILY_PLACE_WATER,
	FAMILY_PLACE_HOME,
	FAMILY_PLACE_TABLE,
	FAMILY_PLACE_BED,
	FAMILY_PLACE_NONE,
}

#define FAMILY_OUTDOOR_PLACES (8)

#define FAMILY_AGE_CHILD (0)
#define FAMILY_AGE_YOUTH (1)
#define FAMILY_AGE_ADULT (2)
#define FAMILY_AGE_ELDER (3)

new const g_FamilyBoySkins[] = {20024, 20025};
new const g_FamilyGirlSkins[] = {20026, 20027};
new const g_FamilySmallBoySkins[] = {20088, 20089};
new const g_FamilySmallGirlSkins[] = {20090, 20091};
new const g_FamilyOldManSkins[] = {20013, 20040, 20009};
new const g_FamilyOldWomanSkins[] = {20092, 20085, 20093, 20094};
new const g_FamilyYouthManSkins[] = {20159, 20002, 20014, 20015, 20028, 20033, 20034, 20043, 20045, 20120};
new const g_FamilyYouthWomanSkins[] = {20080, 20081, 20083, 20084, 20086, 20087, 20117};

new const g_FamilyChildSeatLift[][2] = {
	{20024, 12},
	{20025, 15},
	{20026, 16},
	{20027, 16},
	{20088, 27},
	{20089, 30},
	{20090, 28},
	{20091, 32}
};

new const g_FamilyPlaceNames[E_FAMILY_PLACE][12] = {
	"yard",
	"doorstep",
	"field",
	"square",
	"market",
	"church",
	"forest",
	"water",
	"home",
	"table",
	"bed",
	"none"
};

enum E_FAMILY_ACT
{
	FAMILY_ACT_STAND,
	FAMILY_ACT_TEND,
	FAMILY_ACT_CHORE,
	FAMILY_ACT_HEARTH,
	FAMILY_ACT_WORK,
	FAMILY_ACT_SELL,
	FAMILY_ACT_PRAY,
	FAMILY_ACT_SIT,
	FAMILY_ACT_PLAY,
	FAMILY_ACT_FISH,
	FAMILY_ACT_WINDOW,
	FAMILY_ACT_REST,
	FAMILY_ACT_EAT,
	FAMILY_ACT_SLEEP,
	FAMILY_ACT_SPIN,
	FAMILY_ACT_WASH,
	FAMILY_ACT_DRAW,
	FAMILY_ACT_CHAT,
	FAMILY_ACT_DRINK,
	FAMILY_ACT_COUNT,
}

new const g_FamilyActAnims[FAMILY_ACT_COUNT][2][20] = {
	{"PED", "IDLE_chat"},
	{"COP_AMBIENT", "Copbrowse_loop"},
	{"COP_AMBIENT", "Copbrowse_loop"},
	{"INT_HOUSE", "wash_up"},
	{"COP_AMBIENT", "Copbrowse_loop"},
	{"BAR", "Barserve_loop"},
	{"CAMERA", "CAMCRCH_IDLELOOP"},
	{"BEACH", "ParkSit_M_loop"},
	{"PED", "IDLE_chat"},
	{"SAMP", "FishingIdle"},
	{"GANGS", "leanIDLE"},
	{"BEACH", "ParkSit_W_loop"},
	{"INT_OFFICE", "OFF_Sit_Idle_Loop"},
	{"INT_HOUSE", "BED_Loop_R"},
	{"BEACH", "ParkSit_W_loop"},
	{"BD_FIRE", "wash_up"},
	{"BOMBER", "BOM_Plant_Loop"},
	{"PED", "IDLE_chat"},
	{"BAR", "dnk_stndM_loop"}
};

stock bool:Families_GetActivityAnimation(E_FAMILY_ACT:act,library[],librarySize,name[],nameSize)
{
    if (act < FAMILY_ACT_STAND || act >= FAMILY_ACT_COUNT)
    {
        library[0] = EOS;
        name[0] = EOS;
        return false;
    }

    strcopy(library,g_FamilyActAnims[act][0],librarySize);
    strcopy(name,g_FamilyActAnims[act][1],nameSize);
    return library[0] != EOS && name[0] != EOS;
}

new const g_FamilyActSpots[FAMILY_ACT_COUNT][8] = {
	"chore",
	"chore",
	"chore",
	"hearth",
	"work",
	"work",
	"prayer",
	"rest",
	"chore",
	"chore",
	"window",
	"rest",
	"",
	"",
	"rest",
	"chore",
	"chore",
	"chore",
	"chore"
};

#define FAMILY_KEYFRAMES (6)
#define FAMILY_ROLES (16)

#define FAMILY_DISH_GROUPS (28)
#define FAMILY_PLATE_GROUPS (14)

enum E_FAMILY_DISH
{
	E_FAMILY_DISH_NAME[28],
	E_FAMILY_DISH_HUNGER,
	E_FAMILY_DISH_THIRST,
}

new const g_FamilyDishes[FAMILY_DISH_GROUPS][E_FAMILY_DISH] = {
	{"Pottage", 30, 5},
	{"Pottage and bread", 35, 5},
	{"Porridge", 30, 5},
	{"Stew", 40, 5},
	{"Fish stew", 35, 5},
	{"Meat on a trencher", 40, 0},
	{"Fish on a trencher", 35, 0},
	{"Sausages and kraut", 35, 0},
	{"Eggs and greens", 25, 0},
	{"Fowl", 40, 0},
	{"Cheese and bread", 25, 0},
	{"A slice of pie", 35, 0},
	{"Roast on pewter", 45, 0},
	{"Sweetmeats", 20, 0},
	{"Rye bread", 15, 0},
	{"White bread", 15, 0},
	{"Bread rings", 15, 0},
	{"Pottage from the pot", 20, 5},
	{"Cheese from the wheel", 15, 0},
	{"Roast joint", 25, 0},
	{"Roast fowl", 25, 0},
	{"Fish from the platter", 20, 0},
	{"Sausage from the board", 20, 0},
	{"Meat pie", 25, 0},
	{"Fruit tart", 15, 5},
	{"Honey cakes", 10, 0},
	{"Nuts and apples", 10, 5},
	{"Ale", 0, 35}
};

#define FAMILY_DISH_POTTAGE_BOWL (0)
#define FAMILY_DISH_POTTAGE_BREAD (1)
#define FAMILY_DISH_STEW_BOWL (3)
#define FAMILY_DISH_FISH_STEW (4)
#define FAMILY_DISH_TRENCHER_MEAT (5)
#define FAMILY_DISH_TRENCHER_FISH (6)
#define FAMILY_DISH_PLATE_SAUSAGE (7)
#define FAMILY_DISH_PLATE_EGG (8)
#define FAMILY_DISH_PLATE_FOWL (9)
#define FAMILY_DISH_PLATE_PIE (11)
#define FAMILY_DISH_PEWTER_ROAST (12)
#define FAMILY_DISH_RYE_LOAF (14)
#define FAMILY_DISH_WHEAT_LOAF (15)
#define FAMILY_DISH_ROAST_JOINT (19)
#define FAMILY_DISH_ROAST_FOWL (20)
#define FAMILY_DISH_FISH_PLATTER (21)
#define FAMILY_DISH_SAUSAGE_BOARD (22)
#define FAMILY_DISH_MEAT_PIE (23)
#define FAMILY_DISH_FRUIT_TART (24)
#define FAMILY_DISH_HONEY_CAKES (25)
#define FAMILY_DISH_NUTS_APPLES (26)

enum E_FAMILY_MEAL
{
	FAMILY_MEAL_DINNER,
	FAMILY_MEAL_SUPPER,
}

#define FAMILY_BITES (6)
#define FAMILY_BEAT_GAP_MS (2600)
#define FAMILY_LINE_GAP_MS (3600)
#define FAMILY_CAMERA_MS (1800)

enum E_FAMILY_GUEST_STATE
{
	FAMILY_GUEST_WAITING,
	FAMILY_GUEST_READY,
	FAMILY_GUEST_TALKING,
	FAMILY_GUEST_DONE,
}

enum E_FAMILY_REACTION
{
	E_FAMILY_REACTION_TEXT[32],
	E_FAMILY_REACTION_FAVOUR,
	E_FAMILY_REACTION_REPLY[64],
}

new const g_FamilyReactions[3][E_FAMILY_REACTION] = {
	{"Nod along", 0, ""},
	{"Ask them to say more", 1, "You'd think so, wouldn't you? That's how it is."},
	{"Change the subject", -1, "As you like."}
};

forward bool:Families_IsMealOn(family);
forward bool:Families_IsInvited(family,characterid);
forward bool:Families_IsSeatTaken(family,seat);
forward bool:Families_IsEating(member);
forward E_FAMILY_PLACE:Families_GetPlace(member);
forward E_FAMILY_MEAL:Families_GetMealKind(family);
