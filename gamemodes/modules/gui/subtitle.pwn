#define SUBTITLE_X (320.0)
#define SUBTITLE_Y (402.0)
#define SUBTITLE_WIDTH (204.0)
#define SUBTITLE_LETTER_X (0.21)
#define SUBTITLE_LETTER_Y (1.1)
#define SUBTITLE_LINE_HEIGHT (11.0)
#define SUBTITLE_LINE_CHARS (46)
#define SUBTITLE_BACKGROUND_WIDTH (224.0)
#define SUBTITLE_BACKGROUND_PADDING (6.0)
#define SUBTITLE_BACKGROUND_TINT (0xFFFFFF7D)
#define SUBTITLE_END_SHARE (0.281)
#define SUBTITLE_COLOUR (0xD8CCB2FF)
#define SUBTITLE_TEXT_LEN (256)
#define SUBTITLE_MIN_SECONDS (4)
#define SUBTITLE_CHARS_PER_SECOND (20)
#define SUBTITLE_STACK_MS (1500)
#define SUBTITLE_STACK_LINES (4)

static PlayerText:s_Subtitle[MAX_PLAYERS] = {INVALID_PLAYER_TEXT_DRAW, ...};
static PlayerText:s_SubtitleBackground[MAX_PLAYERS][3];
static s_SubtitleToken[MAX_PLAYERS];
static s_SubtitleText[MAX_PLAYERS][SUBTITLE_TEXT_LEN];
static s_SubtitleShownText[MAX_PLAYERS][SUBTITLE_TEXT_LEN];
static s_SubtitleSince[MAX_PLAYERS];
static bool:s_SubtitleShown[MAX_PLAYERS];

static PlayerText:Subtitle_CreateText(playerid)
{
	new PlayerText:td = CreatePlayerTextDraw(playerid,SUBTITLE_X,SUBTITLE_Y,"_");
	PlayerTextDrawFont(playerid,td,TEXT_DRAW_FONT_1);
	PlayerTextDrawLetterSize(playerid,td,SUBTITLE_LETTER_X,SUBTITLE_LETTER_Y);
	PlayerTextDrawTextSize(playerid,td,0.0,SUBTITLE_WIDTH);
	PlayerTextDrawAlignment(playerid,td,TEXT_DRAW_ALIGN_CENTER);
	PlayerTextDrawColour(playerid,td,SUBTITLE_COLOUR);
	PlayerTextDrawSetShadow(playerid,td,1);
	PlayerTextDrawSetOutline(playerid,td,0);
	PlayerTextDrawBackgroundColour(playerid,td,255);
	PlayerTextDrawSetProportional(playerid,td,true);
	return td;
}

static Subtitle_DestroyBackground(playerid)
{
	for (new i = 0;i < 3;i++)
	{
		if (s_SubtitleBackground[playerid][i] != INVALID_PLAYER_TEXT_DRAW)
		{
			PlayerTextDrawDestroy(playerid,s_SubtitleBackground[playerid][i]);
			s_SubtitleBackground[playerid][i] = INVALID_PLAYER_TEXT_DRAW;
		}
	}
}

static PlayerText:Subtitle_CreatePiece(playerid,Float:x,Float:y,Float:width,Float:height,const sprite[])
{
	new PlayerText:td = CreatePlayerTextDraw(playerid,x,y,sprite);
	PlayerTextDrawFont(playerid,td,TEXT_DRAW_FONT_SPRITE_DRAW);
	PlayerTextDrawTextSize(playerid,td,width,height);
	PlayerTextDrawColour(playerid,td,SUBTITLE_BACKGROUND_TINT);
	return td;
}

static Subtitle_ShowBackground(playerid,lines)
{
	new Float:height = float(lines) * SUBTITLE_LINE_HEIGHT + SUBTITLE_BACKGROUND_PADDING * 2.0, Float:x = SUBTITLE_X - SUBTITLE_BACKGROUND_WIDTH / 2.0, Float:y = SUBTITLE_Y - SUBTITLE_BACKGROUND_PADDING, Float:ends = SUBTITLE_BACKGROUND_WIDTH * SUBTITLE_END_SHARE;
	Subtitle_DestroyBackground(playerid);
	s_SubtitleBackground[playerid][0] = Subtitle_CreatePiece(playerid,x,y,ends,height,"mdl-29997:hdr_l");
	s_SubtitleBackground[playerid][1] = Subtitle_CreatePiece(playerid,x + ends,y,SUBTITLE_BACKGROUND_WIDTH - ends * 2.0,height,"mdl-29997:hdr_mid");
	s_SubtitleBackground[playerid][2] = Subtitle_CreatePiece(playerid,x + SUBTITLE_BACKGROUND_WIDTH - ends,y,ends,height,"mdl-29997:hdr_r");

	for (new i = 0;i < 3;i++)
	{
		PlayerTextDrawShow(playerid,s_SubtitleBackground[playerid][i]);
	}
}

