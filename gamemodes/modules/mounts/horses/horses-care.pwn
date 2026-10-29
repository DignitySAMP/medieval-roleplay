#define HORSES_SCENE_TICK_MS (50)
#define HORSES_SCENE_LAUNCH_MS (600)
#define HORSES_SCENE_ABORT_TICKS (20)
#define HORSES_SCENE_STAGES (4)

enum
{
	HORSES_SCENE_NONE,
	HORSES_SCENE_FEED,
	HORSES_SCENE_WATER,
	HORSES_SCENE_GROOM,
	HORSES_SCENE_SHOE,
	HORSES_SCENE_TAME,
}

enum E_HORSES_SCENE
{
	E_HS_KIND,
	E_HS_HORSE,
	E_HS_STAGE,
	E_HS_STAGES,
	E_HS_KINDS[HORSES_SCENE_STAGES],
	E_HS_EASE[HORSES_SCENE_STAGES],
	E_HS_SCORES[HORSES_SCENE_STAGES],
	E_HS_TIMER,
	KEY:E_HS_OLD_KEYS,
	E_HS_STAGE_AT,
	E_HS_N_TICKS,
	E_HS_ITEM,
	E_HS_TICK,
	Float:E_HS_FROM[3],
}

static s_HorseScene[MAX_PLAYERS][E_HORSES_SCENE];
static s_HorseTameTick[MAX_PLAYERS];
static s_WildCooldown[MAX_HORSES];
static s_MeadowSpookedUntil[HORSE_SEED_MEADOWS + 1];
static s_MeadowHorse[HORSE_SEED_MEADOWS + 1][HORSE_MEADOW_SPOTS];
static s_MeadowRespawnAt[HORSE_SEED_MEADOWS + 1][HORSE_MEADOW_SPOTS];
static s_HorseCarePrompt[MAX_PLAYERS] = {INVALID_HORSE_ID, ...};
static s_HorseCareInfobox[MAX_PLAYERS];

static const s_HorseSceneTitles[][24] = {"", "Feeding", "Watering", "Grooming", "Shoeing", "Taming"};
static const s_HorseTameStages[HORSES_SCENE_STAGES][48] = {
	"Approach it slowly: keep it calm",
	"Gentle it: stroke in time with its breath",
	"Halter and blanket it",
	"The first ride: stay on"
};

stock bool:Horses_IsInScene(playerid)
{
	return Util_IsValidPlayer(playerid) && s_HorseScene[playerid][E_HS_KIND] != HORSES_SCENE_NONE;
}

static bool:Horses_InReach(playerid,horseid,Float:range = HORSES_CARE_RANGE)
{
	if (!Horse_IsValid(horseid) || Horse_GetRider(horseid) != INVALID_PLAYER_ID)
	{
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Horse_GetPos(horseid,x,y,z,a);
	return GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,range,x,y,z + 1.0);
}

static Horses_SceneStageText(playerid,dest[],size = sizeof(dest))
{
	new kind = s_HorseScene[playerid][E_HS_KIND], stage = s_HorseScene[playerid][E_HS_STAGE];

	switch (kind)
	{
		case HORSES_SCENE_FEED: strcopy(dest,"Pour the feed into its nosebag",size);
		case HORSES_SCENE_WATER: strcopy(dest,"Let it drink its fill",size);
		case HORSES_SCENE_GROOM: strcopy(dest,"Rub it down with a wisp of straw",size);
		case HORSES_SCENE_SHOE:
		{
			if (stage == 0)
			{
				strcopy(dest,"Lift the hoof and pare it",size);
			}
			else
			{
				strcopy(dest,"Set the shoe and drive the nails",size);
			}
		}
		case HORSES_SCENE_TAME: strcopy(dest,s_HorseTameStages[Util_ClampInt(stage,0,HORSES_SCENE_STAGES - 1)],size);
		default: dest[0] = EOS;
	}
}

