#define HUD_HORSE_X (36.0)
#define HUD_HORSE_Y (292.0)
#define HUD_HORSE_WIDTH (96.0)
#define HUD_HORSE_HEIGHT (46.0)
#define HUD_HORSE_BAR_X (78.0)
#define HUD_HORSE_BAR_WIDTH (46.0)
#define HUD_HORSE_ROW (7.5)
#define HUD_HORSE_TEXT_LEN (64)
#define HUD_HORSE_LABEL_COLOUR (0xD8CCB2FF)

enum E_HUD_HORSE_BAR
{
	HUD_HORSE_STAMINA,
	HUD_HORSE_HUNGER,
	HUD_HORSE_CONDITION,
	HUD_HORSE_BAR_COUNT,
}

enum E_HUD_HORSE_TEXT
{
	HUD_HORSE_NAME,
	HUD_HORSE_STATUS,
	HUD_HORSE_TEXT_COUNT,
}

static bool:s_HudHorseShown[MAX_PLAYERS];
static PlayerText:s_HudHorseBack[MAX_PLAYERS];
static PlayerText:s_HudHorseLabels[MAX_PLAYERS][_:HUD_HORSE_BAR_COUNT];
static PlayerText:s_HudHorseName[MAX_PLAYERS];
static PlayerText:s_HudHorseStatus[MAX_PLAYERS];
static s_HudHorseBars[MAX_PLAYERS][HUD_HORSE_BAR_COUNT];
static Float:s_HudHorseValues[MAX_PLAYERS][HUD_HORSE_BAR_COUNT];
static s_HudHorseColours[MAX_PLAYERS][HUD_HORSE_BAR_COUNT];
static s_HudHorseStrings[MAX_PLAYERS][HUD_HORSE_TEXT_COUNT][HUD_HORSE_TEXT_LEN];
static const s_HudHorseLabelText[HUD_HORSE_BAR_COUNT][12] = {"Stamina", "Hunger", "Condition"};
static const s_HudHorseDefaultColours[HUD_HORSE_BAR_COUNT] = {0xADA672FF, 0x807266FF, 0x6E8F62FF};

static PlayerText:Hud_HorseText(playerid,Float:x,Float:y,const text[],Float:size = 0.16)
{
	new PlayerText:td = CreatePlayerTextDraw(playerid,x,y,text);
	PlayerTextDrawFont(playerid,td,TEXT_DRAW_FONT_1);
	PlayerTextDrawLetterSize(playerid,td,size,size * 4.4);
	PlayerTextDrawColour(playerid,td,HUD_HORSE_LABEL_COLOUR);
	PlayerTextDrawSetShadow(playerid,td,0);
	PlayerTextDrawSetOutline(playerid,td,1);
	PlayerTextDrawBackgroundColour(playerid,td,255);
	PlayerTextDrawSetProportional(playerid,td,true);
	return td;
}

stock bool:Hud_IsHorseShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_HudHorseShown[playerid];
}

