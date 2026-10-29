#define CARDS_SUITS (4)
#define CARDS_RANKS (10)
#define CARDS_DECK (CARDS_SUITS * CARDS_RANKS)
#define CARDS_NONE (-1)
#define CARDS_BURN (3)
#define CARDS_NAME_LEN (24)
#define CARDS_RANK_FARMER (7)
#define CARDS_RANK_KING (8)
#define CARDS_RANK_QUEEN (9)
#define CARDS_TURN_MS (30000)
#define CARDS_TICK_MS (500)
#define CARDS_NPC_THINK_MS (1500)
#define CARDS_ITEM_KIND (ITEM_KIND_MISC)
#define CARDS_PANEL_TITLE "Lansquenet"
#define CARDS_SETUP_TITLE "Play Lansquenet"
#define CARDS_LEAVE_TITLE "Leave the hand"
#define CARDS_PANEL_WIDTH (300.0)
#define CARDS_BOX (34.0)
#define CARDS_STREAM (40.0)
#define CARDS_THICK (0.0015)
#define CARDS_HAND_REACH (0.26)
#define CARDS_DECK_RIGHT (0.11)
#define CARDS_BURN_RIGHT (-0.11)
#define CARDS_BURN_STEP (0.025)
#define CARDS_SLOT_DECK (0)
#define CARDS_SLOT_MIDDLE (1)
#define CARDS_SLOT_BURN (2)
#define CARDS_SLOT_HAND (CARDS_SLOT_BURN + CARDS_BURN)
#define CARDS_SLOTS (CARDS_SLOT_HAND + TABLE_SEATS)
#define CARDS_SHOWN_NONE (-1)
#define CARDS_SHOWN_BACK (100)
#define CARDS_PICK_ACT (100)
#define CARDS_PICK_LEAVE (110)

enum
{
	CARDS_STEP_BET_DEAL,
	CARDS_STEP_BET_BURN,
	CARDS_STEP_BET_LOOP,
}

enum
{
	CARDS_ACT_STAY,
	CARDS_ACT_MEET,
	CARDS_ACT_RAISE,
	CARDS_ACT_FOLD,
}

enum
{
	CARDS_SUIT_ACORNS,
	CARDS_SUIT_BELLS,
	CARDS_SUIT_HEARTS,
	CARDS_SUIT_LEAVES,
}

new const g_CardsSuitNames[CARDS_SUITS][] = {"Acorns", "Bells", "Hearts", "Leaves"};
new const g_CardsRankNames[CARDS_RANKS][] = {"1", "2", "3", "4", "5", "6", "7", "Farmer", "King", "Queen"};
new const g_CardsSpriteSuits[CARDS_SUITS][] = {"acorns", "bells", "hearts", "leaves"};
new const g_CardsSpriteRanks[CARDS_RANKS][] = {"1", "2", "3", "4", "5", "6", "7", "farmer", "king", "queen"};