static Horses_BeginStage(playerid)
{
	new stage = s_HorseScene[playerid][E_HS_STAGE], kind = s_HorseScene[playerid][E_HS_KINDS][stage], title[64], hint[96];
	Work_BeginChallenge(playerid,kind,s_HorseScene[playerid][E_HS_EASE][stage]);
	s_HorseScene[playerid][E_HS_STAGE_AT] = GetTickCount();
	Horses_SceneStageText(playerid,title);
	Work_GetChallengeHint(kind,hint);
	Work_SetPanelLines(playerid,title,"_",hint);
	Work_UpdateGlyphs(playerid);
}

static bool:Horses_StartScene(playerid,horseid,kind,item = 0)
{
	if (Horses_IsInScene(playerid) || Gui_IsBusy(playerid) || Mount_IsRiding(playerid))
	{
		return false;
	}

	s_HorseScene[playerid][E_HS_KIND] = kind;
	s_HorseScene[playerid][E_HS_HORSE] = horseid;
	s_HorseScene[playerid][E_HS_STAGE] = 0;
	s_HorseScene[playerid][E_HS_ITEM] = item;
	s_HorseScene[playerid][E_HS_N_TICKS] = 0;
	s_HorseScene[playerid][E_HS_TICK] = 0;
	GetPlayerPos(playerid,s_HorseScene[playerid][E_HS_FROM][0],s_HorseScene[playerid][E_HS_FROM][1],s_HorseScene[playerid][E_HS_FROM][2]);

	for (new i = 0;i < HORSES_SCENE_STAGES;i++)
	{
		s_HorseScene[playerid][E_HS_SCORES][i] = -1;
		s_HorseScene[playerid][E_HS_EASE][i] = 6;
	}

	switch (kind)
	{
		case HORSES_SCENE_FEED:
		{
			s_HorseScene[playerid][E_HS_STAGES] = 1;
			s_HorseScene[playerid][E_HS_KINDS][0] = CHALLENGE_SEQUENCE;
			s_HorseScene[playerid][E_HS_EASE][0] = 9;
		}
		case HORSES_SCENE_WATER:
		{
			s_HorseScene[playerid][E_HS_STAGES] = 1;
			s_HorseScene[playerid][E_HS_KINDS][0] = CHALLENGE_WAIT;
			Work_SetChallengeTuning(playerid,0,4000);
		}
		case HORSES_SCENE_GROOM:
		{
			s_HorseScene[playerid][E_HS_STAGES] = 1;
			s_HorseScene[playerid][E_HS_KINDS][0] = CHALLENGE_RHYTHM;
			s_HorseScene[playerid][E_HS_EASE][0] = 7;
		}
		case HORSES_SCENE_SHOE:
		{
			s_HorseScene[playerid][E_HS_STAGES] = 2;
			s_HorseScene[playerid][E_HS_KINDS][0] = CHALLENGE_SEQUENCE;
			s_HorseScene[playerid][E_HS_KINDS][1] = CHALLENGE_TIMING;
			s_HorseScene[playerid][E_HS_EASE][0] = 5;
			s_HorseScene[playerid][E_HS_EASE][1] = 5;
		}
		case HORSES_SCENE_TAME:
		{
			new temper = Horses_StatTier(horseid,HORSES_LOCUS_TMP);
			s_HorseScene[playerid][E_HS_STAGES] = 4;
			s_HorseScene[playerid][E_HS_KINDS][0] = CHALLENGE_HOLD;
			s_HorseScene[playerid][E_HS_KINDS][1] = CHALLENGE_RHYTHM;
			s_HorseScene[playerid][E_HS_KINDS][2] = CHALLENGE_SEQUENCE;
			s_HorseScene[playerid][E_HS_KINDS][3] = CHALLENGE_TIMING;
			s_HorseScene[playerid][E_HS_EASE][0] = temper == 2 ? 6 : 4;
			s_HorseScene[playerid][E_HS_EASE][1] = temper == 0 ? 7 : 4;
			s_HorseScene[playerid][E_HS_EASE][2] = temper == 1 ? 2 : 4;
			s_HorseScene[playerid][E_HS_EASE][3] = temper == 2 ? 5 : 3;
			Work_SetChallengeTuning(playerid,temper == 1 ? 50 : 25,0);
			Horse_SetHold(horseid,"Someone is haltering this horse.");
		}
	}

	new Float:x, Float:y, Float:z, Float:a, Float:px, Float:py, Float:pz;
	Horse_GetPos(horseid,x,y,z,a);
	GetPlayerPos(playerid,px,py,pz);
	SetPlayerFacingAngle(playerid,atan2(y - py,x - px) - 90.0);

	switch (kind)
	{
		case HORSES_SCENE_FEED, HORSES_SCENE_SHOE: ApplyAnimation(playerid,"BOMBER","BOM_Plant_Loop",4.1,true,false,false,false,0,SYNC_ALL);
		case HORSES_SCENE_GROOM: ApplyAnimation(playerid,"CASINO","dealone",4.1,true,false,false,false,0,SYNC_ALL);
		case HORSES_SCENE_TAME: ApplyAnimation(playerid,"PED","IDLE_stance",4.1,true,false,false,false,0,SYNC_ALL);
		default: ApplyAnimation(playerid,"PED","IDLE_stance",4.1,true,false,false,false,0,SYNC_ALL);
	}

	Work_ShowPanel(playerid,s_HorseSceneTitles[kind]);
	s_HorseScene[playerid][E_HS_OLD_KEYS] = KEY:0;
	Horses_BeginStage(playerid);
	s_HorseScene[playerid][E_HS_TIMER] = SetTimerEx("Horses_SceneTick",HORSES_SCENE_TICK_MS,true,"d",playerid);
	return true;
}

