#define BUILD_CONDITION_MAX (100)
#define BUILD_DAMAGED_AT (60)
#define BUILD_POOR_AT (30)
#define BUILD_DECAY_PER_DAY (1)
#define BUILD_DECAY_EVERY_DAYS (2)
#define BUILD_STORM_DAMAGE (3)
#define BUILD_FIRE_DAMAGE (20)
#define BUILD_REPAIR_UNIT (25)
#define BUILD_PROJECTS_MAX (16)
#define BUILD_STAGES_MAX (4)
#define BUILD_STOCKPILE_SLOTS (16)
#define BUILD_SCENE_MS (8000)
#define BUILD_SCENE_TICK_MS (250)
#define BUILD_SCENE_STAMINA (8.0)
#define BUILD_SCENE_FATIGUE (1.0)
#define BUILD_PRACTICE (15)
#define BUILD_PROMPT_MS (500)
#define BUILD_SITE_REACH (4.5)
#define BUILD_SITE_DOOR_GAP (2.0)
#define BUILD_WORK_REACH (7.0)
#define BUILD_NOTICE_DAYS (5)
#define BUILD_PANEL_WIDTH (300.0)

enum _:E_BUILD_KINDS
{
	BUILD_KIND_REPAIR,
	BUILD_KIND_TILE_ROOF,
	BUILD_KIND_COUNT,
}

new const g_BuildKindNames[BUILD_KIND_COUNT][24] = {"Repairs", "Tend the roof"};

enum _:E_BUILD_STAGES
{
	BUILD_STAGE_FRAME,
	BUILD_STAGE_THATCH,
	BUILD_STAGE_RETILE,
	BUILD_STAGE_STONE,
	BUILD_STAGE_STRIP,
	BUILD_STAGE_LATH,
	BUILD_STAGE_MORTAR,
	BUILD_STAGE_TILE,
	BUILD_STAGE_COUNT,
}

enum E_BUILD_STAGE_DEF
{
	E_BUILD_STAGE_DEF_NAME[24],
	E_BUILD_STAGE_DEF_ME[48],
	E_BUILD_STAGE_DEF_TRADE,
	E_BUILD_STAGE_DEF_TOOL,
	E_BUILD_STAGE_DEF_ITEM[2],
	E_BUILD_STAGE_DEF_AMOUNT[2],
	E_BUILD_STAGE_DEF_ANIM_LIB[12],
	E_BUILD_STAGE_DEF_ANIM[20],
}

new const g_BuildStageDefs[BUILD_STAGE_COUNT][E_BUILD_STAGE_DEF] = {
	{"Mend the frame", "hammers new boards into the frame.", TRADE_CARPENTER, ITEM_HAMMER, {ITEM_PLANK, ITEM_NAILS}, {2, 1}, "BASEBALL", "Bat_M"},
	{"Patch the thatch", "packs fresh straw into the thatch.", TRADE_CARPENTER, -1, {ITEM_STRAW, -1}, {3, 0}, "BOMBER", "BOM_Plant_Loop"},
	{"Patch the roof", "patches worn sections of the roof.", TRADE_CARPENTER, ITEM_HAMMER, {ITEM_TILE, -1}, {2, 0}, "BOMBER", "BOM_Plant_Loop"},
	{"Point the walls", "chisels out rotten mortar and resets a stone.", TRADE_MINING, ITEM_CHISEL, {ITEM_STONE_BLOCK, ITEM_WATER_UNCLEAN}, {1, 1}, "BOMBER", "BOM_Plant_Loop"},
	{"Clear worn roofing", "clears worn roofing ready for repairs.", -1, -1, {-1, -1}, {0, 0}, "BD_FIRE", "wash_up"},
	{"Lath the roof", "nails laths across the rafters.", TRADE_CARPENTER, ITEM_HAMMER, {ITEM_PLANK, ITEM_NAILS}, {2, 1}, "BASEBALL", "Bat_M"},
	{"Mix the mortar", "mixes a trough of mortar.", -1, -1, {ITEM_WATER_UNCLEAN, -1}, {1, 0}, "BD_FIRE", "wash_up"},
	{"Repair the covering", "repairs the covering over the roof laths.", TRADE_CARPENTER, ITEM_HAMMER, {ITEM_TILE, -1}, {4, 0}, "BOMBER", "BOM_Plant_Loop"}
};
