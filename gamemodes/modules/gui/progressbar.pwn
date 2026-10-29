#define MAX_PLAYER_BARS (8)
#define INVALID_PLAYER_BAR (-1)

enum E_BAR_DIRECTION
{
	BAR_DIRECTION_RIGHT,
	BAR_DIRECTION_LEFT,
	BAR_DIRECTION_UP,
	BAR_DIRECTION_DOWN,
}

enum E_BAR
{
	bool:E_BAR_USED,
	Float:E_BAR_X,
	Float:E_BAR_Y,
	Float:E_BAR_WIDTH,
	Float:E_BAR_HEIGHT,
	Float:E_BAR_VALUE,
	E_BAR_DIRECTION:E_BAR_DIR,
	PlayerText:E_BAR_BACK,
	PlayerText:E_BAR_FILL,
}

static s_Bars[MAX_PLAYERS][MAX_PLAYER_BARS][E_BAR];

static PlayerText:PBar_Box(playerid,Float:x,Float:y,Float:width,Float:height,colour)
{
	new PlayerText:td = CreatePlayerTextDraw(playerid,x,y,"_");
	PlayerTextDrawUseBox(playerid,td,true);
	PlayerTextDrawTextSize(playerid,td,x + width,0.0);
	PlayerTextDrawLetterSize(playerid,td,1.0,height / 10.0 - 0.35);
	PlayerTextDrawBoxColour(playerid,td,colour);
	PlayerTextDrawSetShadow(playerid,td,0);
	PlayerTextDrawSetOutline(playerid,td,0);
	PlayerTextDrawBackgroundColour(playerid,td,0);
	PlayerTextDrawColour(playerid,td,0);
	return td;
}

static PBar_Apply(playerid,barid)
{
	new Float:pct = s_Bars[playerid][barid][E_BAR_VALUE] / 100.0;
	new Float:x = s_Bars[playerid][barid][E_BAR_X], Float:y = s_Bars[playerid][barid][E_BAR_Y];
	new Float:w = s_Bars[playerid][barid][E_BAR_WIDTH], Float:h = s_Bars[playerid][barid][E_BAR_HEIGHT];
	new PlayerText:fill = s_Bars[playerid][barid][E_BAR_FILL];

	switch (s_Bars[playerid][barid][E_BAR_DIR])
	{
		case BAR_DIRECTION_RIGHT:
		{
			PlayerTextDrawTextSize(playerid,fill,x + w * pct,0.0);
		}
		case BAR_DIRECTION_LEFT:
		{
			PlayerTextDrawDestroy(playerid,fill);
			fill = PBar_Box(playerid,x + w * (1.0 - pct),y,w * pct,h,0);
			s_Bars[playerid][barid][E_BAR_FILL] = fill;
		}
		case BAR_DIRECTION_UP:
		{
			PlayerTextDrawDestroy(playerid,fill);
			fill = PBar_Box(playerid,x,y + h * (1.0 - pct),w,h * pct + 3.5,0);
			s_Bars[playerid][barid][E_BAR_FILL] = fill;
		}
		case BAR_DIRECTION_DOWN:
		{
			PlayerTextDrawLetterSize(playerid,fill,1.0,(h * pct) / 10.0 - 0.35);
		}
	}
}

stock PBar_Create(playerid,Float:x,Float:y,Float:width,Float:height,colour,E_BAR_DIRECTION:direction = BAR_DIRECTION_RIGHT)
{
	new barid = -1;
	for (new i = 0; i < MAX_PLAYER_BARS; i++)
	{
		if (!s_Bars[playerid][i][E_BAR_USED])
		{
			barid = i;
			break;
		}
	}

	if (barid == -1)
	{
		return INVALID_PLAYER_BAR;
	}

	s_Bars[playerid][barid][E_BAR_USED] = true;
	s_Bars[playerid][barid][E_BAR_X] = x;
	s_Bars[playerid][barid][E_BAR_Y] = y;
	s_Bars[playerid][barid][E_BAR_WIDTH] = width;
	s_Bars[playerid][barid][E_BAR_HEIGHT] = height;
	s_Bars[playerid][barid][E_BAR_VALUE] = 100.0;
	s_Bars[playerid][barid][E_BAR_DIR] = direction;
	s_Bars[playerid][barid][E_BAR_BACK] = PBar_Box(playerid,x,y,width,height + 3.5,(colour & 0xFFFFFF00) | 0x50);
	s_Bars[playerid][barid][E_BAR_FILL] = PBar_Box(playerid,x,y,width,height + 3.5,colour);
	PBar_Apply(playerid,barid);
	PlayerTextDrawBoxColour(playerid,s_Bars[playerid][barid][E_BAR_FILL],colour);
	return barid;
}

stock PBar_SetValue(playerid,bar,Float:value,colour)
{
	new barid = bar;
	if (barid < 0 || barid >= MAX_PLAYER_BARS || !s_Bars[playerid][barid][E_BAR_USED])
	{
		return;
	}

	s_Bars[playerid][barid][E_BAR_VALUE] = Util_Clamp(value,0.0,100.0);
	PBar_Apply(playerid,barid);
	PlayerTextDrawBoxColour(playerid,s_Bars[playerid][barid][E_BAR_FILL],colour);
	PlayerTextDrawShow(playerid,s_Bars[playerid][barid][E_BAR_BACK]);
	PlayerTextDrawShow(playerid,s_Bars[playerid][barid][E_BAR_FILL]);
}

stock bool:PBar_GetTextDraws(playerid,bar,&PlayerText:back,&PlayerText:fill)
{
	if (bar < 0 || bar >= MAX_PLAYER_BARS || !s_Bars[playerid][bar][E_BAR_USED])
	{
		return false;
	}

	back = s_Bars[playerid][bar][E_BAR_BACK];
	fill = s_Bars[playerid][bar][E_BAR_FILL];
	return true;
}

stock PBar_Show(playerid,bar)
{
	new barid = bar;
	if (barid < 0 || barid >= MAX_PLAYER_BARS || !s_Bars[playerid][barid][E_BAR_USED])
	{
		return;
	}

	PlayerTextDrawShow(playerid,s_Bars[playerid][barid][E_BAR_BACK]);
	PlayerTextDrawShow(playerid,s_Bars[playerid][barid][E_BAR_FILL]);
}

stock PBar_Hide(playerid,bar)
{
	new barid = bar;
	if (barid < 0 || barid >= MAX_PLAYER_BARS || !s_Bars[playerid][barid][E_BAR_USED])
	{
		return;
	}

	PlayerTextDrawHide(playerid,s_Bars[playerid][barid][E_BAR_BACK]);
	PlayerTextDrawHide(playerid,s_Bars[playerid][barid][E_BAR_FILL]);
}

stock PBar_Destroy(playerid,bar)
{
	new barid = bar;
	if (barid < 0 || barid >= MAX_PLAYER_BARS || !s_Bars[playerid][barid][E_BAR_USED])
	{
		return;
	}

	PlayerTextDrawDestroy(playerid,s_Bars[playerid][barid][E_BAR_BACK]);
	PlayerTextDrawDestroy(playerid,s_Bars[playerid][barid][E_BAR_FILL]);
	s_Bars[playerid][barid][E_BAR_USED] = false;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	for (new i = 0; i < MAX_PLAYER_BARS; i++)
	{
		s_Bars[playerid][i][E_BAR_USED] = false;
	}
}
