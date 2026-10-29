enum E_TUTORIAL_STEP
{
	TUTORIAL_NONE,
	TUTORIAL_WALK_RACK,
	TUTORIAL_OPEN_BAG,
	TUTORIAL_CARRY_WEAPON,
	TUTORIAL_DRAW,
	TUTORIAL_SWING,
	TUTORIAL_SHEATHE,
	TUTORIAL_FISTS_UP,
	TUTORIAL_BRAWL,
	TUTORIAL_DODGE,
	TUTORIAL_INTRODUCE,
	TUTORIAL_WALK_CAMP,
	TUTORIAL_OPEN_CRAFTING,
	TUTORIAL_BUILD,
	TUTORIAL_PLACE,
	TUTORIAL_COOK,
	TUTORIAL_OPEN_CHARACTER,
	TUTORIAL_TO_DONKEY,
	TUTORIAL_RIDE_OUT,
	TUTORIAL_DONE,
}

enum
{
	TUTORIAL_BRIEF_ARRIVAL,
	TUTORIAL_BRIEF_ARMS,
	TUTORIAL_BRIEF_FISTS,
	TUTORIAL_BRIEF_PEOPLE,
	TUTORIAL_BRIEF_NEEDS,
	TUTORIAL_BRIEF_CRAFTING,
	TUTORIAL_BRIEF_WORK,
	TUTORIAL_BRIEF_MEAL,
	TUTORIAL_BRIEF_ROAD,
	TUTORIAL_BRIEF_NEXT,
	TUTORIAL_BRIEF_HISTORY,
	TUTORIAL_BRIEF_COUNT,
}

#define TUTORIAL_START_RETRY_MS (250)
#define TUTORIAL_LEAVE_FADE_MS (1500)
#define TUTORIAL_LEAVE_FADE_STEPS (15)
#define TUTORIAL_LEAVE_DELAY_MS (6000)
#define TUTORIAL_FADE_BLACK (0x000000FF)
#define TUTORIAL_WELCOME_DELAY_MS (4000)

static E_TUTORIAL_STEP:s_TutorialStep[MAX_PLAYERS];
static s_TutorialHeldWork[MAX_PLAYERS][3];
static s_TutorialSwung[MAX_PLAYERS];
static s_TutorialBrawled[MAX_PLAYERS];
static s_TutorialDodged[MAX_PLAYERS];
static s_TutorialTabStage[MAX_PLAYERS];
static bool:s_TutorialTabReading[MAX_PLAYERS];
static s_TutorialTabToken[MAX_PLAYERS];
static bool:s_TutorialWelcomePending[MAX_PLAYERS];
static bool:s_TutorialWelcoming[MAX_PLAYERS];

#define TUTORIAL_SWING_SIDES (4)

static const s_TutorialSideNames[TUTORIAL_SWING_SIDES][8] = {"forward", "back", "left", "right"};

#define TUTORIAL_BRAWL_MOVES (3)
#define TUTORIAL_DODGE_BACK (1)
#define TUTORIAL_DODGE_SIDE (2)
#define TUTORIAL_TAB_STAGES (4)
#define TUTORIAL_TAB_READ_SECONDS (3)

static const s_TutorialBrawlNames[TUTORIAL_BRAWL_MOVES][8] = {"a shove", "a hook", "a kick"};

static const s_TutorialTabText[TUTORIAL_TAB_STAGES][128] = {
	"This tab shows your name, age, people and upbringing. Click a line to read more.",
	"Health shows how you're doing, from food and warmth to every part of your body. Click a line to learn more.",
	"Skills shows your talent points and the trades you learn by working at stations.",
	"Buffs shows what's helping you right now. Newcomer's warmth keeps the cold off during your first hour of playtime."
};

static const s_TutorialTabNextText[TUTORIAL_TAB_STAGES][40] = {
	"Then click the Health tab.",
	"Then click the Skills tab.",
	"Now click the Buffs tab.",
	"Close the panel when you're done."
};

static const s_TutorialTabNext[TUTORIAL_TAB_STAGES] = {CHARPANEL_TAB_HEALTH, CHARPANEL_TAB_SKILLS, CHARPANEL_TAB_BUFFS, KIT_BACK};

