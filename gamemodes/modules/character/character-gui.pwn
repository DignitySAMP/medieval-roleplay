#define CHARACTER_GUI_GRAVEYARD (100)

CharacterGui_ShowSelect(playerid)
{
	yield 1;

	new epoch = Gui_BeginFlow(playerid), name[CHARACTER_NAME_MAX * 2 + 2], played[CHARACTER_SLOT_PLAYED_LEN], Float:x, Float:y, Float:width;
	Scene_ShowLogin(playerid);

	for (;;)
	{
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Your characters");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,float(ACCOUNT_CHARACTER_SLOTS) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Your characters",x,y,width);

		for (new slot = 0;slot < ACCOUNT_CHARACTER_SLOTS;slot++)
		{
			new Float:rowY = y + float(slot) * KIT_ROW;

			if (Character_GetSlotId(playerid,slot) == 0)
			{
				Kit_AddChoice(playerid,x,rowY,width,"Empty slot",slot,KIT_COLOUR_ACCENT,"Create a new character",KIT_COLOUR_MUTED,0.45);
				continue;
			}

			Character_GetSlotName(playerid,slot,name);

			if (Character_IsSlotAlive(playerid,slot))
			{
				Character_GetSlotPlayed(playerid,slot,played);
				Kit_AddChoice(playerid,x,rowY,width,name,slot,KIT_COLOUR_TEXT,played,KIT_COLOUR_MUTED,0.70);
			}
			else
			{
				Kit_AddChoice(playerid,x,rowY,width,name,slot,KIT_COLOUR_MUTED,"Deceased",KIT_COLOUR_BAD,0.70);
			}
		}

		if (Character_GetGraveCount(playerid) > 0)
		{
			Kit_AddButton(playerid,x,y + float(ACCOUNT_CHARACTER_SLOTS) * KIT_ROW + 8.0,width * 0.45,"Graveyard",CHARACTER_GUI_GRAVEYARD,KIT_COLOUR_ACCENT);
			Kit_AddButton(playerid,x + width * 0.55,y + float(ACCOUNT_CHARACTER_SLOTS) * KIT_ROW + 8.0,width * 0.45,GUI_BUTTON_LEAVE,KIT_BACK,KIT_COLOUR_BAD);
		}
		else
		{
			Kit_AddButton(playerid,x + width / 2.0 - 45.0,y + float(ACCOUNT_CHARACTER_SLOTS) * KIT_ROW + 8.0,90.0,GUI_BUTTON_LEAVE,KIT_BACK,KIT_COLOUR_BAD);
		}

		new slot = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || Session_GetState(playerid) != SESSION_CHARACTER_SELECT)
		{
			return;
		}

		if (slot == KIT_BACK)
		{
			new bool:isLeaving = Gui_ConfirmLeave(playerid);

			if (!Gui_IsFlowCurrent(playerid,epoch) || Session_GetState(playerid) != SESSION_CHARACTER_SELECT)
			{
				return;
			}

			if (isLeaving)
			{
				Kit_Close(playerid);
				Account_KickDelayed(playerid);
				return;
			}

			continue;
		}

		if (slot == CHARACTER_GUI_GRAVEYARD)
		{
			pawn_call_public("Character_OnGraveyard","d",playerid);
			return;
		}

		if (slot < 0 || slot >= ACCOUNT_CHARACTER_SLOTS)
		{
			continue;
		}

		if (Character_GetSlotId(playerid,slot) == 0)
		{
			Kit_Clear(playerid);
			Creator_Start(playerid,slot);
			return;
		}

		if (!Character_IsSlotAlive(playerid,slot))
		{
			Gui_Notify(playerid,"That soul has passed. This character is dead and can't be played.");
			continue;
		}

		Kit_Close(playerid);
		Character_Load(playerid,Character_GetSlotId(playerid,slot));
		return;
	}
}