static Horses_EndScene(playerid)
{
	if (s_HorseScene[playerid][E_HS_TIMER] != 0)
	{
		KillTimer(s_HorseScene[playerid][E_HS_TIMER]);
		s_HorseScene[playerid][E_HS_TIMER] = 0;
	}

	new horseid = s_HorseScene[playerid][E_HS_HORSE];

	if (s_HorseScene[playerid][E_HS_KIND] == HORSES_SCENE_TAME && Horse_IsValid(horseid))
	{
		Horse_SetHold(horseid,"");
	}

	s_HorseScene[playerid][E_HS_KIND] = HORSES_SCENE_NONE;
	Work_HidePanel(playerid);
	ClearAnimations(playerid,SYNC_ALL);
}

stock Horses_AbortScene(playerid,const message[] = "")
{
	if (!Horses_IsInScene(playerid))
	{
		return;
	}

	new kind = s_HorseScene[playerid][E_HS_KIND], horseid = s_HorseScene[playerid][E_HS_HORSE];
	Horses_EndScene(playerid);

	if (kind == HORSES_SCENE_TAME && Horses_IsWild(horseid))
	{
		Horses_WildBolts(horseid);
	}

	if (message[0] != EOS)
	{
		Gui_Notify(playerid,message);
	}
}

static Horses_FinishScene(playerid)
{
	new kind = s_HorseScene[playerid][E_HS_KIND], horseid = s_HorseScene[playerid][E_HS_HORSE], item = s_HorseScene[playerid][E_HS_ITEM], total = 0, worst = 3, name[HORSES_NAME_LEN];

	for (new i = 0;i < s_HorseScene[playerid][E_HS_STAGES];i++)
	{
		total += s_HorseScene[playerid][E_HS_SCORES][i];
		worst = min(worst,s_HorseScene[playerid][E_HS_SCORES][i]);
	}

	Horses_EndScene(playerid);
	Horses_GetHorseName(horseid,name);

	if (!Horse_IsValid(horseid))
	{
		return;
	}

	switch (kind)
	{
		case HORSES_SCENE_FEED:
		{
			if (!Inventory_Take(playerid,Item_GetDefKind(item),item,1))
			{
				Gui_Notify(playerid,"The feed is gone from your bag.");
				return;
			}

			Horses_Feed(horseid,item == ITEM_HAY ? HORSES_HAY : HORSES_OATS);
			Gui_Notify(playerid,sprintf("%s eats from your hand.",name));
		}
		case HORSES_SCENE_WATER:
		{
			if (item > 0 && !Inventory_Take(playerid,Item_GetDefKind(item),item,1))
			{
				Gui_Notify(playerid,"The water is gone from your bag.");
				return;
			}

			Horses_Water(horseid);
			Gui_Notify(playerid,sprintf("%s drinks deep.",name));
		}
		case HORSES_SCENE_GROOM:
		{
			if (worst <= 0)
			{
				Gui_Notify(playerid,sprintf("%s fidgets and you give up the grooming.",name));
				return;
			}

			Inventory_Take(playerid,Item_GetDefKind(ITEM_STRAW),ITEM_STRAW,1);
			Horses_Groom(horseid);
			Gui_Notify(playerid,sprintf("%s's coat shines. It leans into you.",name));
		}
		case HORSES_SCENE_SHOE:
		{
			if (worst <= 0)
			{
				Gui_Notify(playerid,"A nail goes in crooked. You pull the shoe and try again later.");
				return;
			}

			if (!Inventory_Take(playerid,Item_GetDefKind(ITEM_HORSESHOES),ITEM_HORSESHOES,1))
			{
				Gui_Notify(playerid,"The horseshoes are gone from your bag.");
				return;
			}

			Horses_Shoe(horseid);
			Gui_Notify(playerid,sprintf("%s is shod. Shoes last a long road.",name));
		}
		case HORSES_SCENE_TAME:
		{
			if (worst <= 1)
			{
				if (s_HorseScene[playerid][E_HS_SCORES][3] != -1 && s_HorseScene[playerid][E_HS_SCORES][3] <= 1)
				{
					ApplyAnimation(playerid,"PED","KO_skid_front",4.1,false,true,true,false,0,SYNC_ALL);
					Vitals_Damage(playerid,8.0,"thrown by a wild horse");
					Gui_Notify(playerid,"It bucks you off and bolts. Wild horses don't forgive a bad seat.");
				}
				else
				{
					Gui_Notify(playerid,"It throws up its head and bolts. Come back calmer in a while.");
				}

				Horses_WildBolts(horseid);
				return;
			}

			Horses_TameDone(playerid,horseid,total);
		}
	}
}