stock bool:Tutorial_IsActive(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TutorialStep[playerid] > TUTORIAL_NONE && s_TutorialStep[playerid] < TUTORIAL_DONE;
}

stock bool:Tutorial_IsWelcoming(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TutorialWelcoming[playerid];
}

stock Tutorial_EndWelcome(playerid)
{
	if (!Util_IsValidPlayer(playerid) || !s_TutorialWelcoming[playerid])
	{
		return;
	}

	s_TutorialWelcoming[playerid] = false;
	pawn_call_public("Tutorial_OnWelcomed","d",playerid);
}

stock E_TUTORIAL_STEP:Tutorial_GetStep(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_TutorialStep[playerid] : TUTORIAL_NONE;
}

static Tutorial_TopUp(playerid,E_ITEM_KIND:kind,param,amount)
{
	new have = Inventory_Count(playerid,kind,param);

	if (have < amount)
	{
		Inventory_Give(playerid,kind,param,amount - have);
	}
}

static Tutorial_FindSlot(playerid,E_ITEM_KIND:wantKind,wantParam)
{
	for (new slot = 0, E_ITEM_KIND:kind, param, amount;slot < Inventory_GetCount(playerid);slot++)
	{
		Inventory_GetSlot(playerid,slot,kind,param,amount);

		if (kind == wantKind && param == wantParam)
		{
			return slot;
		}
	}

	return -1;
}

static Tutorial_EnterStep(playerid)
{
	new bool:isBriefed = false;
	Kit_ClearHighlights(playerid);

	switch (s_TutorialStep[playerid])
	{
		case TUTORIAL_CARRY_WEAPON:
		{
			Kit_AddHighlight(playerid,"Your bag",Tutorial_FindSlot(playerid,ITEM_KIND_WEAPON,WEAPON_KNIFE_CLUB));
			Kit_AddHighlight(playerid,"Your bag",INVENTORY_GUI_USE);
		}
		case TUTORIAL_BUILD:
		{
			Kit_AddHighlight(playerid,"Crafting",CRAFT_BUILD);
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_CRAFTING);
		}
		case TUTORIAL_WALK_RACK:
		{
			TutorialIsland_Mark(playerid,TUTORIAL_RACK_X,TUTORIAL_RACK_Y,TUTORIAL_RACK_Z);
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_ARRIVAL);
		}
		case TUTORIAL_OPEN_BAG:
		{
			DisablePlayerCheckpoint(playerid);
			Tutorial_TopUp(playerid,ITEM_KIND_WEAPON,WEAPON_KNIFE_CLUB,1);
		}
		case TUTORIAL_SWING:
		{
			s_TutorialSwung[playerid] = 0;
		}
		case TUTORIAL_DRAW:
		{
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_ARMS);
		}
		case TUTORIAL_FISTS_UP:
		{
			if (Combat_GetWeapon(playerid) == WEAPON_KNIFE_CLUB)
			{
				Combat_Unequip(playerid);
			}

			Inventory_Take(playerid,ITEM_KIND_WEAPON,WEAPON_KNIFE_CLUB,Inventory_Count(playerid,ITEM_KIND_WEAPON,WEAPON_KNIFE_CLUB));
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_FISTS);
		}
		case TUTORIAL_BRAWL:
		{
			s_TutorialBrawled[playerid] = 0;
		}
		case TUTORIAL_DODGE:
		{
			s_TutorialDodged[playerid] = 0;
		}
		case TUTORIAL_INTRODUCE:
		{
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_PEOPLE);
		}
		case TUTORIAL_WALK_CAMP:
		{
			TutorialIsland_Mark(playerid,TUTORIAL_CAMP_X,TUTORIAL_CAMP_Y,TUTORIAL_CAMP_Z);
		}
		case TUTORIAL_OPEN_CRAFTING:
		{
			DisablePlayerCheckpoint(playerid);

			for (new i = 0, item, amount;i < WORK_BUILD_MAX;i++)
			{
				if (Work_GetBuildMaterial(Work_FindKind(TALENT_ROOT_KEY),i,item,amount))
				{
					Tutorial_TopUp(playerid,Item_GetDefKind(item),item,amount);
				}
			}

			Kit_AddHighlight(playerid,"Your bag",Inventory_GetMenuButtonValue("Crafting"));
			Craft_SetOpenGate(playerid,"Tutorial_CraftGate");
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_NEEDS);
		}
		case TUTORIAL_COOK:
		{
			new name[WORK_KIND_NAME_LEN];
			Work_GetKindName(Work_FindKind(TALENT_ROOT_KEY),name);
			Tutorial_TopUp(playerid,ITEM_KIND_MATERIAL,ITEM_FISH,1);
			Kit_AddHighlight(playerid,name,WORK_PANEL_WORK);
			Kit_AddHighlight(playerid,name,Recipe_FindByName("Roast fish"));
			Work_SetStartGate(playerid,"Tutorial_WorkGate");
		}
		case TUTORIAL_OPEN_CHARACTER:
		{
			s_TutorialTabStage[playerid] = 0;
			s_TutorialTabReading[playerid] = false;
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_MEAL);
		}
		case TUTORIAL_TO_DONKEY:
		{
			TutorialIsland_HoldDonkey(playerid,false);
			TutorialIsland_Mark(playerid,TUTORIAL_STABLES_X,TUTORIAL_STABLES_Y,TUTORIAL_STABLES_Z);
			isBriefed = TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_ROAD);
		}
		case TUTORIAL_RIDE_OUT:
		{
			TutorialIsland_Mark(playerid,TUTORIAL_END_X,TUTORIAL_END_Y,TUTORIAL_END_Z);
		}
		default: {}
	}

	if (!isBriefed)
	{
		TutorialGui_ShowStep(playerid,s_TutorialStep[playerid]);
	}
}

