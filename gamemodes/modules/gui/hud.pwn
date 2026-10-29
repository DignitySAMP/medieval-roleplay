#define HUD_COLOUR_HEALTH (0x8F6B6BFF)
#define HUD_COLOUR_STAMINA (0xADA672FF)
#define HUD_COLOUR_HUNGER (0x807266FF)
#define HUD_COLOUR_THIRST (0x678591FF)
#define HUD_COLOUR_COLD (0x6D8FB3FF)
#define HUD_COLOUR_MILD (0xC9A66BFF)
#define HUD_COLOUR_WARM (0xB5543CFF)
#define HUD_COLOUR_LABEL (0xD8CCB2FF)
#define HUD_BAR_X (566.0)
#define HUD_BAR_Y (395.0)
#define HUD_BAR_WIDTH (60.0)
#define HUD_BAR_HEIGHT (3.0)
#define HUD_BAR_GAP (9.0)
#define HUD_LABEL_X (562.0)
#define HUD_BACKGROUND_SPRITE "mdl-29997:ui_box"
#define HUD_BACKGROUND_TINT (0xFFFFFF7D)
#define HUD_BACKGROUND_X (518.0)
#define HUD_BACKGROUND_Y (372.0)
#define HUD_BACKGROUND_WIDTH (162.0)
#define HUD_BACKGROUND_HEIGHT (76.0)
#define HUD_TITLE_X (563.0)
#define HUD_TITLE_Y (100.5)
#define HUD_BUFF_X (116.0)
#define HUD_BUFF_Y (398.0)
#define HUD_BUFF_WIDTH (60.0)
#define HUD_BUFF_COLOUR (0xC9A66BFF)
#define HUD_BUFF_SLOTS (3)
#define HUD_BUFF_STEP (17.0)
#define HUD_BUFF_LABEL_LEN (48)
#define HUD_ATTENTION_MS (1100)
#define HUD_ATTENTION_UP (4.0)
#define HUD_ATTENTION_DROP_MS (800)
#define HUD_ATTENTION_MAX (24)
#define HUD_WARMTH_COLD_PCT (35.0)
#define HUD_WARMTH_HOT_PCT (65.0)

enum E_HUD_BAR
{
	HUD_BAR_HEALTH,
	HUD_BAR_STAMINA,
	HUD_BAR_HUNGER,
	HUD_BAR_THIRST,
	HUD_BAR_WARMTH,
	HUD_BAR_COUNT,
}

static const s_HudBarColours[E_HUD_BAR] = {HUD_COLOUR_HEALTH, HUD_COLOUR_STAMINA, HUD_COLOUR_HUNGER, HUD_COLOUR_THIRST, HUD_COLOUR_MILD, 0};
static const s_HudBarLabels[E_HUD_BAR][8] = {"Health", "Stamina", "Hunger", "Thirst", "Warmth", ""};

static Text:s_HudTitle = Text:INVALID_TEXT_DRAW;
static PlayerText:s_HudLabels[MAX_PLAYERS][E_HUD_BAR];
static PlayerText:s_HudBackground[MAX_PLAYERS] = {INVALID_PLAYER_TEXT_DRAW, ...};
static s_HudBar[MAX_PLAYERS][E_HUD_BAR];
static bool:s_HudShown[MAX_PLAYERS];
static PlayerText:s_HudBuffLabel[MAX_PLAYERS][HUD_BUFF_SLOTS];
static s_HudBuffBar[MAX_PLAYERS][HUD_BUFF_SLOTS];
static Float:s_HudBuffValue[MAX_PLAYERS][HUD_BUFF_SLOTS];
static s_HudBuffText[MAX_PLAYERS][HUD_BUFF_SLOTS][HUD_BUFF_LABEL_LEN];
static s_HudAttentionTimer[MAX_PLAYERS] = {-1, ...};
static PlayerText:s_HudAttentionTds[MAX_PLAYERS][HUD_ATTENTION_MAX];
static Float:s_HudAttentionRest[MAX_PLAYERS][HUD_ATTENTION_MAX][2];
static s_HudAttentionCount[MAX_PLAYERS];
static bool:s_HudSuspended[MAX_PLAYERS];
static Float:s_HudValue[MAX_PLAYERS][E_HUD_BAR];
static s_HudValueColour[MAX_PLAYERS][E_HUD_BAR];