forward Horses_SceneTick(playerid);

public Horses_SceneTick(playerid)
{
	if (!IsPlayerConnected(playerid) || !Horses_IsInScene(playerid))
	{
		return 1;
	}

	new horseid = s_HorseScene[playerid][E_HS_HORSE];

	if (!Horse_IsValid(horseid) || !IsPlayerInRangeOfPoint(playerid,4.0,s_HorseScene[playerid][E_HS_FROM][0],s_HorseScene[playerid][E_HS_FROM][1],s_HorseScene[playerid][E_HS_FROM][2]))
	{
		Horses_AbortScene(playerid,"You step away.");
		return 1;
	}

	new KEY:keys, updown, leftright, KEY:oldKeys = s_HorseScene[playerid][E_HS_OLD_KEYS];
	GetPlayerKeys(playerid,keys,updown,leftright);
	s_HorseScene[playerid][E_HS_OLD_KEYS] = keys;
	s_HorseScene[playerid][E_HS_TICK]++;

	if (keys & KEY_NO)
	{
		if (++s_HorseScene[playerid][E_HS_N_TICKS] >= HORSES_SCENE_ABORT_TICKS)
		{
			Horses_AbortScene(playerid,"You leave off.");
			return 1;
		}
	}
	else
	{
		s_HorseScene[playerid][E_HS_N_TICKS] = 0;
	}

	if (s_HorseScene[playerid][E_HS_KIND] == HORSES_SCENE_TAME && s_HorseScene[playerid][E_HS_STAGE] == 0 && updown != 0)
	{
		Horses_AbortScene(playerid,"It startles at your step and bolts.");
		return 1;
	}

	if (GetTickCount() - s_HorseScene[playerid][E_HS_STAGE_AT] < HORSES_SCENE_LAUNCH_MS)
	{
		return 1;
	}

	Work_ChallengeInput(playerid,keys,oldKeys);
	new score = Work_GetChallengeScore(playerid);

	if (score != -1)
	{
		new stage = s_HorseScene[playerid][E_HS_STAGE];
		s_HorseScene[playerid][E_HS_SCORES][stage] = score;

		if (s_HorseScene[playerid][E_HS_KIND] == HORSES_SCENE_TAME && score <= 1)
		{
			Horses_FinishScene(playerid);
			return 1;
		}

		if (++s_HorseScene[playerid][E_HS_STAGE] >= s_HorseScene[playerid][E_HS_STAGES])
		{
			Horses_FinishScene(playerid);
			return 1;
		}

		Horses_BeginStage(playerid);
		return 1;
	}

	if (s_HorseScene[playerid][E_HS_TICK] % 2 == 0)
	{
		new text[256], title[64];
		Work_FormatChallenge(playerid,text);
		Horses_SceneStageText(playerid,title);
		Work_SetPanelLines(playerid,title,text,"");
		Work_UpdateGlyphs(playerid);
	}

	return 1;
}