static E_TUTORIAL_STEP:Tutorial_GetResumeStep(playerid)
{
	new E_TUTORIAL_STEP:saved = E_TUTORIAL_STEP:Character_GetTutorialStep(playerid);

	switch (saved)
	{
		case TUTORIAL_CARRY_WEAPON, TUTORIAL_DRAW, TUTORIAL_SWING, TUTORIAL_SHEATHE: saved = Combat_GetWeapon(playerid) == WEAPON_KNIFE_CLUB ? TUTORIAL_DRAW : TUTORIAL_OPEN_BAG;
		case TUTORIAL_BRAWL, TUTORIAL_DODGE: saved = TUTORIAL_FISTS_UP;
		case TUTORIAL_BUILD, TUTORIAL_PLACE, TUTORIAL_COOK: saved = TUTORIAL_OPEN_CRAFTING;
		case TUTORIAL_RIDE_OUT: saved = TUTORIAL_TO_DONKEY;
		default: {}
	}

	return saved > TUTORIAL_NONE && saved < TUTORIAL_DONE ? saved : TUTORIAL_WALK_RACK;
}

static Tutorial_GetResumeSpot(E_TUTORIAL_STEP:step,&Float:x,&Float:y,&Float:z)
{
	if (step <= TUTORIAL_WALK_RACK)
	{
		x = TUTORIAL_SPAWN_X;
		y = TUTORIAL_SPAWN_Y;
		z = TUTORIAL_SPAWN_Z;
	}
	else if (step <= TUTORIAL_WALK_CAMP)
	{
		x = TUTORIAL_RACK_X;
		y = TUTORIAL_RACK_Y;
		z = TUTORIAL_RACK_Z;
	}
	else
	{
		x = TUTORIAL_CAMP_X;
		y = TUTORIAL_CAMP_Y;
		z = TUTORIAL_CAMP_Z;
	}
}

static Tutorial_SetStep(playerid,E_TUTORIAL_STEP:step)
{
	s_TutorialStep[playerid] = step;
	Character_SetTutorialStep(playerid,_:step);
	pawn_call_public("Tutorial_OnStep","dd",playerid,_:step);

	if (step == TUTORIAL_DONE)
	{
		Tutorial_Finish(playerid);
		return;
	}

	Tutorial_EnterStep(playerid);
}