static PlayerText:Hud_CreateLabel(playerid,Float:x,Float:y,const text[],TEXT_DRAW_ALIGN:alignment)
{
	new PlayerText:td = CreatePlayerTextDraw(playerid,x,y,text);
	PlayerTextDrawFont(playerid,td,TEXT_DRAW_FONT_1);
	PlayerTextDrawLetterSize(playerid,td,0.16,0.7);
	PlayerTextDrawAlignment(playerid,td,alignment);
	PlayerTextDrawColour(playerid,td,HUD_COLOUR_LABEL);
	PlayerTextDrawSetShadow(playerid,td,0);
	PlayerTextDrawSetOutline(playerid,td,1);
	PlayerTextDrawBackgroundColour(playerid,td,255);
	PlayerTextDrawSetProportional(playerid,td,true);
	return td;
}

static Hud_CreateShared()
{
	s_HudTitle = TextDrawCreate(HUD_TITLE_X,HUD_TITLE_Y,"_");
	TextDrawFont(s_HudTitle,TEXT_DRAW_FONT_1);
	TextDrawLetterSize(s_HudTitle,0.18,0.8);
	TextDrawAlignment(s_HudTitle,TEXT_DRAW_ALIGN_CENTRE);
	TextDrawColour(s_HudTitle,HUD_COLOUR_LABEL);
	TextDrawSetShadow(s_HudTitle,0);
	TextDrawSetOutline(s_HudTitle,1);
	TextDrawBackgroundColour(s_HudTitle,255);
	TextDrawSetProportional(s_HudTitle,true);
}

static Hud_Create(playerid)
{
	s_HudBackground[playerid] = CreatePlayerTextDraw(playerid,HUD_BACKGROUND_X,HUD_BACKGROUND_Y,HUD_BACKGROUND_SPRITE);
	PlayerTextDrawFont(playerid,s_HudBackground[playerid],TEXT_DRAW_FONT_SPRITE_DRAW);
	PlayerTextDrawTextSize(playerid,s_HudBackground[playerid],HUD_BACKGROUND_WIDTH,HUD_BACKGROUND_HEIGHT);
	PlayerTextDrawColour(playerid,s_HudBackground[playerid],HUD_BACKGROUND_TINT);

	for (new E_HUD_BAR:bar = HUD_BAR_HEALTH;bar < HUD_BAR_COUNT;bar++)
	{
		new Float:y = HUD_BAR_Y + float(_:bar) * HUD_BAR_GAP;
		s_HudBar[playerid][bar] = PBar_Create(playerid,HUD_BAR_X,y,HUD_BAR_WIDTH,HUD_BAR_HEIGHT,s_HudBarColours[bar]);
		s_HudValue[playerid][bar] = 100.0;
		s_HudValueColour[playerid][bar] = s_HudBarColours[bar];
		s_HudLabels[playerid][bar] = Hud_CreateLabel(playerid,HUD_LABEL_X,y - 1.5,s_HudBarLabels[bar],TEXT_DRAW_ALIGN_RIGHT);
	}

}

static Hud_Destroy(playerid)
{
	if (s_HudBackground[playerid] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid,s_HudBackground[playerid]);
		s_HudBackground[playerid] = INVALID_PLAYER_TEXT_DRAW;
	}

	for (new E_HUD_BAR:bar = HUD_BAR_HEALTH;bar < HUD_BAR_COUNT;bar++)
	{
		PBar_Destroy(playerid,s_HudBar[playerid][bar]);
		s_HudBar[playerid][bar] = INVALID_PLAYER_BAR;

		if (s_HudLabels[playerid][bar] != INVALID_PLAYER_TEXT_DRAW)
		{
			PlayerTextDrawDestroy(playerid,s_HudLabels[playerid][bar]);
			s_HudLabels[playerid][bar] = INVALID_PLAYER_TEXT_DRAW;
		}
	}

	Hud_DestroyBuff(playerid);
	s_HudShown[playerid] = false;
}

