#define MODEL_SCREEN_FX (-29998)
#define SCREENFX_CANVAS_WIDTH (640.0)
#define SCREENFX_CANVAS_HEIGHT (448.0)
#define SCREENFX_TINT (0xFFFFFF00)

enum E_SCREENFX
{
	SCREENFX_BLOOD,
	SCREENFX_COLD,
	SCREENFX_HEAT,
	SCREENFX_COUNT,
}

static const s_ScreenFxSprites[E_SCREENFX][24] = {"mdl-29998:fx_blood", "mdl-29998:fx_cold", "mdl-29998:fx_heat", ""};
static const s_ScreenFxNames[E_SCREENFX][8] = {"blood", "cold", "heat", ""};

static PlayerText:s_ScreenFx[MAX_PLAYERS][E_SCREENFX];
static s_ScreenFxShown[MAX_PLAYERS][E_SCREENFX];
static s_ScreenFxLevel[MAX_PLAYERS][E_SCREENFX];
static bool:s_ScreenFxOverride[MAX_PLAYERS];

stock E_SCREENFX:ScreenFx_GetByName(const name[])
{
	for (new E_SCREENFX:effect = SCREENFX_BLOOD;effect < SCREENFX_COUNT;effect++)
	{
		if (!strcmp(name,s_ScreenFxNames[effect],true))
		{
			return effect;
		}
	}

	return SCREENFX_COUNT;
}

stock ScreenFx_Set(playerid,E_SCREENFX:effect,alpha)
{
	if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid) || effect >= SCREENFX_COUNT)
	{
		return;
	}

	alpha = clamp(alpha,0,255);

	if (alpha == s_ScreenFxShown[playerid][effect])
	{
		return;
	}

	s_ScreenFxShown[playerid][effect] = alpha;

	if (alpha <= 0)
	{
		if (s_ScreenFx[playerid][effect] != INVALID_PLAYER_TEXT_DRAW)
		{
			PlayerTextDrawDestroy(playerid,s_ScreenFx[playerid][effect]);
			s_ScreenFx[playerid][effect] = INVALID_PLAYER_TEXT_DRAW;
		}

		return;
	}

	if (s_ScreenFx[playerid][effect] == INVALID_PLAYER_TEXT_DRAW)
	{
		new PlayerText:td = CreatePlayerTextDraw(playerid,0.0,0.0,s_ScreenFxSprites[effect]);
		PlayerTextDrawFont(playerid,td,TEXT_DRAW_FONT_SPRITE_DRAW);
		PlayerTextDrawTextSize(playerid,td,SCREENFX_CANVAS_WIDTH,SCREENFX_CANVAS_HEIGHT);
		s_ScreenFx[playerid][effect] = td;
	}

	PlayerTextDrawColour(playerid,s_ScreenFx[playerid][effect],SCREENFX_TINT | alpha);
	PlayerTextDrawShow(playerid,s_ScreenFx[playerid][effect]);
}

stock ScreenFx_SetLevel(playerid,E_SCREENFX:effect,alpha)
{
	if (!Util_IsValidPlayer(playerid) || effect >= SCREENFX_COUNT)
	{
		return;
	}

	s_ScreenFxLevel[playerid][effect] = clamp(alpha,0,255);

	if (!s_ScreenFxOverride[playerid])
	{
		ScreenFx_Set(playerid,effect,s_ScreenFxLevel[playerid][effect]);
	}
}

stock ScreenFx_Scale(Float:value,Float:start,Float:finish,peak)
{
	new Float:progress = (value - start) / (finish - start);
	return floatround(Util_Clamp(progress,0.0,1.0) * float(peak));
}

stock bool:ScreenFx_IsOverride(playerid)
{
	return Util_IsValidPlayer(playerid) && s_ScreenFxOverride[playerid];
}

stock ScreenFx_SetOverride(playerid,bool:isOverride)
{
	s_ScreenFxOverride[playerid] = isOverride;

	for (new E_SCREENFX:effect = SCREENFX_BLOOD;effect < SCREENFX_COUNT;effect++)
	{
		ScreenFx_Set(playerid,effect,isOverride ? 0 : s_ScreenFxLevel[playerid][effect]);
	}
}

#include <pp-hooks>

hook Models_OnRegister()
{
	Models_AddObject(MODEL_SCREEN_FX,"ui/sprite_model.dff","ui/screen_fx.txd");
}

hook OnPlayerConnect(playerid)
{
	for (new E_SCREENFX:effect = SCREENFX_BLOOD;effect < SCREENFX_COUNT;effect++)
	{
		s_ScreenFx[playerid][effect] = INVALID_PLAYER_TEXT_DRAW;
		s_ScreenFxShown[playerid][effect] = 0;
		s_ScreenFxLevel[playerid][effect] = 0;
	}

	s_ScreenFxOverride[playerid] = false;
}
