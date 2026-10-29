enum E_ACTOR_MENU
{
	E_ACTOR_MENU_LABEL[ACTORS_MENU_LABEL],
	E_ACTOR_MENU_CALLBACK[32],
	E_ACTOR_MENU_DATA,
	E_ACTOR_MENU_COLOUR,
}

static s_ActorMenu[MAX_PLAYERS][ACTORS_MENU_MAX][E_ACTOR_MENU];
static s_ActorMenuCount[MAX_PLAYERS];
static s_ActorMenuActor[MAX_PLAYERS] = {-1, ...};
static s_ActorPromptTarget[MAX_PLAYERS] = {-1, ...};
static s_ActorPromptShownTarget[MAX_PLAYERS] = {-1, ...};
static s_ActorReleasedPrompt[MAX_PLAYERS] = {-1, ...};
static s_ActorPromptInfobox[MAX_PLAYERS];
static s_ActorPromptTakenAt[MAX_PLAYERS];
static s_ActorRemarkAt[MAX_PLAYERS];

new const g_ActorStinkRemarks[][64] = {
	"Phew, what is that smell?",
	"God's teeth, you could do with a wash.",
	"Stand downwind, would you?",
	"Have you been sleeping with the pigs?",
	"The flies love you, at least.",
	"There's a washtub at the market, you know."
};

new const g_ActorReekRemarks[][64] = {
	"Get away from me! You smell like a dead dog.",
	"Saints preserve us, the stink of you.",
	"Wash, for the love of God. Wash."
};

stock Actors_MenuAdd(playerid,const label[],const callback[],data = 0,colour = KIT_COLOUR_TEXT)
{
	if (!Util_IsValidPlayer(playerid) || s_ActorMenuCount[playerid] >= ACTORS_MENU_MAX)
	{
		return;
	}

	new slot = s_ActorMenuCount[playerid]++;
	strcopy(s_ActorMenu[playerid][slot][E_ACTOR_MENU_LABEL],label,ACTORS_MENU_LABEL);
	strcopy(s_ActorMenu[playerid][slot][E_ACTOR_MENU_CALLBACK],callback,32);
	s_ActorMenu[playerid][slot][E_ACTOR_MENU_DATA] = data;
	s_ActorMenu[playerid][slot][E_ACTOR_MENU_COLOUR] = colour;
}

stock Actors_FindMenuRow(playerid,const label[])
{
	if (!Util_IsValidPlayer(playerid))
	{
		return -1;
	}

	for (new i = 0;i < s_ActorMenuCount[playerid];i++)
	{
		if (!strcmp(s_ActorMenu[playerid][i][E_ACTOR_MENU_LABEL],label))
		{
			return i;
		}
	}

	return -1;
}

stock Actors_GetMenuActor(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_ActorMenuActor[playerid] : -1;
}

stock Actors_GetPromptTarget(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_ActorPromptTarget[playerid] : -1;
}

stock Actors_ClearPrompt(playerid)
{
	if (s_ActorPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_ActorPromptInfobox[playerid]);
	}

	s_ActorPromptTarget[playerid] = -1;
    s_ActorPromptShownTarget[playerid] = -1;
	s_ActorPromptInfobox[playerid] = 0;
    Actors_SetApproached(playerid,-1);
}

stock Actors_ReleasePrompt(playerid,index)
{
	Actors_ClearPrompt(playerid);
	s_ActorReleasedPrompt[playerid] = index;
}

stock Actors_ForgetReleasedPrompt(playerid,index)
{
	if (s_ActorReleasedPrompt[playerid] == index)
	{
		s_ActorReleasedPrompt[playerid] = -1;
	}
}

stock bool:Actors_IsFacing(Float:px,Float:py,Float:pa,Float:ax,Float:ay)
{
	new Float:diff = atan2(ay - py,ax - px) - 90.0 - pa;

	while (diff > 180.0)
	{
		diff -= 360.0;
	}

	while (diff < -180.0)
	{
		diff += 360.0;
	}

	return floatabs(diff) <= ACTORS_FACING_CONE;
}