stock Hud_Show(playerid)
{
	if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid))
	{
		return;
	}

	if (s_HudBar[playerid][HUD_BAR_HEALTH] == INVALID_PLAYER_BAR)
	{
		Hud_Create(playerid);
	}

	s_HudShown[playerid] = true;

	if (s_HudSuspended[playerid])
	{
		return;
	}

	TextDrawShowForPlayer(playerid,s_HudTitle);
	PlayerTextDrawShow(playerid,s_HudBackground[playerid]);
	Hud_ShowDiscs(playerid);

	for (new E_HUD_BAR:bar = HUD_BAR_HEALTH;bar < HUD_BAR_COUNT;bar++)
	{
		PBar_Show(playerid,s_HudBar[playerid][bar]);
		PlayerTextDrawShow(playerid,s_HudLabels[playerid][bar]);
	}

	Hud_ShowBuff(playerid);
}

stock Hud_SetSuspended(playerid,bool:isSuspended)
{
	if (!Util_IsValidPlayer(playerid) || s_HudSuspended[playerid] == isSuspended)
	{
		return;
	}

	s_HudSuspended[playerid] = isSuspended;

	if (!s_HudShown[playerid])
	{
		return;
	}

	if (isSuspended)
	{
		if (s_HudAttentionTimer[playerid] != -1)
		{
			Hud_AttentionRest(playerid);
		}

		TextDrawHideForPlayer(playerid,s_HudTitle);
		PlayerTextDrawHide(playerid,s_HudBackground[playerid]);
		Hud_HideDiscs(playerid);
		Hud_HideHorse(playerid);

		for (new slot = 0;slot < HUD_BUFF_SLOTS;slot++)
		{
			if (s_HudBuffLabel[playerid][slot] != INVALID_PLAYER_TEXT_DRAW)
			{
				PlayerTextDrawHide(playerid,s_HudBuffLabel[playerid][slot]);
				PBar_Hide(playerid,s_HudBuffBar[playerid][slot]);
			}
		}

		for (new E_HUD_BAR:bar = HUD_BAR_HEALTH;bar < HUD_BAR_COUNT;bar++)
		{
			PBar_Hide(playerid,s_HudBar[playerid][bar]);
			PlayerTextDrawHide(playerid,s_HudLabels[playerid][bar]);
		}

		return;
	}

	TextDrawShowForPlayer(playerid,s_HudTitle);
	PlayerTextDrawShow(playerid,s_HudBackground[playerid]);
	Hud_ShowDiscs(playerid);

	for (new E_HUD_BAR:bar = HUD_BAR_HEALTH;bar < HUD_BAR_COUNT;bar++)
	{
		PBar_SetValue(playerid,s_HudBar[playerid][bar],s_HudValue[playerid][bar],s_HudValueColour[playerid][bar]);
		PlayerTextDrawShow(playerid,s_HudLabels[playerid][bar]);
	}

	Hud_ShowBuff(playerid);
}

static Hud_DestroyBuffSlot(playerid,slot)
{
	if (s_HudBuffLabel[playerid][slot] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawDestroy(playerid,s_HudBuffLabel[playerid][slot]);
		s_HudBuffLabel[playerid][slot] = INVALID_PLAYER_TEXT_DRAW;
	}

	PBar_Destroy(playerid,s_HudBuffBar[playerid][slot]);
	s_HudBuffBar[playerid][slot] = INVALID_PLAYER_BAR;
}

static Hud_DestroyBuff(playerid)
{
	for (new slot = 0;slot < HUD_BUFF_SLOTS;slot++)
	{
		Hud_DestroyBuffSlot(playerid,slot);
	}
}

static Hud_DrawBuffSlot(playerid,slot)
{
	if (!s_HudShown[playerid] || s_HudSuspended[playerid] || s_HudBuffText[playerid][slot][0] == EOS)
	{
		return;
	}

	new Float:y = HUD_BUFF_Y - float(slot) * HUD_BUFF_STEP;

	if (s_HudBuffLabel[playerid][slot] == INVALID_PLAYER_TEXT_DRAW)
	{
		s_HudBuffLabel[playerid][slot] = Hud_CreateLabel(playerid,HUD_BUFF_X,y,s_HudBuffText[playerid][slot],TEXT_DRAW_ALIGN_LEFT);
		s_HudBuffBar[playerid][slot] = PBar_Create(playerid,HUD_BUFF_X,y + 9.0,HUD_BUFF_WIDTH,HUD_BAR_HEIGHT,HUD_BUFF_COLOUR);
	}
	else
	{
		PlayerTextDrawSetString(playerid,s_HudBuffLabel[playerid][slot],s_HudBuffText[playerid][slot]);
	}

	PlayerTextDrawShow(playerid,s_HudBuffLabel[playerid][slot]);
	PBar_SetValue(playerid,s_HudBuffBar[playerid][slot],s_HudBuffValue[playerid][slot],HUD_BUFF_COLOUR);
}

