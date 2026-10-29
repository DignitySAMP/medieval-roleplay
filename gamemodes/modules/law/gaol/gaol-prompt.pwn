enum
{
	GAOL_PROMPT_NONE,
	GAOL_PROMPT_DOOR,
	GAOL_PROMPT_EXIT,
	GAOL_PROMPT_WORK,
	GAOL_PROMPT_MEND,
	GAOL_PROMPT_CELL,
}

static s_GaolPromptKind[MAX_PLAYERS];
static s_GaolPromptTarget[MAX_PLAYERS];
static s_GaolPromptInfobox[MAX_PLAYERS];

static Gaol_ClearPrompt(playerid)
{
	if (s_GaolPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_GaolPromptInfobox[playerid]);
	}

	s_GaolPromptKind[playerid] = GAOL_PROMPT_NONE;
	s_GaolPromptTarget[playerid] = -1;
	s_GaolPromptInfobox[playerid] = 0;
}

stock Gaol_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Law_IsBound(playerid) || Pillory_IsLocked(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Gaol_ClearPrompt(playerid);
		return;
	}

	new kind = GAOL_PROMPT_NONE, target = -1, text[128];

	if (Gaol_IsLocked(playerid))
	{
		if ((target = Gaol_IsAtGrate(playerid)) != -1)
		{
			kind = GAOL_PROMPT_WORK;
			format(text,sizeof(text),"The grate is %d%% loose.~n~Press ~y~Y~w~ to work at it. A guard nearby will hear you.",Gaol_GetProgress(target));
		}
	}
	else if (Gaol_IsAtDoor(playerid))
	{
		kind = GAOL_PROMPT_DOOR;
		strcopy(text,"Press ~y~Y~w~ to go down to the gaol.");
	}
	else if (Gaol_IsAtExit(playerid))
	{
		kind = GAOL_PROMPT_EXIT;
		strcopy(text,"Press ~y~Y~w~ to climb the steps out.");
	}
	else if (Law_IsGuard(playerid) && (target = Gaol_IsAtCellDoor(playerid)) != -1)
	{
		kind = GAOL_PROMPT_CELL;
		strcopy(text,Gaol_IsCellOpen(target) ? ("The cell door stands open.~n~Press ~y~Y~w~ to lock it again.") : ("The cell door is locked.~n~Press ~y~Y~w~ to unlock it. It locks again when you walk away."));
	}
	else if (Law_IsGuard(playerid) && (target = Gaol_IsAtGrate(playerid)) != -1 && Gaol_GetProgress(target) > 0)
	{
		kind = GAOL_PROMPT_MEND;
		format(text,sizeof(text),"Someone has worked this grate %d%% loose.~n~Press ~y~Y~w~ to wedge it tight.",Gaol_GetProgress(target));
	}

	if (kind == GAOL_PROMPT_NONE)
	{
		Gaol_ClearPrompt(playerid);
		return;
	}

	if (kind == GAOL_PROMPT_CELL && Gaol_IsCellOpen(target))
	{
		target += GAOL_CELLS;
	}

	if (kind == s_GaolPromptKind[playerid] && target == s_GaolPromptTarget[playerid] && Infobox_IsShown(playerid,s_GaolPromptInfobox[playerid]))
	{
		return;
	}

	s_GaolPromptKind[playerid] = kind;
	s_GaolPromptTarget[playerid] = target;
	s_GaolPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_GaolPromptInfobox[playerid],"The gaol",text,2);
}

Timer_Declare(Gaol_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Gaol_UpdatePrompt(playerid);
		}
	}

	return 1;
}

Timer_Declare(Gaol_Tick)
{
	Gaol_HoldTick();
	return 1;
}

forward bool:Gaol_PromptContext(playerid);

public bool:Gaol_PromptContext(playerid)
{
	return s_GaolPromptKind[playerid] != GAOL_PROMPT_NONE;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_GaolPromptKind[playerid] = GAOL_PROMPT_NONE;
	s_GaolPromptTarget[playerid] = -1;
	s_GaolPromptInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_GaolPromptKind[playerid] == GAOL_PROMPT_NONE || Infobox_IsPromptBlocked(playerid,s_GaolPromptInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new kind = s_GaolPromptKind[playerid], target = s_GaolPromptTarget[playerid];
	Gaol_ClearPrompt(playerid);

	switch (kind)
	{
		case GAOL_PROMPT_DOOR: Gaol_Enter(playerid);
		case GAOL_PROMPT_EXIT: Gaol_Leave(playerid);
		case GAOL_PROMPT_WORK: Gaol_StartWork(playerid);
		case GAOL_PROMPT_CELL:
		{
			new cell = target % GAOL_CELLS;

			if (!Gaol_IsCellOpen(cell))
			{
				Gaol_OpenCell(cell,playerid);
				Chat_Speak(playerid,CHAT_ME,"turns the key and swings the cell door open.");
			}
			else if (Gaol_ShutCell(cell))
			{
				Chat_Speak(playerid,CHAT_ME,"swings the cell door shut and locks it.");
			}
			else
			{
				Gui_Notify(playerid,"Someone is still in the cell or standing in the doorway. The door won't shut on them.");
			}
		}
		case GAOL_PROMPT_MEND:
		{
			Gaol_SetProgress(target,0);
			Chat_Speak(playerid,CHAT_ME,"wedges the grate tight again.");
		}
	}
}
