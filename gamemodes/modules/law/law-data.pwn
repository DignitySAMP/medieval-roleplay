#define LAW_COUNTY (1)
#define LAW_WITNESS_DAY (30.0)
#define LAW_WITNESS_DARK (12.0)
#define LAW_EYE_Z (0.7)
#define LAW_DAY_SECONDS (86400)
#define LAW_BOUNTY_FACTOR (2)
#define LAW_BOUNTY_CAP (4800)
#define LAW_REPEAT_SECONDS (300)
#define LAW_DESCRIPTION_LEN (96)
#define LAW_NAME_LEN (32)
#define LAW_VERB_LEN (40)
#define LAW_TICK_MS (1000)
#define LAW_PROMPT_MS (500)
#define LAW_SAVE_SECONDS (30)
#define LAW_REACH (2.0)
#define LAW_GAOL_OFFLINE_PERCENT (50)
#define LAW_CRIER_KIND "law"
#define LAW_PANEL_WIDTH (260.0)
#define LAW_FLOG_HEALTH (30.0)
#define LAW_FLOG_FLOOR (15.0)

#define GAOL_WORLD (7090)
#define GAOL_INTERIOR (1)

#define LAW_DEVICE_PILLORY (0)
#define LAW_DEVICE_STOCKS (1)

enum
{
	LAW_CRIME_MURDER,
	LAW_CRIME_ASSAULT,
	LAW_CRIME_THEFT,
	LAW_CRIME_POACHING,
	LAW_CRIME_POISONING,
	LAW_CRIME_DECREE,
	LAW_CRIME_TRESPASS,
	LAW_CRIME_FREEING,
	LAW_CRIME_BRIBERY,
	LAW_CRIME_ESCAPE,
	LAW_CRIME_ARSON,
	LAW_CRIME_DARKNESS,
	LAW_CRIME_TOLL,
	LAW_CRIME_COUNT,
}

enum
{
	LAW_SENTENCE_NONE,
	LAW_SENTENCE_FINE,
	LAW_SENTENCE_PILLORY,
	LAW_SENTENCE_STOCKS,
	LAW_SENTENCE_GAOL,
	LAW_SENTENCE_FLOG,
	LAW_SENTENCE_BRAND,
	LAW_SENTENCE_BANISH,
	LAW_SENTENCE_EXECUTE,
	LAW_SENTENCE_COUNT,
}

enum
{
	LAW_RANK_NONE,
	LAW_RANK_WATCHMAN,
	LAW_RANK_GUARD,
	LAW_RANK_SERGEANT,
	LAW_RANK_COUNT,
}

enum E_LAW_CRIME_DEF
{
	E_LAW_CRIME_DEF_NAME[LAW_NAME_LEN],
	E_LAW_CRIME_DEF_VERB[LAW_VERB_LEN],
	E_LAW_CRIME_DEF_FINE,
	bool:E_LAW_CRIME_DEF_SERIOUS,
	E_LAW_CRIME_DEF_WANTED_DAYS,
	E_LAW_CRIME_DEF_SENTENCE,
	E_LAW_CRIME_DEF_MINUTES,
}

new const g_LawCrimeDefs[LAW_CRIME_COUNT][E_LAW_CRIME_DEF] = {
	{"murder", "kill someone", 1200, true, 7, LAW_SENTENCE_GAOL, 120},
	{"assault", "strike someone down", 120, false, 3, LAW_SENTENCE_PILLORY, 20},
	{"theft", "steal", 60, false, 3, LAW_SENTENCE_STOCKS, 20},
	{"poaching", "poach", 48, false, 3, LAW_SENTENCE_FINE, 0},
	{"poisoning", "poison someone", 960, true, 7, LAW_SENTENCE_GAOL, 90},
	{"breaking a decree", "break a decree", 24, false, 3, LAW_SENTENCE_FINE, 0},
	{"trespass", "trespass", 24, false, 3, LAW_SENTENCE_FINE, 0},
	{"freeing a prisoner", "free a prisoner", 240, false, 3, LAW_SENTENCE_GAOL, 30},
	{"bribery", "offer a bribe", 120, false, 3, LAW_SENTENCE_STOCKS, 15},
	{"escape", "escape the gaol", 240, true, 7, LAW_SENTENCE_GAOL, 60},
	{"arson", "set a fire", 480, true, 7, LAW_SENTENCE_GAOL, 90},
	{"going dark", "walk the streets without a light", 12, false, 0, LAW_SENTENCE_FINE, 0},
	{"toll evasion", "slip past the toll without paying", 12, false, 3, LAW_SENTENCE_FINE, 0}
};

new const g_LawSentenceNames[LAW_SENTENCE_COUNT][16] = {
	"none",
	"fine",
	"pillory",
	"stocks",
	"gaol",
	"flogging",
	"branding",
	"banishment",
	"execution"
};

new const g_LawRankNames[LAW_RANK_COUNT][16] = {
	"none",
	"watchman",
	"guard",
	"sergeant"
};

forward bool:Law_IsGuard(playerid);
forward bool:Law_IsWanted(playerid);
forward bool:Law_IsBound(playerid);
forward bool:Law_IsServing(playerid);
forward bool:Pillory_Lock(playerid,device,bool:isStocks);
forward bool:Gaol_Lock(playerid);
forward bool:Pillory_IsLocked(playerid);
forward bool:Gaol_IsLocked(playerid);
forward bool:Law_LockServing(playerid);
