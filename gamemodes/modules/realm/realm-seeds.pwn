#define REALM_SEED_POINTS (3)
#define REALM_SEED_TOLLS (1)

new const Float:g_RealmSeat[4] = {1179.136, -2810.064, 124.003, 30.0};

enum E_REALM_POINT_DEF
{
	E_REALM_POINT_DEF_KEY[16],
	E_REALM_POINT_DEF_NAME[28],
	Float:E_REALM_POINT_DEF_POS[4],
}

new const g_RealmPointDefs[3][E_REALM_POINT_DEF] = {
	{"talmberg", "Talmberg", {1004.565, -3400.327, 65.734, 37.5}},
	{"church", "the church village", {1007.000, -3151.536, 34.514, 330.0}},
	{"guardhouse", "the guardhouse hamlet", {718.800, -3185.536, 22.703, 330.0}}
};

new const Float:g_RealmTollDefs[1][7] = {
	{990.288, -3654.965, 56.328, 118.1, 989.404, -3653.311, 56.216}
};

new const Float:g_RealmTollBooths[1][4] = {
	{987.694, -3650.115, 56.227, 118.1}
};

new const g_RealmTollBoothKinds[1] = {1};

new const Float:g_RealmTollKeepers[1][4] = {
	{989.281, -3649.266, 56.334, 181.7}
};

new const g_RealmTollNames[1][32] = {
	"the hollow way"
};