static Subtitle_CountLines(const text[])
{
	new lines = 0, start = 0, position = 0;

	do
	{
		position = strfind(text,"~n~",false,start);
		lines += 1 + max(0,(position == -1 ? strlen(text) : position) - start - 1) / SUBTITLE_LINE_CHARS;
		start = position + 3;
	}
	while (position != -1);

	return lines;
}

static Subtitle_Stack(playerid,const text[])
{
	if (s_SubtitleShown[playerid] && GetTickCount() - s_SubtitleSince[playerid] < SUBTITLE_STACK_MS && !strcmp(s_SubtitleText[playerid],text))
	{
		return;
	}

	if (!s_SubtitleShown[playerid] || GetTickCount() - s_SubtitleSince[playerid] >= SUBTITLE_STACK_MS)
	{
		strcopy(s_SubtitleShownText[playerid],text,SUBTITLE_TEXT_LEN);
		return;
	}

	new stacked[SUBTITLE_TEXT_LEN * 2];
	format(stacked,sizeof(stacked),"%s~n~~w~%s",s_SubtitleShownText[playerid],text);

	while (Subtitle_CountLines(stacked) > SUBTITLE_STACK_LINES || strlen(stacked) >= SUBTITLE_TEXT_LEN)
	{
		new cut = strfind(stacked,"~n~");

		if (cut == -1)
		{
			strcopy(stacked,text);
			break;
		}

		strdel(stacked,0,cut + 3);
	}

	strcopy(s_SubtitleShownText[playerid],stacked,SUBTITLE_TEXT_LEN);
}

stock Subtitle_Show(playerid,const text[])
{
	if (!Util_IsValidPlayer(playerid) || s_Subtitle[playerid] == INVALID_PLAYER_TEXT_DRAW || text[0] == EOS)
	{
		return;
	}

	Subtitle_Stack(playerid,text);

	PlayerTextDrawDestroy(playerid,s_Subtitle[playerid]);
	Subtitle_ShowBackground(playerid,Subtitle_CountLines(s_SubtitleShownText[playerid]));
	s_Subtitle[playerid] = Subtitle_CreateText(playerid);

	new tinted[SUBTITLE_TEXT_LEN * 2];
	Kit_TintText(s_SubtitleShownText[playerid],tinted);
	PlayerTextDrawSetString(playerid,s_Subtitle[playerid],tinted);
	PlayerTextDrawShow(playerid,s_Subtitle[playerid]);
	strcopy(s_SubtitleText[playerid],text,SUBTITLE_TEXT_LEN);
	s_SubtitleShown[playerid] = true;
	s_SubtitleSince[playerid] = GetTickCount();

	new seconds = max(SUBTITLE_MIN_SECONDS,strlen(s_SubtitleShownText[playerid]) / SUBTITLE_CHARS_PER_SECOND + 2);
	SetTimerEx("Subtitle_Expire",seconds * 1000,false,"dd",playerid,++s_SubtitleToken[playerid]);
}

stock bool:Subtitle_IsShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_SubtitleShown[playerid];
}

stock Subtitle_GetText(playerid,dest[],size = sizeof(dest))
{
	strcopy(dest,s_SubtitleText[playerid],size);
}

stock Subtitle_GetShownText(playerid,dest[],size = sizeof(dest))
{
	if (!Subtitle_IsShown(playerid))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_SubtitleShownText[playerid],size);
}

stock Subtitle_Hide(playerid)
{
	s_SubtitleToken[playerid]++;
	s_SubtitleShown[playerid] = false;
	Subtitle_DestroyBackground(playerid);

	if (s_Subtitle[playerid] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawHide(playerid,s_Subtitle[playerid]);
	}
}

forward Subtitle_Expire(playerid,token);

public Subtitle_Expire(playerid,token)
{
	if (IsPlayerConnected(playerid) && s_SubtitleToken[playerid] == token && s_Subtitle[playerid] != INVALID_PLAYER_TEXT_DRAW)
	{
		PlayerTextDrawHide(playerid,s_Subtitle[playerid]);
		Subtitle_DestroyBackground(playerid);
		s_SubtitleShown[playerid] = false;
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_SubtitleToken[playerid]++;
	s_Subtitle[playerid] = INVALID_PLAYER_TEXT_DRAW;

	for (new i = 0;i < 3;i++)
	{
		s_SubtitleBackground[playerid][i] = INVALID_PLAYER_TEXT_DRAW;
	}

	if (IsPlayerNPC(playerid))
	{
		return;
	}

	s_Subtitle[playerid] = Subtitle_CreateText(playerid);
	s_SubtitleShown[playerid] = false;
	s_SubtitleText[playerid][0] = EOS;
	s_SubtitleShownText[playerid][0] = EOS;
}

hook OnPlayerDisconnect(playerid,reason)
{
	s_SubtitleToken[playerid]++;
	s_Subtitle[playerid] = INVALID_PLAYER_TEXT_DRAW;
}
