#define MODEL_UI_DISCS (-29996)
#define HUD_DISC_X (1.0)
#define HUD_DISC_Y (340.0)
#define HUD_DISC_GAP (30.0)
#define HUD_DISC_OUTLINE (30.0)
#define HUD_DISC_SIZE (26.0)
#define HUD_DISC_SPRITE_LEN (40)

enum E_HUD_DISC
{
	HUD_DISC_MOON,
	HUD_DISC_HOUR,
	HUD_DISC_SEASON,
	HUD_DISC_COUNT,
}

static Text:s_HudDiscOutline[HUD_DISC_COUNT] = {Text:INVALID_TEXT_DRAW, ...};
static Text:s_HudDiscSprite[HUD_DISC_COUNT] = {Text:INVALID_TEXT_DRAW, ...};
static s_HudDiscName[HUD_DISC_COUNT][HUD_DISC_SPRITE_LEN];
static bool:s_HudDiscShown[MAX_PLAYERS];
static bool:s_HudDiscsCreated = false;

static Hud_CreateDiscs()
{
	for (new E_HUD_DISC:disc = HUD_DISC_MOON;disc < HUD_DISC_COUNT;disc++)
	{
		new Float:y = HUD_DISC_Y + float(_:disc) * HUD_DISC_GAP;

		s_HudDiscOutline[disc] = TextDrawCreate(HUD_DISC_X,y,"LD_BEAT:chit");
		TextDrawFont(s_HudDiscOutline[disc],TEXT_DRAW_FONT_SPRITE_DRAW);
		TextDrawTextSize(s_HudDiscOutline[disc],HUD_DISC_OUTLINE,HUD_DISC_OUTLINE);
		TextDrawColour(s_HudDiscOutline[disc],255);
		TextDrawSetShadow(s_HudDiscOutline[disc],0);
		TextDrawSetOutline(s_HudDiscOutline[disc],0);

		s_HudDiscSprite[disc] = TextDrawCreate(HUD_DISC_X + (HUD_DISC_OUTLINE - HUD_DISC_SIZE) / 2.0,y + (HUD_DISC_OUTLINE - HUD_DISC_SIZE) / 2.0,"_");
		TextDrawFont(s_HudDiscSprite[disc],TEXT_DRAW_FONT_SPRITE_DRAW);
		TextDrawTextSize(s_HudDiscSprite[disc],HUD_DISC_SIZE,HUD_DISC_SIZE);
		TextDrawColour(s_HudDiscSprite[disc],-1);
		TextDrawSetShadow(s_HudDiscSprite[disc],0);
		TextDrawSetOutline(s_HudDiscSprite[disc],0);
	}

	s_HudDiscsCreated = true;
}

static Hud_ShowDisc(playerid,E_HUD_DISC:disc)
{
	if (s_HudDiscName[disc][0] == EOS)
	{
		TextDrawHideForPlayer(playerid,s_HudDiscOutline[disc]);
		TextDrawHideForPlayer(playerid,s_HudDiscSprite[disc]);
		return;
	}

	TextDrawShowForPlayer(playerid,s_HudDiscOutline[disc]);
	TextDrawShowForPlayer(playerid,s_HudDiscSprite[disc]);
}

stock Hud_ShowDiscs(playerid)
{
	if (!s_HudDiscsCreated)
	{
		return;
	}

	s_HudDiscShown[playerid] = true;

	for (new E_HUD_DISC:disc = HUD_DISC_MOON;disc < HUD_DISC_COUNT;disc++)
	{
		Hud_ShowDisc(playerid,disc);
	}
}

stock Hud_HideDiscs(playerid)
{
	if (!s_HudDiscsCreated)
	{
		return;
	}

	s_HudDiscShown[playerid] = false;

	for (new E_HUD_DISC:disc = HUD_DISC_MOON;disc < HUD_DISC_COUNT;disc++)
	{
		TextDrawHideForPlayer(playerid,s_HudDiscOutline[disc]);
		TextDrawHideForPlayer(playerid,s_HudDiscSprite[disc]);
	}
}

stock bool:Hud_AreDiscsShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_HudDiscShown[playerid];
}

stock Hud_SetDisc(E_HUD_DISC:disc,const sprite[])
{
	if (!strcmp(s_HudDiscName[disc],sprite) && (s_HudDiscName[disc][0] != EOS) == (sprite[0] != EOS))
	{
		return;
	}

	strcopy(s_HudDiscName[disc],sprite);

	if (!s_HudDiscsCreated)
	{
		return;
	}

	if (sprite[0] != EOS)
	{
		TextDrawSetString(s_HudDiscSprite[disc],sprintf("mdl%d:%s",MODEL_UI_DISCS,sprite));
	}

	foreach (new playerid : Player)
	{
		if (s_HudDiscShown[playerid])
		{
			Hud_ShowDisc(playerid,disc);
		}
	}
}

stock Hud_GetDisc(E_HUD_DISC:disc,dest[],size = sizeof(dest))
{
	strcopy(dest,s_HudDiscName[disc],size);
}

#include <pp-hooks>

hook Models_OnRegister()
{
	Models_AddObject(MODEL_UI_DISCS,"ui/sprite_model.dff","ui/ui_discs.txd");
}

hook OnGameModeInit()
{
	Hud_CreateDiscs();

	for (new E_HUD_DISC:disc = HUD_DISC_MOON;disc < HUD_DISC_COUNT;disc++)
	{
		if (s_HudDiscName[disc][0] != EOS)
		{
			TextDrawSetString(s_HudDiscSprite[disc],sprintf("mdl%d:%s",MODEL_UI_DISCS,s_HudDiscName[disc]));
		}
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	s_HudDiscShown[playerid] = false;
}
