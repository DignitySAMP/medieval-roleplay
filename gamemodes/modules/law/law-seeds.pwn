#define LAW_SEED_DEVICES (2)

enum E_LAW_SEED_DEVICE
{
	E_LAW_SEED_DEVICE_KIND,
	Float:E_LAW_SEED_DEVICE_POS[4],
}

new const g_LawSeedDevices[LAW_SEED_DEVICES][E_LAW_SEED_DEVICE] = {
	{LAW_DEVICE_PILLORY, {1016.000, -3403.500, 65.549, 270.0}},
	{LAW_DEVICE_STOCKS, {999.206, -3408.000, 66.591, 120.0}}
};

new const Float:g_LawSeedRegister[4] = {712.279, -3193.201, 23.000, 168.0};
new const Float:g_LawSeedDoor[4] = {715.188, -3192.427, 22.703, 211.0};
new const Float:g_LawSeedEscape[4] = {707.299, -3185.498, 22.703, 31.0};
