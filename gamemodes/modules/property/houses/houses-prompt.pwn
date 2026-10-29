enum
{
	HOUSE_PROMPT_NONE,
	HOUSE_PROMPT_DOOR,
	HOUSE_PROMPT_KNOCK,
	HOUSE_PROMPT_EXIT,
	HOUSE_PROMPT_REGISTER,
	HOUSE_PROMPT_CANDLE,
	HOUSE_PROMPT_ROOM,
}

static s_HousePromptKind[MAX_PLAYERS];
static s_HousePromptTarget[MAX_PLAYERS];
static s_HousePromptInfobox[MAX_PLAYERS];
static s_HouseRegisterHouse = -1;
static Float:s_HouseRegisterSpot[3];

stock Houses_FindRegister()
{
	s_HouseRegisterHouse = Houses_FindByKey(HOUSE_REGISTER_HOUSE);

	if (s_HouseRegisterHouse == -1)
	{
		return;
	}

	for (new i = g_HouseDefs[s_HouseRegisterHouse][E_HOUSE_DEF_FIRST][3], last = i + g_HouseDefs[s_HouseRegisterHouse][E_HOUSE_DEF_COUNT][3];i < last;i++)
	{
		if (!strcmp(g_HouseSpotDefs[i][E_HOUSE_POSE_DEF_WHO],"work"))
		{
			Houses_LocalToWorld(g_HouseSpotDefs[i][E_HOUSE_POSE_DEF_POS][0],g_HouseSpotDefs[i][E_HOUSE_POSE_DEF_POS][1],g_HouseSpotDefs[i][E_HOUSE_POSE_DEF_POS][2],s_HouseRegisterSpot[0],s_HouseRegisterSpot[1],s_HouseRegisterSpot[2]);
			return;
		}
	}
}

stock bool:Houses_IsAtRegister(playerid)
{
	return s_HouseRegisterHouse != -1 && Houses_GetInside(playerid) == s_HouseRegisterHouse && IsPlayerInRangeOfPoint(playerid,HOUSE_SPOT_REACH,s_HouseRegisterSpot[0],s_HouseRegisterSpot[1],s_HouseRegisterSpot[2] + 1.0);
}

static Houses_ClearPrompt(playerid)
{
	if (s_HousePromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_HousePromptInfobox[playerid]);
	}

	s_HousePromptKind[playerid] = HOUSE_PROMPT_NONE;
	s_HousePromptTarget[playerid] = -1;
	s_HousePromptInfobox[playerid] = 0;
}

stock Houses_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Houses_IsLying(playerid) || Law_IsBound(playerid) || Law_IsServing(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Houses_ClearPrompt(playerid);
		return;
	}

	new kind = HOUSE_PROMPT_NONE, target, title[28], text[160];

	if ((target = Houses_FindDoorNear(playerid)) != -1 && !Houses_IsGutted(target))
	{
		Houses_GetName(target,title);
		title[0] = toupper(title[0]);

		if (Houses_CanEnter(playerid,target))
		{
			kind = HOUSE_PROMPT_DOOR;
			strcopy(text,"Press ~y~Y~w~ to go in.");
		}
		else
		{
			kind = HOUSE_PROMPT_KNOCK;
			strcopy(text,"The door is barred for the night.~n~Press ~y~Y~w~ to knock.");
		}
	}
	else if (Houses_IsAtExit(playerid))
	{
		kind = HOUSE_PROMPT_EXIT;
		target = Houses_GetInside(playerid);
		strcopy(title,"The door");
		strcopy(text,Houses_IsOpen() ? ("Press ~y~Y~w~ to go outside.") : ("Press ~y~Y~w~ to go outside. You leave the door unbarred for a minute behind you."));
	}
	else if (Houses_IsAtRegister(playerid))
	{
		kind = HOUSE_PROMPT_REGISTER;
		strcopy(title,"County register");
		strcopy(text,"The steward keeps the rolls of rooms to let here.~n~Press ~y~Y~w~ to ask about a room or pay your rent.");
	}
	else if ((target = Houses_FindCandleSlot(playerid,1.2)) != -1 && !Houses_IsCandleLit(target))
	{
		kind = HOUSE_PROMPT_CANDLE;
		strcopy(title,"Candle");
		strcopy(text,"Press ~y~Y~w~ to set a candle here and light it.");
	}
	else if ((target = Houses_FindRoomAt(playerid)) != -1 && Houses_IsRoomOf(target,Character_GetId(playerid)))
	{
		kind = HOUSE_PROMPT_ROOM;
		strcopy(title,"Your room");
		strcopy(text,"Press ~y~Y~w~ for your chest, the bed and the furniture.");
	}

	if (kind == HOUSE_PROMPT_NONE || Keys_IsBusy(playerid,KEY_YES,kind == HOUSE_PROMPT_EXIT ? HOUSE_EXIT_KEY_PRIO : KEYS_PRIO_MENU))
	{
		Houses_ClearPrompt(playerid);
		return;
	}

	if (kind == s_HousePromptKind[playerid] && target == s_HousePromptTarget[playerid] && Infobox_IsShown(playerid,s_HousePromptInfobox[playerid]))
	{
		return;
	}

	s_HousePromptKind[playerid] = kind;
	s_HousePromptTarget[playerid] = target;
	s_HousePromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_HousePromptInfobox[playerid],title,text,3);
}