stock bool:Horses_AtTrough(playerid)
{
	for (new node = 0;node < YARD_SEED_NODES;node++)
	{
		if (g_YardDefs[node][E_YARD_DEF_KIND] == YARD_KIND_TROUGH && Yard_GetLevel(node) > 0 && IsPlayerInRangeOfPoint(playerid,4.5,g_YardDefs[node][E_YARD_DEF_POS][0],g_YardDefs[node][E_YARD_DEF_POS][1],g_YardDefs[node][E_YARD_DEF_POS][2] + 1.0))
		{
			return true;
		}
	}

	return false;
}

stock bool:Horses_TryFeed(playerid,horseid)
{
	if (!Horses_InReach(playerid,horseid))
	{
		Gui_Notify(playerid,"Stand beside your horse to feed it.");
		return false;
	}

	new item = 0;

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_OATS_FEED),ITEM_OATS_FEED) > 0)
	{
		item = ITEM_OATS_FEED;
	}
	else if (Inventory_Count(playerid,Item_GetDefKind(ITEM_OATS),ITEM_OATS) > 0)
	{
		item = ITEM_OATS;
	}
	else if (Inventory_Count(playerid,Item_GetDefKind(ITEM_HAY),ITEM_HAY) > 0)
	{
		item = ITEM_HAY;
	}

	if (item == 0)
	{
		Gui_Notify(playerid,"You have no oats or hay. Farmers and the market sell them.");
		return false;
	}

	if (Horses_GetHunger(horseid) >= 95.0)
	{
		Gui_Notify(playerid,"It's full and turns its head away.");
		return false;
	}

	return Horses_StartScene(playerid,horseid,HORSES_SCENE_FEED,item);
}

stock bool:Horses_TryWater(playerid,horseid)
{
	if (!Horses_InReach(playerid,horseid,6.0))
	{
		Gui_Notify(playerid,"Bring your horse close to water it.");
		return false;
	}

	new item = 0;

	if (!Horses_AtTrough(playerid) && !Yard_IsAtRiver(playerid))
	{
		if (Inventory_Count(playerid,Item_GetDefKind(ITEM_WATER_CLEAN),ITEM_WATER_CLEAN) > 0)
		{
			item = ITEM_WATER_CLEAN;
		}
		else if (Inventory_Count(playerid,Item_GetDefKind(ITEM_WATER_UNCLEAN),ITEM_WATER_UNCLEAN) > 0)
		{
			item = ITEM_WATER_UNCLEAN;
		}
		else
		{
			Gui_Notify(playerid,"Water it at a trough or a stream, or carry a bucket of water.");
			return false;
		}
	}

	if (Horses_GetThirst(horseid) >= 95.0)
	{
		Gui_Notify(playerid,"It isn't thirsty.");
		return false;
	}

	return Horses_StartScene(playerid,horseid,HORSES_SCENE_WATER,item);
}

stock bool:Horses_TryGroom(playerid,horseid)
{
	if (!Horses_InReach(playerid,horseid))
	{
		Gui_Notify(playerid,"Stand beside your horse to groom it.");
		return false;
	}

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_STRAW),ITEM_STRAW) <= 0)
	{
		Gui_Notify(playerid,"You need a wisp of straw to rub it down.");
		return false;
	}

	return Horses_StartScene(playerid,horseid,HORSES_SCENE_GROOM);
}

stock bool:Horses_TryShoe(playerid,horseid)
{
	if (!Horses_InReach(playerid,horseid))
	{
		Gui_Notify(playerid,"Stand beside the horse to shoe it.");
		return false;
	}

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_HORSESHOES),ITEM_HORSESHOES) <= 0)
	{
		Gui_Notify(playerid,"You need a set of horseshoes from a smith.");
		return false;
	}

	return Horses_StartScene(playerid,horseid,HORSES_SCENE_SHOE);
}

