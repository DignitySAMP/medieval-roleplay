#define DICE_COUNT (6)
#define DICE_FACES (6)
#define DICE_ALL ((1 << DICE_COUNT) - 1)
#define DICE_TURN_MS (30000)
#define DICE_TICK_MS (500)
#define DICE_WEIGHTED_CHANCE (34)
#define DICE_BUST_PAUSE_MS (2500)
#define DICE_NPC_THINK_MS (1500)
#define DICE_ITEM_KIND (ITEM_KIND_MISC)
#define DICE_PANEL_TITLE "Dice"
#define DICE_SETUP_TITLE "Play dice"
#define DICE_LEAVE_TITLE "Leave the game"
#define DICE_PANEL_WIDTH (300.0)
#define DICE_BOX (30.0)
#define DICE_BOX_GAP (5.0)
#define DICE_PICK_ROLL (100)
#define DICE_PICK_BANK (101)
#define DICE_PICK_LEAVE (102)
#define DICE_PICK_DIE (200)
#define DICE_STREAM (40.0)
#define DICE_REST_Z (TABLE_CLOTH_TOP + 0.025)
#define DICE_SPREAD (0.22)
#define DICE_ROW_GAP (0.07)
#define DICE_HOP (0.35)
#define DICE_HOP_SPEED (1.8)
#define DICE_COLOUR_ASIDE (0x6E665CFF)
#define DICE_PICK_RIM (2.0)

enum
{
	DICE_KIND_PLAIN,
	DICE_KIND_WEIGHTED,
	DICE_KIND_HEAVY,
	DICE_KIND_LUCKY,
	DICE_KIND_DEVIL,
	DICE_KIND_COUNT,
}

new const g_DiceTargets[] = {1500, 3000, 5000};

new const g_DiceKindSprites[DICE_KIND_COUNT][] = {"plain", "weighted", "heavy", "lucky", "devil"};
new const g_DiceKindModels[DICE_KIND_COUNT] = {MODEL_GAMES_DIE_PLAIN, MODEL_GAMES_DIE_WEIGHTED, MODEL_GAMES_DIE_HEAVY, MODEL_GAMES_DIE_LUCKY, MODEL_GAMES_DIE_DEVIL};
new const g_DiceStyleBankAt[TABLE_STYLE_COUNT] = {300, 450, 700};
new const g_DiceStyleMinDice[TABLE_STYLE_COUNT] = {3, 2, 1};
new const Float:g_DiceFaceRotations[DICE_FACES + 1][2] = {
	{0.0, 0.0},
	{0.0, 0.0},
	{90.0, 0.0},
	{0.0, -90.0},
	{0.0, 90.0},
	{-90.0, 0.0},
	{180.0, 0.0}
};
new const g_DiceKindItems[DICE_KIND_COUNT] = {ITEM_DICE, ITEM_DIE_WEIGHTED, ITEM_DIE_HEAVY, ITEM_DIE_LUCKY, ITEM_DIE_DEVIL};
new const g_DiceSpecialOrder[] = {DICE_KIND_WEIGHTED, DICE_KIND_HEAVY, DICE_KIND_DEVIL, DICE_KIND_LUCKY};