Timer_Declare(Houses_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Houses_UpdatePrompt(playerid);
		}
	}

	return 1;
}

forward Houses_RegisterDeferred(playerid);

public Houses_RegisterDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Houses_OpenRegister(playerid);
	}

	return 1;
}

forward Houses_RoomDeferred(playerid,room);

public Houses_RoomDeferred(playerid,room)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Houses_OpenRoom(playerid,room);
	}

	return 1;
}

forward bool:Houses_PromptContext(playerid);

public bool:Houses_PromptContext(playerid)
{
	return s_HousePromptKind[playerid] != HOUSE_PROMPT_NONE || Houses_IsLying(playerid);
}

forward bool:Houses_ExitContext(playerid);

public bool:Houses_ExitContext(playerid)
{
    return Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !Character_IsBusy(playerid) && !Law_IsBound(playerid) && !Law_IsServing(playerid) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT && Houses_IsAtExit(playerid);
}

forward bool:Houses_BusyCheck(playerid);

public bool:Houses_BusyCheck(playerid)
{
	return Houses_IsLying(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_HousePromptKind[playerid] = HOUSE_PROMPT_NONE;
	s_HousePromptTarget[playerid] = -1;
	s_HousePromptInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || (newkeys & KEY_WALK) || s_HousePromptKind[playerid] == HOUSE_PROMPT_NONE || Houses_IsLying(playerid) || Infobox_IsPromptBlocked(playerid,s_HousePromptInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,s_HousePromptKind[playerid] == HOUSE_PROMPT_EXIT ? HOUSE_EXIT_KEY_PRIO : KEYS_PRIO_MENU))
	{
		return;
	}

	new kind = s_HousePromptKind[playerid], target = s_HousePromptTarget[playerid];
	Houses_ClearPrompt(playerid);

	switch (kind)
	{
		case HOUSE_PROMPT_DOOR:
		{
			Houses_Enter(playerid,target);
			Houses_TouchHold(playerid);
		}
		case HOUSE_PROMPT_KNOCK: Houses_Knock(playerid,target);
		case HOUSE_PROMPT_EXIT:
		{
			if (!Houses_IsOpen())
			{
				Houses_Unbar(target);
			}

			Houses_Leave(playerid);
		}
		case HOUSE_PROMPT_REGISTER: SetTimerEx("Houses_RegisterDeferred",0,false,"d",playerid);
		case HOUSE_PROMPT_CANDLE: Houses_LightCandle(playerid,target);
		case HOUSE_PROMPT_ROOM: SetTimerEx("Houses_RoomDeferred",0,false,"dd",playerid,target);
	}
}
