#define DISASTERS_TICK_MS (60000)
#define DISASTERS_WARN_MINUTES (15)
#define DISASTERS_CRIER_KIND "omen"
#define DISASTERS_STORM_WEATHER (8)
#define DISASTERS_FLOOD_WEATHER (16)
#define DISASTERS_LIGHTNING_PERCENT (2)
#define DISASTERS_SICK_PERMILLE (15)
#define DISASTERS_SICK_EVERY (10)
#define DISASTERS_SCARCITY_STEP (10)
#define DISASTERS_DROUGHT_DAYS (30)

enum _:E_DISASTER_KIND
{
	DISASTER_STORM,
	DISASTER_FLOOD,
	DISASTER_DROUGHT,
	DISASTER_PESTILENCE,
	DISASTER_KIND_COUNT,
}

enum E_DISASTER_DEF
{
	E_DISASTER_DEF_KEY[12],
	E_DISASTER_DEF_NAME[20],
	E_DISASTER_DEF_MIN_MINUTES,
	E_DISASTER_DEF_MAX_MINUTES,
	E_DISASTER_DEF_ODDS[4],
	E_DISASTER_DEF_SIGNS[144],
	E_DISASTER_DEF_BEGINS[144],
	E_DISASTER_DEF_ENDS[144],
}

new const g_DisasterDefs[DISASTER_KIND_COUNT][E_DISASTER_DEF] = {
	{"storm", "A storm", 20, 40, {0, 40, 60, 50},
		"The swallows fly low and the west goes black. The old folk say a storm is coming: bring the washing in and bank the fires.",
		"The storm breaks over the county. Keep under a roof; lightning finds the thatch.",
		"The storm has passed. Look to your roofs."},
	{"flood", "A flood", 45, 90, {0, 25, 0, 30},
		"The river runs brown and high and the rain won't stop. The low fields will flood.",
		"The river is over its banks. The roads are mud and the low ground is under water.",
		"The waters go down. Count what was lost."},
	{"drought", "A drought", 0, 0, {0, 0, 150, 0},
		"No rain since the sowing. The wells run low and the grain stands thin: bread will be dear this month.",
		"The drought holds. Food and drink cost more at every stall, and a spark sets the thatch ablaze.",
		"Rain at last. The drought is broken."},
	{"pestilence", "A pestilence", 600, 900, {10, 10, 15, 10},
		"A sickness has come up the road with the carters. Keep apart from the coughing and keep yourselves clean.",
		"Sickness is in the villages. Those who crowd together catch it.",
		"The sickness has run its course."}
};