stock bool:Actors_GetTalkPos(index,&Float:x,&Float:y,&Float:z)
{
    if (!Actors_IsPlaced(index))
    {
        return false;
    }

    new body = Actors_GetBody(index);
    if (IsValidPedestrian(body) == 1)
    {
        return GetPedestrianPos(body,x,y,z) != 0;
    }

    return Actors_GetPos(index,x,y,z);
}

stock bool:Actors_IsFacedBy(playerid,index)
{
	new Float:px, Float:py, Float:pz, Float:pa, Float:ax, Float:ay, Float:az;
	GetPlayerPos(playerid,px,py,pz);
	GetPlayerFacingAngle(playerid,pa);
	Actors_GetTalkPos(index,ax,ay,az);
	return Actors_IsFacing(px,py,pa,ax,ay);
}

stock Actors_FindFacedNear(playerid,bool:facedOnly = true)
{
	new best = -1, Float:bestDistance = ACTORS_REACH, world = GetPlayerVirtualWorld(playerid), Float:px, Float:py, Float:pz, Float:pa;
	GetPlayerPos(playerid,px,py,pz);
	GetPlayerFacingAngle(playerid,pa);

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (!Actors_IsPlaced(i) || Actors_GetWorld(i) != world || Actors_IsDead(i) || !Actors_IsOpen(i) || Actors_GetRole(i) == ACTOR_ROLE_BANDIT)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
        if (!Actors_GetTalkPos(i,x,y,z))
        {
            continue;
        }
		new Float:distance = VectorSize(x - px,y - py,z - pz);

		if (distance < bestDistance && (!facedOnly || Actors_IsFacing(px,py,pa,x,y)))
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock bool:Actors_IsRoadTalkTarget(index)
{
    new body = Actors_GetBody(index);
    return Actors_IsPlaced(index) && (Actors_IsWalking(index) || (IsValidPedestrian(body) == 1 && Actors_FindWalkerKind(GetPedestrianKind(body)) != -1));
}

stock Float:Actors_ReachOf(index)
{
    return Actors_IsRoadTalkTarget(index) ? ACTORS_ROAD_REACH : ACTORS_REACH;
}

forward bool:Families_IsGuest(playerid);

stock bool:Actors_CanTalkTo(playerid,index)
{
    if (!Session_IsPlaying(playerid) || Families_IsGuest(playerid) || Gui_IsBusy(playerid) || Dialogue_IsTalking(playerid) || Infirmary_HasPrompt(playerid) || Law_IsBound(playerid) || Law_IsServing(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || !Actors_IsPlaced(index) || !Actors_IsOpen(index) || Actors_GetRole(index) == ACTOR_ROLE_BANDIT || Actors_GetWorld(index) != GetPlayerVirtualWorld(playerid))
    {
        return false;
    }

    new Float:x, Float:y, Float:z;
    if (!Actors_GetTalkPos(index,x,y,z))
    {
        return false;
    }
    return IsPlayerInRangeOfPoint(playerid,Actors_ReachOf(index),x,y,z) && (!Actors_IsRoadTalkTarget(index) || Actors_IsFacedBy(playerid,index));
}

stock Actors_FindPedestrianNear(playerid)
{
    new Float:px, Float:py, Float:pz, Float:pa, Float:nearest = ACTORS_ROAD_REACH, target = -1;
    GetPlayerPos(playerid,px,py,pz);
    GetPlayerFacingAngle(playerid,pa);
    new bodies[WALKERS_POOL], count = GetPedestriansInRange(px,py,pz,ACTORS_ROAD_REACH,bodies,sizeof(bodies));

    for (new i = 0;i < count;i++)
    {
        new body = bodies[i], actor = Actors_FindByBody(body);
        if (IsValidPedestrian(body) != 1 || !Actors_IsRoadTalkTarget(actor) || !Actors_CanTalkTo(playerid,actor))
        {
            continue;
        }

        new Float:x, Float:y, Float:z;
        if (!GetPedestrianPos(body,x,y,z))
        {
            continue;
        }
        new Float:distance = VectorSize(x - px,y - py,z - pz);
        if (distance < nearest && Actors_IsFacing(px,py,pa,x,y))
        {
            target = actor;
            nearest = distance;
        }
    }

    return target;
}

stock Actors_RegisterWalkersNear(playerid)
{
    new Float:x, Float:y, Float:z, bodies[WALKERS_POOL];
    GetPlayerPos(playerid,x,y,z);
    new count = GetPedestriansInRange(x,y,z,ACTORS_ROAD_REACH,bodies,sizeof(bodies));
    for (new i = 0; i < count; i++)
    {
        if (GetActorVirtualWorld(bodies[i]) == GetPlayerVirtualWorld(playerid))
        {
            Actors_EnsureWalker(bodies[i]);
        }
    }
}

stock Actors_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Dialogue_IsTalking(playerid) || Gui_IsBusy(playerid) || Infirmary_HasPrompt(playerid) || Law_IsBound(playerid) || Law_IsServing(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Actors_ClearPrompt(playerid);
		return;
	}

    Actors_RegisterWalkersNear(playerid);
    new target = Actors_FindPedestrianNear(playerid);
    if (target == -1)
    {
        target = Actors_FindFacedNear(playerid);
    }

    if (target == -1)
    {
        target = Actors_FindFacedNear(playerid,false);
        if (Actors_IsRoadTalkTarget(target))
        {
            target = -1;
        }
    }

    if (target != s_ActorReleasedPrompt[playerid])
    {
        s_ActorReleasedPrompt[playerid] = -1;
    }

	if (target == -1 || !Actors_IsOpen(target) || Keys_IsBusy(playerid,KEY_YES,ACTORS_KEY_PRIO))
	{
		Actors_ClearPrompt(playerid);
		return;
	}

	if (!Actors_IsFacedBy(playerid,target))
	{
		new was = s_ActorPromptTarget[playerid];
		s_ActorPromptTarget[playerid] = -1;
		new bool:other = Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_WORLD);
		s_ActorPromptTarget[playerid] = was;

		if (other)
		{
			Actors_ClearPrompt(playerid);
			return;
		}
	}

    if (Actors_IsRoadTalkTarget(target))
    {
        Actors_SetApproached(playerid,-1);
    }

	if (target == s_ActorPromptShownTarget[playerid] && s_ActorPromptInfobox[playerid] > 0 && Infobox_IsShown(playerid,s_ActorPromptInfobox[playerid]))
	{
        s_ActorPromptTarget[playerid] = target;
		return;
	}

	new name[ACTORS_NAME_LEN], title[ACTORS_TITLE_LEN], text[96];
	Actors_GetName(target,name);
	Actors_GetTitle(target,title);
	format(text,sizeof(text),"%s~n~Press ~y~Y~w~ to open %s conversation panel.",title,Actors_GetSex(target) ? ("her") : ("his"));
	text[0] = toupper(text[0]);
    s_ActorPromptTarget[playerid] = target;
    new token = Infobox_ShowPrompt(playerid,s_ActorPromptInfobox[playerid],name,text,3);
    if (token != INFOBOX_REFUSED)
    {
        s_ActorPromptInfobox[playerid] = token;
        s_ActorPromptShownTarget[playerid] = target;
    }
    Actors_SetApproached(playerid,!Actors_IsRoadTalkTarget(target) && target != s_ActorReleasedPrompt[playerid] && target == s_ActorPromptShownTarget[playerid] && s_ActorPromptInfobox[playerid] > 0 && Infobox_IsShown(playerid,s_ActorPromptInfobox[playerid]) ? target : -1);
}