stock bool:Horses_TryTame(playerid,horseid)
{
	if (!Horses_IsWild(horseid) || !Horses_InReach(playerid,horseid))
	{
		return false;
	}

	new meadow, spot, tick = GetTickCount();
	Horses_GetWildSpot(horseid,meadow,spot);

	if (tick - s_WildCooldown[horseid] < HORSES_TAME_COOLDOWN_MS && s_WildCooldown[horseid] != 0)
	{
		Gui_Notify(playerid,"It's still wary from the last try. Leave it be a while.");
		return false;
	}

	if (tick - s_HorseTameTick[playerid] < HORSES_TAME_PLAYER_MS && s_HorseTameTick[playerid] != 0)
	{
		Gui_Notify(playerid,"Catch your breath before you try another horse.");
		return false;
	}

	if (meadow >= 0 && gettime() < s_MeadowSpookedUntil[meadow])
	{
		Gui_Notify(playerid,"The herd is spooked. Come back calmer in a while, and don't run near them.");
		return false;
	}

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_HALTER),ITEM_HALTER) <= 0)
	{
		Gui_Notify(playerid,"You need a halter and rope to tame it. The market traders sell them.");
		return false;
	}

	s_HorseTameTick[playerid] = tick;
	return Horses_StartScene(playerid,horseid,HORSES_SCENE_TAME);
}

forward Task:Horses_TameDone(playerid,horseid,total);
#pragma warning push
#pragma warning disable 204
async Task:Horses_TameDone(playerid,horseid,total)
{
	new characterid = Character_GetId(playerid), owned = await Horses_CountOwned(characterid);

	if (!IsPlayerConnected(playerid) || !Horses_IsWild(horseid))
	{
		return async 0;
	}

	if (owned >= HORSES_PER_CHARACTER)
	{
		Gui_Notify(playerid,"You keep two horses already. You let this one go.");
		Horses_WildBolts(horseid);
		return async 0;
	}

	if (!Inventory_Take(playerid,Item_GetDefKind(ITEM_HALTER),ITEM_HALTER,1))
	{
		Gui_Notify(playerid,"Your halter is gone. It slips away.");
		Horses_WildBolts(horseid);
		return async 0;
	}

	new meadow, spot;
	Horses_GetWildSpot(horseid,meadow,spot);
	Horses_SetWildSpot(horseid,-1,-1);

	if (meadow >= 0 && spot >= 0)
	{
		s_MeadowHorse[meadow][spot] = INVALID_HORSE_ID;
		s_MeadowRespawnAt[meadow][spot] = GetTickCount() + HORSES_WILD_RESPAWN_MS;
	}

	Horses_SetName(horseid,"");
	Horse_SetHold(horseid,"");
	new hid = await Horses_Adopt(horseid,characterid,HORSES_EVENT_TAMED);

	if (hid <= 0 || !IsPlayerConnected(playerid))
	{
		return async 0;
	}

	Horses_SetBond(horseid,HORSES_BOND_TAMED + (total >= 11 ? 5 : 0));
	pawn_call_public("Horse_OnTamed","dd",playerid,horseid);
	Gui_Notify(playerid,"It stands quiet under you. The horse is yours. Give it a name.");
	Horses_AskName(playerid,horseid);
	return async hid;
}
#pragma warning pop

stock Horses_WildBolts(horseid)
{
	if (!Horses_IsWild(horseid))
	{
		return;
	}

	new meadow, spot, Float:x, Float:y, Float:z, Float:a;
	Horses_GetWildSpot(horseid,meadow,spot);
	Horse_GetPos(horseid,x,y,z,a);
	s_WildCooldown[horseid] = GetTickCount();
	Horse_WalkTo(horseid,x + floatsin(-(a + 180.0),degrees) * 20.0,y + floatcos(-(a + 180.0),degrees) * 20.0,z,HORSES_BOLT_SPEED);

	if (meadow >= 0 && spot >= 0)
	{
		s_MeadowHorse[meadow][spot] = INVALID_HORSE_ID;
		s_MeadowRespawnAt[meadow][spot] = GetTickCount() + HORSES_TAME_COOLDOWN_MS;
	}

	SetTimerEx("Horses_WildGone",8000,false,"d",horseid);
}