static Hud_ShowBuff(playerid)
{
	for (new slot = 0;slot < HUD_BUFF_SLOTS;slot++)
	{
		Hud_DrawBuffSlot(playerid,slot);
	}
}

stock Hud_GetBuffText(playerid,slot,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Util_IsValidPlayer(playerid) && slot >= 0 && slot < HUD_BUFF_SLOTS)
	{
		strcopy(dest,s_HudBuffText[playerid][slot],size);
	}
}

stock Hud_SetBuffSlot(playerid,slot,const label[],Float:percent)
{
	if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid) || slot < 0 || slot >= HUD_BUFF_SLOTS)
	{
		return;
	}

	if (label[0] == EOS)
	{
		s_HudBuffText[playerid][slot][0] = EOS;
		Hud_DestroyBuffSlot(playerid,slot);
		return;
	}

	strcopy(s_HudBuffText[playerid][slot],label,HUD_BUFF_LABEL_LEN);
	s_HudBuffValue[playerid][slot] = percent;
	Hud_DrawBuffSlot(playerid,slot);
}

static Hud_AttentionAdd(playerid,PlayerText:td)
{
	if (td == INVALID_PLAYER_TEXT_DRAW || s_HudAttentionCount[playerid] >= HUD_ATTENTION_MAX)
	{
		return;
	}

	new i = s_HudAttentionCount[playerid]++;
	s_HudAttentionTds[playerid][i] = td;
	PlayerTextDrawGetPos(playerid,td,s_HudAttentionRest[playerid][i][0],s_HudAttentionRest[playerid][i][1]);
}

static Hud_AttentionRest(playerid)
{
	Kit_StopExternalAnims(playerid);

	for (new i = 0;i < s_HudAttentionCount[playerid];i++)
	{
		PlayerTextDrawSetPos(playerid,s_HudAttentionTds[playerid][i],s_HudAttentionRest[playerid][i][0],s_HudAttentionRest[playerid][i][1]);

		if (!s_HudSuspended[playerid])
		{
			PlayerTextDrawShow(playerid,s_HudAttentionTds[playerid][i]);
		}
	}
}

forward Hud_AttentionTick(playerid);

public Hud_AttentionTick(playerid)
{
	if (!IsPlayerConnected(playerid) || s_HudSuspended[playerid])
	{
		return 1;
	}

	Hud_AttentionRest(playerid);

	for (new i = 0;i < s_HudAttentionCount[playerid];i++)
	{
		new PlayerText:td = s_HudAttentionTds[playerid][i];
		PlayerTextDrawSetPos(playerid,td,s_HudAttentionRest[playerid][i][0],s_HudAttentionRest[playerid][i][1] - HUD_ATTENTION_UP);
		Kit_TrackExternalAnim(playerid,PlayerText_MoveToY(playerid,td,s_HudAttentionRest[playerid][i][1],HUD_ATTENTION_DROP_MS,EASE_OUT_BOUNCE));
	}

	return 1;
}