stock bool:Actors_TryTalk(playerid)
{
    if (!Util_IsValidPlayer(playerid))
    {
        return false;
    }

    Actors_RegisterWalkersNear(playerid);
    if (Infobox_IsPromptBlocked(playerid,s_ActorPromptInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,ACTORS_KEY_PRIO))
    {
        return false;
    }

    new target = Actors_FindPedestrianNear(playerid);
    if (target == -1)
    {
        if (s_ActorPromptTarget[playerid] == -1 || s_ActorPromptTarget[playerid] != s_ActorPromptShownTarget[playerid] || s_ActorPromptInfobox[playerid] <= 0 || !Infobox_IsShown(playerid,s_ActorPromptInfobox[playerid]))
        {
            return false;
        }
        target = s_ActorPromptTarget[playerid];
    }

    if (!Actors_CanTalkTo(playerid,target))
    {
        return false;
    }

    if (Actors_IsRoadTalkTarget(target))
    {
        Walkers_SetTalkPaused(Actors_GetBody(target),true);
    }

	s_ActorReleasedPrompt[playerid] = -1;
	Actors_SetMenuTalking(playerid,target);
    if (Actors_IsRoadTalkTarget(target))
    {
        new Float:px, Float:py, Float:pz;
        GetPlayerPos(playerid,px,py,pz);
        Actors_FaceTowards(target,px,py);
    }
	Actors_ClearPrompt(playerid);
	s_ActorPromptTakenAt[playerid] = GetTickCount();
	SetTimerEx("Actors_MenuDeferred",0,false,"dd",playerid,target);
    return true;
}