stock Horses_SpawnWild(meadow,spot)
{
	if (meadow < 0 || meadow >= HORSE_SEED_MEADOWS || spot < 0 || spot >= g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_COUNT])
	{
		return INVALID_HORSE_ID;
	}

	new base = spot * 4;
	new horseid = Horses_Spawn(HORSES_BREED_WILD,g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_SPOTS][base],g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_SPOTS][base + 1],g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_SPOTS][base + 2],g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_SPOTS][base + 3],0,HORSES_KIND_WILD,random(1000000) + 1);

	if (horseid != INVALID_HORSE_ID)
	{
		Horses_SetWildSpot(horseid,meadow,spot);
		Horses_SetName(horseid,"Wild horse");
		s_WildCooldown[horseid] = 0;
	}

	s_MeadowHorse[meadow][spot] = horseid;
	s_MeadowRespawnAt[meadow][spot] = 0;
	return horseid;
}

stock Horses_SpawnAllWild()
{
	new count = 0;

	for (new meadow = 0;meadow < HORSE_SEED_MEADOWS;meadow++)
	{
		for (new spot = 0;spot < g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_COUNT];spot++)
		{
			if (Horses_SpawnWild(meadow,spot) != INVALID_HORSE_ID)
			{
				count++;
			}
		}
	}

	return count;
}

stock Horses_CountWild()
{
	new count = 0;

	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (Horses_IsWild(horseid))
		{
			count++;
		}
	}

	return count;
}

stock bool:Horses_IsMeadowSpooked(meadow)
{
	return meadow >= 0 && meadow < HORSE_SEED_MEADOWS && gettime() < s_MeadowSpookedUntil[meadow];
}

stock Horses_SpookMeadow(meadow)
{
	if (meadow >= 0 && meadow < HORSE_SEED_MEADOWS)
	{
		s_MeadowSpookedUntil[meadow] = gettime() + HORSES_SPOOK_SECONDS;
	}
}

static Horses_ClearCarePrompt(playerid)
{
	if (s_HorseCareInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_HorseCareInfobox[playerid]);
	}

	s_HorseCarePrompt[playerid] = INVALID_HORSE_ID;
	s_HorseCareInfobox[playerid] = 0;
}

stock Horses_GetCarePrompt(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_HorseCarePrompt[playerid] : INVALID_HORSE_ID;
}

static Horses_UpdateCarePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Mount_IsRiding(playerid) || Horses_IsInScene(playerid) || GetPlayerVirtualWorld(playerid) != 0)
	{
		Horses_ClearCarePrompt(playerid);
		return;
	}

	new best = INVALID_HORSE_ID, Float:bestDistance = HORSES_CARE_RANGE, Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid,px,py,pz);

	for (new horseid = 0;horseid < MAX_HORSES;horseid++)
	{
		if (!Horse_IsValid(horseid) || Horse_GetRider(horseid) != INVALID_PLAYER_ID || Horse_IsWalking(horseid) || (!Horses_IsWild(horseid) && !Horses_MayRide(playerid,horseid)))
		{
			continue;
		}

		new Float:x, Float:y, Float:z, Float:a;
		Horse_GetPos(horseid,x,y,z,a);
		new Float:distance = VectorSize(px - x,py - y,pz - z - 1.0);

		if (distance < bestDistance)
		{
			best = horseid;
			bestDistance = distance;
		}
	}

	if (best == INVALID_HORSE_ID)
	{
		Horses_ClearCarePrompt(playerid);
		return;
	}

	if (best == s_HorseCarePrompt[playerid] && Infobox_IsShown(playerid,s_HorseCareInfobox[playerid]))
	{
		return;
	}

	new name[HORSES_NAME_LEN];
	Horses_GetHorseName(best,name);
	s_HorseCarePrompt[playerid] = best;
	new text[64];

	if (Horses_IsWild(best))
	{
		strcopy(text,"Press ~y~Y~w~ to halter it (you need a halter).");
	}
	else
	{
		strcopy(text,"Press ~y~Y~w~ to look after it.");
	}

	s_HorseCareInfobox[playerid] = Infobox_ShowPrompt(playerid,s_HorseCareInfobox[playerid],name,text,3);
}