stock Hud_ShowHorse(playerid)
{
	if (!Util_IsValidPlayer(playerid) || s_HudHorseShown[playerid])
	{
		return;
	}

	s_HudHorseBack[playerid] = CreatePlayerTextDraw(playerid,HUD_HORSE_X - 4.0,HUD_HORSE_Y - 4.0,"mdl-29997:ui_box");
	PlayerTextDrawFont(playerid,s_HudHorseBack[playerid],TEXT_DRAW_FONT_SPRITE_DRAW);
	PlayerTextDrawTextSize(playerid,s_HudHorseBack[playerid],HUD_HORSE_WIDTH,HUD_HORSE_HEIGHT);
	PlayerTextDrawColour(playerid,s_HudHorseBack[playerid],0xFFFFFF7D);
	PlayerTextDrawShow(playerid,s_HudHorseBack[playerid]);
	s_HudHorseName[playerid] = Hud_HorseText(playerid,HUD_HORSE_X,HUD_HORSE_Y,"_",0.18);
	s_HudHorseStatus[playerid] = Hud_HorseText(playerid,HUD_HORSE_X,HUD_HORSE_Y + 9.0 + HUD_HORSE_ROW * 3.0,"_");
	PlayerTextDrawShow(playerid,s_HudHorseName[playerid]);
	PlayerTextDrawShow(playerid,s_HudHorseStatus[playerid]);

	for (new E_HUD_HORSE_TEXT:t = HUD_HORSE_NAME;t < HUD_HORSE_TEXT_COUNT;t++)
	{
		s_HudHorseStrings[playerid][t][0] = EOS;
	}

	for (new E_HUD_HORSE_BAR:bar = HUD_HORSE_STAMINA;bar < HUD_HORSE_BAR_COUNT;bar++)
	{
		new Float:y = HUD_HORSE_Y + 9.0 + HUD_HORSE_ROW * float(_:bar);
		s_HudHorseLabels[playerid][_:bar] = Hud_HorseText(playerid,HUD_HORSE_X,y - 1.5,s_HudHorseLabelText[bar]);
		s_HudHorseBars[playerid][bar] = PBar_Create(playerid,HUD_HORSE_BAR_X,y + 1.0,HUD_HORSE_BAR_WIDTH,3.0,s_HudHorseDefaultColours[bar]);
		s_HudHorseValues[playerid][bar] = -1.0;
		s_HudHorseColours[playerid][bar] = 0;
		PlayerTextDrawShow(playerid,s_HudHorseLabels[playerid][_:bar]);
		PBar_Show(playerid,s_HudHorseBars[playerid][bar]);
	}

	s_HudHorseShown[playerid] = true;
}

stock Hud_HideHorse(playerid)
{
	if (!Util_IsValidPlayer(playerid) || !s_HudHorseShown[playerid])
	{
		return;
	}

	PlayerTextDrawDestroy(playerid,s_HudHorseBack[playerid]);

	PlayerTextDrawDestroy(playerid,s_HudHorseName[playerid]);
	PlayerTextDrawDestroy(playerid,s_HudHorseStatus[playerid]);

	for (new E_HUD_HORSE_BAR:bar = HUD_HORSE_STAMINA;bar < HUD_HORSE_BAR_COUNT;bar++)
	{
		PlayerTextDrawDestroy(playerid,s_HudHorseLabels[playerid][_:bar]);
		PBar_Destroy(playerid,s_HudHorseBars[playerid][bar]);
	}

	s_HudHorseShown[playerid] = false;
}

stock Hud_SetHorseBar(playerid,E_HUD_HORSE_BAR:bar,Float:pct,colour = 0)
{
	if (!Hud_IsHorseShown(playerid) || bar >= HUD_HORSE_BAR_COUNT)
	{
		return;
	}

	if (colour == 0)
	{
		colour = s_HudHorseDefaultColours[bar];
	}

	if (floatabs(pct - s_HudHorseValues[playerid][bar]) < 0.5 && colour == s_HudHorseColours[playerid][bar])
	{
		return;
	}

	s_HudHorseValues[playerid][bar] = pct;
	s_HudHorseColours[playerid][bar] = colour;
	PBar_SetValue(playerid,s_HudHorseBars[playerid][bar],pct,colour);
}

stock Hud_SetHorseText(playerid,E_HUD_HORSE_TEXT:slot,const text[])
{
	if (!Hud_IsHorseShown(playerid) || slot >= HUD_HORSE_TEXT_COUNT || !strcmp(text,s_HudHorseStrings[playerid][slot]) && s_HudHorseStrings[playerid][slot][0] != EOS)
	{
		return;
	}

	strcopy(s_HudHorseStrings[playerid][slot],text,HUD_HORSE_TEXT_LEN);

	new PlayerText:td = slot == HUD_HORSE_NAME ? s_HudHorseName[playerid] : s_HudHorseStatus[playerid];

	if (text[0] == EOS)
	{
		PlayerTextDrawSetString(playerid,td,"_");
	}
	else
	{
		PlayerTextDrawSetString(playerid,td,text);
	}
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_HudHorseShown[playerid] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason
	Hud_HideHorse(playerid);
}