static Tutorial_Advance(playerid,E_TUTORIAL_STEP:expected)
{
	if (s_TutorialStep[playerid] == expected)
	{
		Tutorial_SetStep(playerid,expected + E_TUTORIAL_STEP:1);
	}
}

stock Tutorial_Start(playerid)
{
	if (!Session_IsPlaying(playerid))
	{
		return false;
	}

	new E_TUTORIAL_STEP:step = Tutorial_GetResumeStep(playerid);
	TutorialGui_ResetBriefings(playerid);
	Tutorial_SetStep(playerid,step);

	if (step > TUTORIAL_WALK_RACK)
	{
		Gui_Notify(playerid,"You're back where you left off in the tutorial.");
	}

	return true;
}

stock Tutorial_Finish(playerid)
{
	s_TutorialStep[playerid] = TUTORIAL_DONE;
	s_TutorialWelcoming[playerid] = true;
	Kit_ClearHighlights(playerid);
	Character_SetTutorialDone(playerid);
	Inventory_Give(playerid,ITEM_KIND_DRINK,ITEM_WATER_SKIN,1);
	TutorialGui_ShowStep(playerid,TUTORIAL_DONE);
	pawn_call_public("Tutorial_OnFinished","d",playerid);

	if (TutorialIsland_IsOn(playerid))
	{
		DisablePlayerCheckpoint(playerid);
		SetTimerEx("Tutorial_LeaveFade",TUTORIAL_LEAVE_DELAY_MS,false,"dd",playerid,Account_GetToken(playerid));
	}
}

stock Tutorial_Skip(playerid)
{
	if (!Tutorial_IsActive(playerid))
	{
		return false;
	}

	Tutorial_Finish(playerid);
	return true;
}

forward Tutorial_StartDeferred(playerid,token);

public Tutorial_StartDeferred(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Session_HasCharacter(playerid))
	{
		return 1;
	}

	if (!Session_IsPlaying(playerid) || !Inventory_IsLoaded(playerid))
	{
		SetTimerEx("Tutorial_StartDeferred",TUTORIAL_START_RETRY_MS,false,"dd",playerid,token);
		return 1;
	}

	if (s_TutorialStep[playerid] == TUTORIAL_NONE)
	{
		Tutorial_Start(playerid);
	}
	else if (Tutorial_IsActive(playerid))
	{
		Tutorial_EnterStep(playerid);
	}

	return 1;
}

static Tutorial_CountBrawl(playerid,E_FIGHT_ANIM:anim)
{
	new move = -1;

	switch (anim)
	{
		case FIGHT_ANIM_JAB: move = 0;
		case FIGHT_ANIM_LEFT, FIGHT_ANIM_RIGHT: move = 1;
		case FIGHT_ANIM_LOWER: move = 2;
		default: {}
	}

	if (move == -1 || (s_TutorialBrawled[playerid] & (1 << move)))
	{
		return;
	}

	s_TutorialBrawled[playerid] |= 1 << move;

	if (s_TutorialBrawled[playerid] == (1 << TUTORIAL_BRAWL_MOVES) - 1)
	{
		Tutorial_Advance(playerid,TUTORIAL_BRAWL);
		return;
	}

	new left[32];

	for (new i = 0;i < TUTORIAL_BRAWL_MOVES;i++)
	{
		if (!(s_TutorialBrawled[playerid] & (1 << i)))
		{
			if (left[0] != EOS)
			{
				strcat(left,", ");
			}

			strcat(left,s_TutorialBrawlNames[i]);
		}
	}

	Gui_Notify(playerid,sprintf("Good. You still need %s.",left));
}

forward Tutorial_WorkGate(playerid,targetType,target,recipe);

public Tutorial_WorkGate(playerid,targetType,target,recipe)
{
	s_TutorialHeldWork[playerid][0] = targetType;
	s_TutorialHeldWork[playerid][1] = target;
	s_TutorialHeldWork[playerid][2] = recipe;
	TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_WORK);
	return 1;
}

forward Tutorial_CraftGate(playerid);