Timer_Declare(Horses_CareTick)
{
	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		Horses_UpdateCarePrompt(playerid);

		new Float:vx, Float:vy, Float:vz;
		GetPlayerVelocity(playerid,vx,vy,vz);
		new bool:fast = VectorSize(vx,vy,0.0) > 0.18 || Mount_IsGalloping(playerid);

		if (!fast)
		{
			continue;
		}

		for (new meadow = 0;meadow < HORSE_SEED_MEADOWS;meadow++)
		{
			if (IsPlayerInRangeOfPoint(playerid,HORSES_SPOOK_RANGE,g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_SPOTS][0],g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_SPOTS][1],g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_SPOTS][2]))
			{
				Horses_SpookMeadow(meadow);
			}
		}
	}

	new now = GetTickCount();

	for (new meadow = 0;meadow < HORSE_SEED_MEADOWS;meadow++)
	{
		for (new spot = 0;spot < g_HorseMeadowDefs[meadow][E_HORSE_MEADOW_DEF_COUNT];spot++)
		{
			if (s_MeadowHorse[meadow][spot] == INVALID_HORSE_ID && s_MeadowRespawnAt[meadow][spot] != 0 && now >= s_MeadowRespawnAt[meadow][spot])
			{
				Horses_SpawnWild(meadow,spot);
			}
		}
	}

	return 1;
}

forward Horses_WildGone(horseid);

public Horses_WildGone(horseid)
{
	if (Horses_IsWild(horseid))
	{
		Horse_Destroy(horseid);
	}

	return 1;
}

forward bool:Horses_CarePromptContext(playerid);

public bool:Horses_CarePromptContext(playerid)
{
	return s_HorseCarePrompt[playerid] != INVALID_HORSE_ID;
}

forward Horses_CareDeferred(playerid,horseid);

public Horses_CareDeferred(playerid,horseid)
{
	if (!IsPlayerConnected(playerid) || !Horse_IsValid(horseid))
	{
		return 1;
	}

	if (Horses_IsWild(horseid))
	{
		Horses_TryTame(playerid,horseid);
		return 1;
	}

	Horses_OpenPanel(playerid,horseid);
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_HorseScene[playerid][E_HS_KIND] = HORSES_SCENE_NONE;
	s_HorseScene[playerid][E_HS_TIMER] = 0;
	s_HorseTameTick[playerid] = 0;
	s_HorseCarePrompt[playerid] = INVALID_HORSE_ID;
	s_HorseCareInfobox[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (Horses_IsInScene(playerid))
	{
		Horses_AbortScene(playerid);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_HorseCarePrompt[playerid] == INVALID_HORSE_ID || Infobox_IsPromptBlocked(playerid,s_HorseCareInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new horseid = s_HorseCarePrompt[playerid];
	Horses_ClearCarePrompt(playerid);
	SetTimerEx("Horses_CareDeferred",0,false,"dd",playerid,horseid);
}

hook Horse_OnDestroyed(horseid)
{
	for (new meadow = 0;meadow < HORSE_SEED_MEADOWS;meadow++)
	{
		for (new spot = 0;spot < HORSE_MEADOW_SPOTS;spot++)
		{
			if (s_MeadowHorse[meadow][spot] == horseid)
			{
				s_MeadowHorse[meadow][spot] = INVALID_HORSE_ID;

				if (s_MeadowRespawnAt[meadow][spot] == 0)
				{
					s_MeadowRespawnAt[meadow][spot] = GetTickCount() + HORSES_TAME_COOLDOWN_MS;
				}
			}
		}
	}

	foreach (new playerid : Player)
	{
		if (s_HorseScene[playerid][E_HS_KIND] != HORSES_SCENE_NONE && s_HorseScene[playerid][E_HS_HORSE] == horseid)
		{
			Horses_EndScene(playerid);
		}
	}
}
