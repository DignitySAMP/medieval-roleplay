#define GROUPS_MAX (48)
#define GROUP_INVALID (-1)
#define GROUPS_NAME_LEN (32)
#define GROUPS_RANKS (6)
#define GROUPS_RANK_NAME_LEN (20)
#define GROUPS_PER_CHARACTER (3)
#define GROUPS_REVIEW_MEMBERS (8)
#define GROUPS_GUILD_FOUNDERS (3)
#define GROUPS_GUILD_CAP (20)
#define GROUPS_CAP (30)
#define GROUPS_ROLL_MAX (64)
#define GROUPS_GUILD_LEVEL (4)
#define GROUPS_CHARTER_FEE (240)
#define GROUPS_BAND_FEE (120)
#define GROUPS_NEAR (6.0)
#define GROUPS_SEAT_REACH (4.0)
#define GROUPS_HALL_REACH (2.5)
#define GROUPS_PANEL_WIDTH (300.0)
#define GROUPS_TICK_MS (500)
#define GROUPS_TRAIN_MS (5000)
#define GROUPS_TRAIN_PERCENT (25)
#define GROUPS_TRAIN_RANGE (15.0)
#define GROUPS_TRAIN_MASTER_LEVEL (8)
#define GROUPS_MARK_PERCENT (15)
#define GROUPS_MASTER_VOTES (2)
#define GROUPS_MASTERPIECE_STARS (5)
#define GROUPS_BOARD_SHOWN (8)
#define GROUPS_NOTICE_LEN (144)
#define GROUPS_TERMS_LEN (128)
#define GROUPS_KIT_LINES (4)
#define GROUPS_ISSUED_MAX (8)
#define GROUPS_LIVERY_SLOT (ATTACH_SLOT_HEAD)
#define GROUPS_HIDEOUT_REACH (4.0)
#define GROUPS_HIDEOUT_CLEAR (8.0)
#define GROUPS_HIDEOUT_FIRE_LIT (-3001)
#define GROUPS_HIDEOUT_FIRE_COLD (MODEL_LIGHT_BONFIRE_ASH)
#define GROUPS_HIDEOUT_STREAM (150.0)
#define GROUPS_CHAT_COLOUR (0x9FD3A8FF)
#define GROUPS_CRIER_DAYS (3)

enum _:E_GROUP_KINDS
{
	GROUP_KIND_GUILD,
	GROUP_KIND_HOUSEHOLD,
	GROUP_KIND_MERCENARY,
	GROUP_KIND_OUTLAW,
	GROUP_KIND_ORDER,
	GROUP_KIND_GUARD,
	GROUP_KIND_CHURCH,
	GROUP_KIND_COUNT,
}

new const g_GroupKindNames[GROUP_KIND_COUNT][20] = {"Craft guild", "Household", "Mercenary band", "Outlaw band", "Religious order", "County guard", "The church"};

#define GROUP_FEATURE_DUTY (1)
#define GROUP_FEATURE_UNIFORM (2)
#define GROUP_FEATURE_ARMOURY (4)
#define GROUP_FEATURE_HALL (8)
#define GROUP_FEATURE_SPAWN (16)
#define GROUP_FEATURE_BOARD (32)
#define GROUP_FEATURE_CHARTER (64)
#define GROUP_FEATURE_CONTRACTS (128)
#define GROUP_FEATURE_COUNT (8)

new const g_GroupFeatureNames[GROUP_FEATURE_COUNT][24] = {"Duty", "Uniform", "Armoury", "Hall", "Spawn at the hall", "Notice board", "Charter rules", "Contracts"};

new const g_GroupKindFeatures[GROUP_KIND_COUNT] = {
	GROUP_FEATURE_CHARTER,
	0,
	GROUP_FEATURE_CONTRACTS,
	GROUP_FEATURE_HALL,
	GROUP_FEATURE_UNIFORM,
	GROUP_FEATURE_HALL | GROUP_FEATURE_BOARD,
	GROUP_FEATURE_HALL | GROUP_FEATURE_BOARD
};

#define GROUP_PERM_INVITE (1)
#define GROUP_PERM_EXPEL (2)
#define GROUP_PERM_RANKS (4)
#define GROUP_PERM_TREASURY (8)
#define GROUP_PERM_STORE (16)
#define GROUP_PERM_CONTRACTS (32)
#define GROUP_PERM_BOARD (64)
#define GROUP_PERM_HALL (128)
#define GROUP_PERM_JUDGE (256)
#define GROUP_PERM_COUNT (9)
#define GROUP_PERM_ALL (511)

new const g_GroupPermNames[GROUP_PERM_COUNT][20] = {"Invite", "Expel", "Set ranks", "Treasury", "Storehouse", "Contracts", "Notice board", "Hall and armoury", "Judge masterpieces"};

new const g_GroupDefaultPerms[GROUPS_RANKS] = {
	GROUP_PERM_ALL,
	GROUP_PERM_INVITE | GROUP_PERM_EXPEL | GROUP_PERM_STORE | GROUP_PERM_BOARD | GROUP_PERM_CONTRACTS | GROUP_PERM_JUDGE,
	GROUP_PERM_STORE | GROUP_PERM_BOARD,
	0,
	0,
	0
};

new const g_GroupDefaultRanks[GROUP_KIND_COUNT][GROUPS_RANKS][GROUPS_RANK_NAME_LEN] = {
	{"Guildmaster", "Master", "Journeyman", "Apprentice", "", ""},
	{"Lord", "Knight", "Retainer", "Servant", "", ""},
	{"Captain", "Sergeant", "Sworn sword", "Recruit", "", ""},
	{"Chief", "Lieutenant", "Outlaw", "Lookout", "", ""},
	{"Master of the order", "Prior", "Brother", "Novice", "", ""},
	{"Sergeant", "Guard", "Watchman", "", "", ""},
	{"Abbot", "Prior", "Priest", "Deacon", "Brother", "Lay brother"}
};

#define GROUPS_LIVERY_COUNT (8)

new const g_GroupLiveryColours[GROUPS_LIVERY_COUNT] = {0xFFA8322D, 0xFFD9A62E, 0xFF35548C, 0xFF3F6B3A, 0xFF2A2624, 0xFFE8E2D2, 0xFF6A3B78, 0xFF7A5A3A};
new const g_GroupLiveryNames[GROUPS_LIVERY_COUNT][16] = {"madder red", "weld yellow", "woad blue", "green", "black", "white", "purple", "russet"};

enum _:E_GROUP_CONTRACT_STATE
{
	GROUP_CONTRACT_OFFERED,
	GROUP_CONTRACT_SIGNED,
	GROUP_CONTRACT_FULFILLED,
	GROUP_CONTRACT_DISPUTED,
	GROUP_CONTRACT_CANCELLED,
	GROUP_CONTRACT_STATES,
}

new const g_GroupContractStates[GROUP_CONTRACT_STATES][12] = {"offered", "signed", "fulfilled", "disputed", "released"};

enum _:E_GROUP_PIECE_STATE
{
	GROUP_PIECE_PENDING,
	GROUP_PIECE_PASSED,
	GROUP_PIECE_FAILED,
}

new const g_GroupFoundFees[GROUP_KIND_COUNT] = {GROUPS_CHARTER_FEE, 0, GROUPS_BAND_FEE, 0, 0, 0, 0};
new const g_GroupFoundersNeeded[GROUP_KIND_COUNT] = {GROUPS_GUILD_FOUNDERS, 1, 1, 1, 1, 1, 1};