public Tutorial_CraftGate(playerid)
{
	if (s_TutorialStep[playerid] == TUTORIAL_OPEN_CRAFTING && !TutorialGui_WasBriefed(playerid,TUTORIAL_BRIEF_CRAFTING))
	{
		Tutorial_Advance(playerid,TUTORIAL_OPEN_CRAFTING);
		return 1;
	}

	SetTimerEx("Craft_OpenDeferred",0,false,"d",playerid);
	return 1;
}

Tutorial_OnWorkBriefed(playerid)
{
	if (s_TutorialStep[playerid] == TUTORIAL_COOK && !Work_IsWorking(playerid))
	{
		Work_Start(playerid,s_TutorialHeldWork[playerid][0],s_TutorialHeldWork[playerid][1],s_TutorialHeldWork[playerid][2]);
	}
}

static Tutorial_ShowTabCountdown(playerid,seconds,bool:isBouncing = false)
{
	new text[176];
	format(text,sizeof(text),"%s Continue in %d second%s.",s_TutorialTabText[s_TutorialTabStage[playerid]],seconds,seconds == 1 ? ("") : ("s"));
	TutorialGui_ShowText(playerid,text,isBouncing);
}

forward Tutorial_TabCountdown(playerid,token,seconds);

public Tutorial_TabCountdown(playerid,token,seconds)
{
	if (!IsPlayerConnected(playerid) || token != s_TutorialTabToken[playerid] || !s_TutorialTabReading[playerid] || s_TutorialStep[playerid] != TUTORIAL_OPEN_CHARACTER)
	{
		return 1;
	}

	if (seconds > 0)
	{
		Tutorial_ShowTabCountdown(playerid,seconds);
		SetTimerEx("Tutorial_TabCountdown",1000,false,"ddd",playerid,token,seconds - 1);
		return 1;
	}

	new stage = s_TutorialTabStage[playerid]++, text[176];
	s_TutorialTabReading[playerid] = false;
	format(text,sizeof(text),"%s %s",s_TutorialTabText[stage],s_TutorialTabNextText[stage]);
	TutorialGui_ShowText(playerid,text);
	Kit_AddHighlight(playerid,CHARPANEL_TITLE,s_TutorialTabNext[stage]);
	return 1;
}

forward Tutorial_LeaveFade(playerid,token);

public Tutorial_LeaveFade(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && TutorialIsland_IsOn(playerid))
	{
		ScreenFade_Start(playerid,TUTORIAL_FADE_BLACK,TUTORIAL_LEAVE_FADE_MS,TUTORIAL_LEAVE_FADE_STEPS);
		SetTimerEx("Tutorial_LeaveIsland",TUTORIAL_LEAVE_FADE_MS,false,"dd",playerid,token);
	}

	return 1;
}

forward Tutorial_WelcomeDeferred(playerid,token);

public Tutorial_WelcomeDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_IsPlaying(playerid))
	{
		TutorialGui_ShowBriefing(playerid,TUTORIAL_BRIEF_NEXT);
	}

	return 1;
}

forward Tutorial_LeaveIsland(playerid,token);

public Tutorial_LeaveIsland(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && TutorialIsland_IsOn(playerid))
	{
		TutorialIsland_Leave(playerid);
		s_TutorialWelcomePending[playerid] = true;
		Character_Spawn(playerid);
	}

	return 1;
}

forward Tutorial_OnStep(playerid,step);

public Tutorial_OnStep(playerid,step)
{
	return 1;
}

forward Tutorial_OnFinished(playerid);

public Tutorial_OnFinished(playerid)
{
	return 1;
}

forward Tutorial_OnWelcomed(playerid);

public Tutorial_OnWelcomed(playerid)
{
	return 1;
}

CMD:tutskip(cmdid, playerid, params[])
{
	#pragma unused cmdid, params

	SendClientMessage(playerid,-1,Tutorial_Skip(playerid) ? ("Tutorial skipped.") : ("No tutorial running."));
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_TutorialStep[playerid] = TUTORIAL_NONE;
	s_TutorialTabReading[playerid] = false;
	s_TutorialWelcomePending[playerid] = false;
	s_TutorialWelcoming[playerid] = false;
}