stock Actors_OpenMenu(playerid,index)
{
	if (!Actors_IsOpen(index) || !Actors_IsPlaced(index))
	{
        Actors_SetMenuTalking(playerid,-1);
		return;
	}

	new epoch = Gui_BeginFlow(playerid);
	Actors_SetMenuTalking(playerid,index);
	s_ActorMenuActor[playerid] = index;
	s_ActorMenuCount[playerid] = 0;
	pawn_call_public("Actors_OnMenuOpen","dd",playerid,index);
	pawn_call_public("Actors_OnMenuBuild","dd",playerid,index);

	new name[ACTORS_NAME_LEN], Float:x, Float:y, Float:width, count = s_ActorMenuCount[playerid];
	Actors_GetName(index,name);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,ACTORS_MENU_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);

	if (count == 0)
	{
		Kit_AddText(playerid,x,y,"They have nothing for you.",KIT_COLOUR_MUTED);
	}

	for (new i = 0;i < count;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,s_ActorMenu[playerid][i][E_ACTOR_MENU_LABEL],i,s_ActorMenu[playerid][i][E_ACTOR_MENU_COLOUR]);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count > 0 ? count : 1) * KIT_ROW + 8.0,80.0,"Goodbye",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	Actors_SetMenuTalking(playerid,-1);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= s_ActorMenuCount[playerid])
	{
		s_ActorMenuActor[playerid] = -1;
		return;
	}

	SetTimerEx(s_ActorMenu[playerid][pick][E_ACTOR_MENU_CALLBACK],0,false,"ddd",playerid,index,s_ActorMenu[playerid][pick][E_ACTOR_MENU_DATA]);
}

static Actors_Remark(playerid)
{
	new now = gettime();

	if (!Hygiene_IsStinking(playerid) || now < s_ActorRemarkAt[playerid] || random(100) >= ACTORS_REMARK_CHANCE)
	{
		return;
	}

	new actor = Actors_FindNear(playerid,ACTORS_REMARK_RANGE);

	if (actor == -1 || Actors_IsWalking(actor))
	{
		return;
	}

	s_ActorRemarkAt[playerid] = now + ACTORS_REMARK_SECONDS;

	if (Hygiene_IsReeking(playerid))
	{
		Actors_Say(actor,g_ActorReekRemarks[random(sizeof(g_ActorReekRemarks))]);
	}
	else
	{
		Actors_Say(actor,g_ActorStinkRemarks[random(sizeof(g_ActorStinkRemarks))]);
	}
}

Timer_Declare(Actors_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Actors_UpdatePrompt(playerid);
			Actors_Remark(playerid);
		}
	}

	return 1;
}

forward Actors_MenuDeferred(playerid,index);

public Actors_MenuDeferred(playerid,index)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
        new Float:x, Float:y, Float:z;
        Actors_GetTalkPos(index,x,y,z);
        if (!Actors_IsOpen(index) || !Actors_IsPlaced(index) || Actors_GetWorld(index) != GetPlayerVirtualWorld(playerid) || !IsPlayerInRangeOfPoint(playerid,Actors_ReachOf(index),x,y,z) || Gui_IsBusy(playerid))
        {
            Actors_SetMenuTalking(playerid,-1);
            return 1;
        }

        if (Actors_IsRoadTalkTarget(index))
        {
            Dialogue_Start(playerid,index);
            Actors_SetMenuTalking(playerid,-1);
        }
        else
        {
            Actors_OpenMenu(playerid,index);
        }
	}
    else
    {
        Actors_SetMenuTalking(playerid,-1);
    }

	return 1;
}

