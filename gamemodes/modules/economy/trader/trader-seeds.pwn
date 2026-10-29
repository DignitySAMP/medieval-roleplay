#define TRADER_SEED_KEY "trader-map-1"
#define TRADER_SEED_COUNT (2)
#define TRADER_SEED_GAP (5.0)

enum E_TRADER_SEED_DEF
{
	E_TRADER_SEED_DEF_NAME[TRADER_NAME_LEN],
	E_TRADER_SEED_DEF_LOOK,
	Float:E_TRADER_SEED_DEF_POS[4],
}

new const g_TraderSeedDefs[2][E_TRADER_SEED_DEF] = {
	{"Bohuslav", 5, {1008.264, -3397.635, 66.734, 167.8}},
	{"Kunes", 7, {1004.238, -3149.049, 35.803, 187.3}}
};