hook CharPanel_OnTab(playerid,tab)
{
	if (s_TutorialStep[playerid] != TUTORIAL_OPEN_CHARACTER || s_TutorialTabReading[playerid] || s_TutorialTabStage[playerid] >= TUTORIAL_TAB_STAGES || tab != s_TutorialTabStage[playerid])
	{
		return;
	}

	s_TutorialTabReading[playerid] = true;
	Kit_ClearHighlights(playerid);
	Tutorial_ShowTabCountdown(playerid,TUTORIAL_TAB_READ_SECONDS,true);
	SetTimerEx("Tutorial_TabCountdown",1000,false,"ddd",playerid,++s_TutorialTabToken[playerid],TUTORIAL_TAB_READ_SECONDS - 1);
}

hook CharPanel_OnClosed(playerid)
{
	if (s_TutorialStep[playerid] != TUTORIAL_OPEN_CHARACTER)
	{
		return;
	}

	Kit_ClearHighlights(playerid);
	s_TutorialTabReading[playerid] = false;
	s_TutorialTabToken[playerid]++;

	if (s_TutorialTabStage[playerid] >= TUTORIAL_TAB_STAGES)
	{
		Tutorial_Advance(playerid,TUTORIAL_OPEN_CHARACTER);
		return;
	}

	s_TutorialTabStage[playerid] = 0;
	TutorialGui_ShowStep(playerid,TUTORIAL_OPEN_CHARACTER);
}

hook Character_OnUnloaded(playerid)
{
	s_TutorialStep[playerid] = TUTORIAL_NONE;
}

hook Character_OnSpawning(playerid)
{
	if (IsPlayerNPC(playerid) || Character_IsTutorialDone(playerid))
	{
		return;
	}

	new Float:x, Float:y, Float:z;
	Tutorial_GetResumeSpot(Tutorial_GetResumeStep(playerid),x,y,z);
	TutorialIsland_Enter(playerid);
	TutorialIsland_SetSpawn(playerid,x,y,z);
	Character_SetNextSpawn(playerid,x,y,z,TUTORIAL_SPAWN_A,0,TutorialIsland_GetWorld(playerid));
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	if (from == SESSION_SPAWNING && to == SESSION_PLAYING && s_TutorialWelcomePending[playerid])
	{
		s_TutorialWelcomePending[playerid] = false;
		SetTimerEx("Tutorial_WelcomeDeferred",TUTORIAL_WELCOME_DELAY_MS,false,"dd",playerid,Account_GetToken(playerid));
	}

	if (from == SESSION_SPAWNING && to == SESSION_PLAYING && TutorialIsland_IsOn(playerid) && !Character_IsTutorialDone(playerid))
	{
		SetTimerEx("Tutorial_StartDeferred",TUTORIAL_START_RETRY_MS,false,"dd",playerid,Account_GetToken(playerid));
	}
}

hook OnPlayerEnterCheckpoint(playerid)
{
	if (!TutorialIsland_IsOn(playerid))
	{
		return;
	}

	switch (s_TutorialStep[playerid])
	{
		case TUTORIAL_WALK_RACK, TUTORIAL_WALK_CAMP, TUTORIAL_RIDE_OUT: Tutorial_Advance(playerid,s_TutorialStep[playerid]);
		default: {}
	}
}

hook Mount_OnMounted(playerid,horseid)
{
	if (TutorialIsland_IsOn(playerid) && horseid == TutorialIsland_GetDonkey(playerid))
	{
		Tutorial_Advance(playerid,TUTORIAL_TO_DONKEY);
	}
}

hook Inventory_OnMenuOpened(playerid)
{
	Tutorial_Advance(playerid,TUTORIAL_OPEN_BAG);
}

hook Combat_OnEquipped(playerid,weapon)
{
	#pragma unused weapon

	if (s_TutorialStep[playerid] == TUTORIAL_CARRY_WEAPON)
	{
		Inventory_CloseBagAfterUse(playerid);
	}

	Tutorial_Advance(playerid,TUTORIAL_CARRY_WEAPON);
}

