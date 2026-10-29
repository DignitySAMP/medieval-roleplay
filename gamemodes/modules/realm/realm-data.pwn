#define REALM_COUNTY (1)
#define REALM_VACANT_DAYS (7)
#define REALM_LEVY_COIN_PERCENT (20)
#define REALM_LEVY_GRAIN_PERCENT (10)
#define REALM_VILLAGES (3)
#define REALM_KEY_LEN (32)
#define REALM_DECREES_MAX (24)
#define REALM_DECREE_TEXT (144)

enum
{
	REALM_POLICY_SALES_TAX,
	REALM_POLICY_STRIP_RENT,
	REALM_POLICY_TITHE,
	REALM_POLICY_PETITION_CRAFT,
	REALM_POLICY_PETITION_HIGH,
	REALM_POLICY_STALL_FEE,
	REALM_POLICY_MULTURE,
	REALM_POLICY_LICENCE,
	REALM_POLICY_LAND_TAX,
	REALM_POLICY_WOLF_BOUNTY,
	REALM_POLICY_CURFEW,
	REALM_POLICY_LIGHT_LAW,
	REALM_POLICY_FINE_SCALE,
	REALM_POLICY_PILLORY_MINUTES,
	REALM_POLICY_WEAPONS,
	REALM_POLICY_SUMPTUARY,
	REALM_POLICY_TOLL,
	REALM_POLICY_BANISHMENT,
	REALM_POLICY_PROTECTED,
	REALM_POLICY_CLOSED_SEASONS,
	REALM_POLICY_COUNT,
}

enum
{
	REALM_GROUP_MONEY,
	REALM_GROUP_RIGHTS,
	REALM_GROUP_LAW,
	REALM_GROUP_SOCIETY,
	REALM_GROUP_COUNT,
}

enum E_REALM_POLICY_DEF
{
	E_RP_KEY[REALM_KEY_LEN],
	E_RP_NAME[40],
	E_RP_GROUP,
	E_RP_DEFAULT,
	E_RP_MIN,
	E_RP_MAX,
	E_RP_STEP,
	E_RP_UNIT[20],
}

new const g_RealmPolicyDefs[REALM_POLICY_COUNT][E_REALM_POLICY_DEF] = {
	{"sales_tax", "Sales tax on till sales", REALM_GROUP_MONEY, 10, 0, 25, 1, "percent"},
	{"strip_rent", "Strip rent a season", REALM_GROUP_MONEY, 72, 0, 240, 12, "pfennig"},
	{"tithe", "Harvest tithe", REALM_GROUP_MONEY, 10, 0, 20, 1, "percent"},
	{"petition_craft", "Petition fee, craftsman", REALM_GROUP_MONEY, 12, 0, 60, 6, "pfennig"},
	{"petition_high", "Petition fee, higher rungs", REALM_GROUP_MONEY, 60, 0, 240, 12, "pfennig"},
	{"stall_fee", "Market stall a day", REALM_GROUP_MONEY, 24, 0, 120, 6, "pfennig"},
	{"multure", "Mill multure", REALM_GROUP_MONEY, 62, 0, 125, 31, "per thousand"},
	{"licence", "Licence a season (hunt, wood, mine)", REALM_GROUP_RIGHTS, 120, 0, 480, 12, "pfennig"},
	{"land_tax", "Land tax a year on owned houses", REALM_GROUP_MONEY, 240, 0, 1200, 24, "pfennig"},
	{"wolf_bounty", "Wolf bounty a pelt", REALM_GROUP_RIGHTS, 6, 0, 48, 1, "pfennig"},
	{"curfew", "Night curfew", REALM_GROUP_SOCIETY, 0, 0, 1, 1, "off/on"},
	{"light_law", "Light law: carry a light at night", REALM_GROUP_SOCIETY, 0, 0, 1, 1, "off/on"},
	{"fine_scale", "Fines, against the base table", REALM_GROUP_LAW, 100, 50, 300, 10, "percent"},
	{"pillory_minutes", "Pillory length", REALM_GROUP_LAW, 15, 5, 60, 5, "minutes"},
	{"weapons", "Weapons in town", REALM_GROUP_SOCIETY, 0, 0, 2, 1, "open/sheathed/none"},
	{"sumptuary", "Dyes and furs for the nobility only", REALM_GROUP_SOCIETY, 0, 0, 1, 1, "off/on"},
	{"toll", "Road toll", REALM_GROUP_MONEY, 1, 0, 12, 1, "pfennig"},
	{"banishment", "Banishment for serious crimes", REALM_GROUP_LAW, 0, 0, 1, 1, "off/on"},
	{"protected", "Protected species and trees", REALM_GROUP_RIGHTS, 0, 0, 255, 1, "flags"},
	{"closed_seasons", "Closed hunting seasons", REALM_GROUP_RIGHTS, 0, 0, 15, 1, "flags"}
};

enum
{
	REALM_DECREE_FEAST,
	REALM_DECREE_CLOSED_SEASON,
	REALM_DECREE_BOUNTY,
	REALM_DECREE_BAN,
	REALM_DECREE_CALL_TO_ARMS,
	REALM_DECREE_KINDS,
}

new const g_RealmDecreeNames[REALM_DECREE_KINDS][20] = {"A feast day", "A closed season", "A bounty", "A ban", "A call to arms"};

new const g_RealmVillageKeys[REALM_VILLAGES][16] = {"talmberg", "church", "guardhouse"};
new const g_RealmVillageNames[REALM_VILLAGES][28] = {"Talmberg", "the church village", "the guardhouse hamlet"};
new const Float:g_RealmVillagePos[REALM_VILLAGES][3] = {{1007.0, -3403.5, 65.67}, {1005.0, -3155.0, 34.0}, {716.8, -3189.0, 22.7}};