forward bool:Actors_PromptContext(playerid);

public bool:Actors_PromptContext(playerid)
{
    if (Actors_FindPedestrianNear(playerid) != -1 && !Infobox_IsPromptBlocked(playerid,s_ActorPromptInfobox[playerid]))
    {
        return true;
    }

	return !Infirmary_HasPrompt(playerid) && ((s_ActorPromptTarget[playerid] != -1 && s_ActorPromptTarget[playerid] == s_ActorPromptShownTarget[playerid] && s_ActorPromptInfobox[playerid] > 0 && Infobox_IsShown(playerid,s_ActorPromptInfobox[playerid])) || (s_ActorPromptTakenAt[playerid] != 0 && GetTickCount() - s_ActorPromptTakenAt[playerid] < ACTORS_PROMPT_HOLD_MS));
}

forward Actors_OnMenuOpen(playerid,index);

public Actors_OnMenuOpen(playerid,index)
{
	return 1;
}

forward Actors_OnMenuBuild(playerid,index);

public Actors_OnMenuBuild(playerid,index)
{
    new key[ACTORS_KEY_LEN];
    Actors_GetKey(index,key);

    if (Actors_GetRole(index) == ACTOR_ROLE_TRADER && Trader_IsValid(Actors_GetOwner(index)) && Trader_IsOpen())
    {
        Actors_MenuAdd(playerid,"Trade","Actors_TradeDeferred",Actors_GetOwner(index));
    }

    if (strfind(key,"regular:") == 0)
    {
        Actors_MenuAdd(playerid,"Play a game","Actors_GameDeferred",strval(key[8]));
    }

    if (strfind(key,"rider:") == 0 && Actors_GetBody(index) == Coach_GetRider())
    {
        Actors_MenuAdd(playerid,"Buy a coach seat","Actors_CoachDeferred");
    }

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_ActorReleasedPrompt[playerid] = -1;
    Actors_SetApproached(playerid,-1);
	Actors_SetTalking(playerid,-1);
	Actors_SetMenuTalking(playerid,-1);
	s_ActorPromptTarget[playerid] = -1;
    s_ActorPromptShownTarget[playerid] = -1;
	s_ActorPromptInfobox[playerid] = 0;
	s_ActorPromptTakenAt[playerid] = 0;
	s_ActorRemarkAt[playerid] = 0;
	s_ActorMenuActor[playerid] = -1;
	s_ActorMenuCount[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
    if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES))
    {
        Actors_TryTalk(playerid);
    }
}

hook ResetPlayerVariables(playerid)
{
	s_ActorReleasedPrompt[playerid] = -1;
    Actors_ResetTalkHolds(playerid);
    Actors_ClearPrompt(playerid);
}

forward Actors_TradeDeferred(playerid,index,trader);

public Actors_TradeDeferred(playerid,index,trader)
{
    if (Session_IsPlaying(playerid) && Actors_IsOpen(index) && Actors_GetOwner(index) == trader && Trader_IsOpen())
    {
        SetTimerEx("Trader_OpenDeferred",0,false,"dd",playerid,trader);
    }

    return 1;
}

forward Actors_GameDeferred(playerid,index,regular);

public Actors_GameDeferred(playerid,index,regular)
{
    if (Session_IsPlaying(playerid) && Actors_IsOpen(index) && Table_IsValidRegular(regular))
    {
        SetTimerEx("Table_ChooseDeferred",0,false,"dd",playerid,regular);
    }

    return 1;
}

forward Actors_CoachDeferred(playerid,index,data);

public Actors_CoachDeferred(playerid,index,data)
{
    #pragma unused data

    if (Session_IsPlaying(playerid) && Actors_IsOpen(index))
    {
        SetTimerEx("Coach_BoardDeferred",0,false,"d",playerid);
    }

    return 1;
}
