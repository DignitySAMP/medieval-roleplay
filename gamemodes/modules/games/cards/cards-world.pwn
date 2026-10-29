static STREAMER_TAG_OBJECT:s_CardsObjects[TABLE_MAX][CARDS_SLOTS];
static s_CardsShown[TABLE_MAX][CARDS_SLOTS];

static Cards_ClearSlot(table,slot)
{
	if (IsValidDynamicObject(s_CardsObjects[table][slot]))
	{
		DestroyDynamicObject(s_CardsObjects[table][slot]);
	}

	s_CardsObjects[table][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_CardsShown[table][slot] = CARDS_SHOWN_NONE;
}

static Cards_ClearObjects(table)
{
	for (new slot = 0;slot < CARDS_SLOTS;slot++)
	{
		Cards_ClearSlot(table,slot);
	}
}

static Cards_ShowSlot(table,slot,shown,Float:right,Float:ahead,Float:lift,Float:yaw)
{
	if (s_CardsShown[table][slot] == shown)
	{
		return;
	}

	Cards_ClearSlot(table,slot);

	if (shown == CARDS_SHOWN_NONE)
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:angle, bool:isFaceUp = shown != CARDS_SHOWN_BACK && slot != CARDS_SLOT_DECK, model = MODEL_GAMES_CARD;
	Table_LocalToWorld(table,right,ahead,x,y,z,angle);
	z += TABLE_CLOTH_TOP + lift;

	if (slot == CARDS_SLOT_DECK)
	{
		model = MODEL_GAMES_DECK;
	}
	else if (isFaceUp)
	{
		model = MODEL_GAMES_CARD_ACORNS_1 - shown;
	}

	s_CardsObjects[table][slot] = CreateDynamicObject(model,x,y,z,0.0,0.0,angle + yaw,Table_GetWorld(table),Table_GetInterior(table),-1,CARDS_STREAM,CARDS_STREAM);
	s_CardsShown[table][slot] = shown;
	Nearby_StreamObjectsAt(x,y,z,Table_GetWorld(table),Table_GetInterior(table),CARDS_STREAM);
}

stock Cards_GetHandModel(table,seat)
{
	new slot = CARDS_SLOT_HAND + seat;
	return IsValidDynamicObject(s_CardsObjects[table][slot]) ? Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_CardsObjects[table][slot],E_STREAMER_MODEL_ID) : 0;
}

stock Cards_CountObjects(table)
{
	new count = 0;

	for (new slot = 0;slot < CARDS_SLOTS;slot++)
	{
		if (IsValidDynamicObject(s_CardsObjects[table][slot]))
		{
			count++;
		}
	}

	return count;
}

stock Cards_UpdateObjects(table)
{
	if (!Cards_IsRunning(table))
	{
		return;
	}

	Cards_ShowSlot(table,CARDS_SLOT_DECK,Cards_GetLeft(table) > 0 ? 0 : CARDS_SHOWN_NONE,CARDS_DECK_RIGHT,0.0,0.0,0.0);

	new middle = Cards_GetMiddle(table);
	Cards_ShowSlot(table,CARDS_SLOT_MIDDLE,Cards_IsValid(middle) ? middle : CARDS_SHOWN_NONE,0.0,0.0,0.0,0.0);

	for (new i = 0;i < CARDS_BURN;i++)
	{
		new card = Cards_GetBurned(table,i);
		Cards_ShowSlot(table,CARDS_SLOT_BURN + i,Cards_IsValid(card) ? card : CARDS_SHOWN_NONE,CARDS_BURN_RIGHT - float(i) * CARDS_BURN_STEP,float(i) * CARDS_BURN_STEP,float(i) * CARDS_THICK,float(i) * 8.0);
	}

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new card = Cards_GetHand(table,seat), shown = CARDS_SHOWN_NONE, Float:turn = float(seat) * 90.0;

		if (Table_IsSeatIn(table,seat) && Cards_IsValid(card))
		{
			shown = Cards_HasFolded(table,seat) ? CARDS_SHOWN_BACK : card;
		}

		Cards_ShowSlot(table,CARDS_SLOT_HAND + seat,shown,CARDS_HAND_REACH * floatsin(turn,degrees),-CARDS_HAND_REACH * floatcos(turn,degrees),0.0,turn);
	}
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new table = 0;table < TABLE_MAX;table++)
	{
		for (new slot = 0;slot < CARDS_SLOTS;slot++)
		{
			s_CardsObjects[table][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
			s_CardsShown[table][slot] = CARDS_SHOWN_NONE;
		}
	}
}

hook Cards_OnChanged(table)
{
	Cards_UpdateObjects(table);
}

hook Cards_OnEnded(table,winner)
{
	#pragma unused winner

	Cards_ClearObjects(table);
}