stock Hud_SetAttention(playerid,bool:isOn)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	if (s_HudAttentionTimer[playerid] != -1)
	{
		KillTimer(s_HudAttentionTimer[playerid]);
		s_HudAttentionTimer[playerid] = -1;
		Hud_AttentionRest(playerid);
	}

	s_HudAttentionCount[playerid] = 0;

	if (!isOn || !s_HudShown[playerid])
	{
		return;
	}

	for (new E_HUD_BAR:bar = HUD_BAR_HEALTH;bar < HUD_BAR_COUNT;bar++)
	{
		new PlayerText:back, PlayerText:fill;
		Hud_AttentionAdd(playerid,s_HudLabels[playerid][bar]);

		if (PBar_GetTextDraws(playerid,s_HudBar[playerid][bar],back,fill))
		{
			Hud_AttentionAdd(playerid,back);
			Hud_AttentionAdd(playerid,fill);
		}
	}

	for (new slot = 0;slot < HUD_BUFF_SLOTS;slot++)
	{
		new PlayerText:back, PlayerText:fill;

		if (s_HudBuffLabel[playerid][slot] == INVALID_PLAYER_TEXT_DRAW)
		{
			continue;
		}

		Hud_AttentionAdd(playerid,s_HudBuffLabel[playerid][slot]);

		if (PBar_GetTextDraws(playerid,s_HudBuffBar[playerid][slot],back,fill))
		{
			Hud_AttentionAdd(playerid,back);
			Hud_AttentionAdd(playerid,fill);
		}
	}

	Hud_AttentionTick(playerid);
	s_HudAttentionTimer[playerid] = SetTimerEx("Hud_AttentionTick",HUD_ATTENTION_MS,true,"d",playerid);
}

stock bool:Hud_IsSuspended(playerid)
{
	return Util_IsValidPlayer(playerid) && s_HudSuspended[playerid];
}

static Hud_ApplyBar(playerid,E_HUD_BAR:bar,Float:value,colour)
{
	s_HudValue[playerid][bar] = value;
	s_HudValueColour[playerid][bar] = colour;

	if (!s_HudSuspended[playerid])
	{
		PBar_SetValue(playerid,s_HudBar[playerid][bar],value,colour);
	}
}

stock Hud_Hide(playerid)
{
	if (!Util_IsValidPlayer(playerid) || !s_HudShown[playerid])
	{
		return;
	}

	Hud_SetAttention(playerid,false);

	TextDrawHideForPlayer(playerid,s_HudTitle);
	Hud_HideDiscs(playerid);
	Hud_HideHorse(playerid);
	Hud_Destroy(playerid);
}

stock bool:Hud_IsShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_HudShown[playerid];
}

stock Hud_SetBar(playerid,E_HUD_BAR:bar,Float:value)
{
	if (!Util_IsValidPlayer(playerid) || !s_HudShown[playerid] || bar >= HUD_BAR_COUNT)
	{
		return;
	}

	Hud_ApplyBar(playerid,bar,value,s_HudBarColours[bar]);
}

stock Hud_SetWarmth(playerid,Float:percent)
{
	if (!Util_IsValidPlayer(playerid) || !s_HudShown[playerid])
	{
		return;
	}

	new colour = HUD_COLOUR_MILD;

	if (percent < HUD_WARMTH_COLD_PCT)
	{
		colour = HUD_COLOUR_COLD;
	}
	else if (percent > HUD_WARMTH_HOT_PCT)
	{
		colour = HUD_COLOUR_WARM;
	}

	Hud_ApplyBar(playerid,HUD_BAR_WARMTH,percent,colour);
}

stock Hud_SetTitle(const text[])
{
	TextDrawSetString(s_HudTitle,text);
}

#include <pp-hooks>

hook OnGameModeInit()
{
	Hud_CreateShared();
	Hud_SetTitle("The Realm");
}

hook OnPlayerConnect(playerid)
{
	s_HudSuspended[playerid] = false;
	s_HudBackground[playerid] = INVALID_PLAYER_TEXT_DRAW;

	s_HudShown[playerid] = false;
	for (new slot = 0;slot < HUD_BUFF_SLOTS;slot++)
	{
		s_HudBuffLabel[playerid][slot] = INVALID_PLAYER_TEXT_DRAW;
		s_HudBuffBar[playerid][slot] = INVALID_PLAYER_BAR;
		s_HudBuffText[playerid][slot][0] = EOS;
	}
	s_HudAttentionTimer[playerid] = -1;
	s_HudAttentionCount[playerid] = 0;

	for (new E_HUD_BAR:bar = HUD_BAR_HEALTH;bar < HUD_BAR_COUNT;bar++)
	{
		s_HudBar[playerid][bar] = INVALID_PLAYER_BAR;
		s_HudLabels[playerid][bar] = INVALID_PLAYER_TEXT_DRAW;
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Hud_SetAttention(playerid,false);
	Hud_Destroy(playerid);
}