hook Combat_OnModeChanged(playerid,enabled)
{
	if (enabled)
	{
		Tutorial_Advance(playerid,Combat_IsFistsUp(playerid) ? TUTORIAL_FISTS_UP : TUTORIAL_DRAW);
	}
	else
	{
		Tutorial_Advance(playerid,TUTORIAL_SHEATHE);
	}
}

hook Combat_OnDodge(playerid,bool:isSideways)
{
	if (s_TutorialStep[playerid] != TUTORIAL_DODGE)
	{
		return;
	}

	s_TutorialDodged[playerid] |= isSideways ? TUTORIAL_DODGE_SIDE : TUTORIAL_DODGE_BACK;

	if (s_TutorialDodged[playerid] == (TUTORIAL_DODGE_BACK | TUTORIAL_DODGE_SIDE))
	{
		Combat_SetMode(playerid,false);
		Tutorial_Advance(playerid,TUTORIAL_DODGE);
		return;
	}

	Gui_Notify(playerid,isSideways ? ("Good. Now hold Sprint (Space) and press back to step away.") : ("Good. Now hold Sprint (Space) and press left or right to roll aside."));
}

hook Combat_OnSwing(playerid,anim)
{
	if (s_TutorialStep[playerid] == TUTORIAL_BRAWL)
	{
		Tutorial_CountBrawl(playerid,E_FIGHT_ANIM:anim);
		return;
	}

	if (s_TutorialStep[playerid] != TUTORIAL_SWING || anim < 0 || anim >= TUTORIAL_SWING_SIDES)
	{
		return;
	}

	if (s_TutorialSwung[playerid] & (1 << anim))
	{
		return;
	}

	s_TutorialSwung[playerid] |= 1 << anim;

	if (s_TutorialSwung[playerid] == (1 << TUTORIAL_SWING_SIDES) - 1)
	{
		Tutorial_Advance(playerid,TUTORIAL_SWING);
		return;
	}

	new left[48];

	for (new side = 0;side < TUTORIAL_SWING_SIDES;side++)
	{
		if (!(s_TutorialSwung[playerid] & (1 << side)))
		{
			if (left[0] != EOS)
			{
				strcat(left,", ");
			}

			strcat(left,s_TutorialSideNames[side]);
		}
	}

	Gui_Notify(playerid,sprintf("Good. You still need to swing %s.",left));
}

hook Nametag_OnIntroduced(playerid,told)
{
	#pragma unused told

	Tutorial_Advance(playerid,TUTORIAL_INTRODUCE);
}

hook Craft_OnOpened(playerid)
{
	Tutorial_Advance(playerid,TUTORIAL_OPEN_CRAFTING);
}

hook Work_OnPlacementStarted(playerid,kind)
{
	#pragma unused kind

	Tutorial_Advance(playerid,TUTORIAL_BUILD);
}

hook Work_OnPlacementCancelled(playerid,kind)
{
	#pragma unused kind

	if (s_TutorialStep[playerid] == TUTORIAL_PLACE)
	{
		s_TutorialStep[playerid] = TUTORIAL_OPEN_CRAFTING;
		Kit_ClearHighlights(playerid);
		Kit_AddHighlight(playerid,"Your bag",Inventory_GetMenuButtonValue("Crafting"));
		TutorialGui_ShowStep(playerid,TUTORIAL_OPEN_CRAFTING);
	}
}

hook Work_OnStationPlaced(playerid,stationid)
{
	#pragma unused stationid

	Tutorial_Advance(playerid,TUTORIAL_PLACE);
}

hook Work_OnFinished(playerid,recipe,stars)
{
	#pragma unused stars

	if (recipe == Recipe_FindByName("Roast fish"))
	{
		Tutorial_Advance(playerid,TUTORIAL_COOK);
	}
}

hook Work_OnRuined(playerid,recipe,stage)
{
	#pragma unused stage

	if (recipe == Recipe_FindByName("Roast fish") && s_TutorialStep[playerid] == TUTORIAL_COOK)
	{
		Inventory_Give(playerid,ITEM_KIND_MATERIAL,ITEM_FISH,1);
		Gui_Notify(playerid,"You burnt the fish! Here's a fresh one, give it another go.");
	}
}
