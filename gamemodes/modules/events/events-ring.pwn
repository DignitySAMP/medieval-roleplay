#define EVENTS_RING_PIECES (12)
#define EVENTS_RING_INSIDE (5.5)
#define EVENTS_RING_MARK (3.0)
#define EVENTS_RING_LABEL_RANGE (40.0)
#define EVENTS_RING_LABEL_HEIGHT (3.9)
#define EVENTS_RING_LABEL_COLOUR (0xE8D8A8FF)
#define EVENTS_RING_LABEL_LEN (96)
#define EVENTS_RING_LABEL_IDLE "The ring"
#define EVENTS_RING_LABEL_PIECE (4)

new const g_EventsRingPieces[EVENTS_RING_PIECES][E_EVENTS_PIECE] = {
	{MODEL_TOURNEY_LISTS, -3.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, 3.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, -3.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS, 3.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS_GATE, -6.0, 3.0, 90.0},
	{MODEL_TOURNEY_LISTS, -6.0, -3.0, 90.0},
	{MODEL_TOURNEY_LISTS_GATE, 6.0, -3.0, 270.0},
	{MODEL_TOURNEY_LISTS, 6.0, 3.0, 270.0},
	{MODEL_TOURNEY_LISTS_POST, -6.0, -6.0, 0.0},
	{MODEL_TOURNEY_LISTS_POST, -6.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS_POST, 6.0, -6.0, 0.0},
	{MODEL_TOURNEY_LISTS_POST, 6.0, 6.0, 0.0}
};

static STREAMER_TAG_OBJECT:s_EventsRingObjects[EVENTS_RING_PIECES];
static STREAMER_TAG_3D_TEXT_LABEL:s_EventsRingLabel = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
static s_EventsRingLabelText[EVENTS_RING_LABEL_LEN];
static bool:s_EventsRingPlaced;

stock bool:Events_HasRing()
{
	return g_EventsRing[0] != 0.0;
}

stock Float:Events_RingFrameAngle()
{
	return 90.0 - g_EventsRing[3];
}

stock Events_RingToWorld(Float:frameX,Float:frameY,&Float:x,&Float:y)
{
	new Float:rzf = Events_RingFrameAngle();
	x = g_EventsRing[0] + frameX * floatcos(rzf,degrees) - frameY * floatsin(rzf,degrees);
	y = g_EventsRing[1] + frameX * floatsin(rzf,degrees) + frameY * floatcos(rzf,degrees);
}

stock Events_WorldToRing(Float:x,Float:y,&Float:frameX,&Float:frameY)
{
	new Float:rzf = Events_RingFrameAngle(), Float:dx = x - g_EventsRing[0], Float:dy = y - g_EventsRing[1];
	frameX = dx * floatcos(rzf,degrees) + dy * floatsin(rzf,degrees);
	frameY = -dx * floatsin(rzf,degrees) + dy * floatcos(rzf,degrees);
}

stock Float:Events_RingGroundAt(Float:x,Float:y)
{
	new Float:z;

	if (!Placement_FindSurface(x,y,g_EventsRing[2] + EVENTS_LISTS_RAY_UP,EVENTS_LISTS_RAY_REACH,z))
	{
		return g_EventsRing[2];
	}

	return z;
}

stock bool:Events_IsInsideRing(Float:x,Float:y,Float:z)
{
	if (!Events_HasRing())
	{
		return false;
	}

	new Float:frameX, Float:frameY;
	Events_WorldToRing(x,y,frameX,frameY);
	return floatabs(frameX) <= EVENTS_RING_INSIDE && floatabs(frameY) <= EVENTS_RING_INSIDE && floatabs(z - g_EventsRing[2]) < 6.0;
}

stock bool:Events_IsPlayerInRing(playerid)
{
	if (!IsPlayerConnected(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return Events_IsInsideRing(x,y,z);
}

stock Events_GetRingCentre(&Float:x,&Float:y,&Float:z)
{
	x = g_EventsRing[0];
	y = g_EventsRing[1];
	z = g_EventsRing[2];
}

stock Events_RingMark(side,&Float:x,&Float:y,&Float:z,&Float:angle)
{
	new Float:ox, Float:oy;
	Events_RingToWorld(side == 0 ? -EVENTS_RING_MARK : EVENTS_RING_MARK,side == 0 ? EVENTS_RING_MARK : -EVENTS_RING_MARK,x,y);
	Events_RingToWorld(side == 0 ? EVENTS_RING_MARK : -EVENTS_RING_MARK,side == 0 ? -EVENTS_RING_MARK : EVENTS_RING_MARK,ox,oy);
	z = Events_RingGroundAt(x,y) + 1.0;
	angle = Util_GetAngleToPoint(x,y,ox,oy);
}

stock Events_PlaceRing()
{
	if (s_EventsRingPlaced || !Events_HasRing())
	{
		return 0;
	}

	for (new i = 0;i < EVENTS_RING_PIECES;i++)
	{
		new Float:x, Float:y;
		Events_RingToWorld(g_EventsRingPieces[i][E_EVENTS_PIECE_X],g_EventsRingPieces[i][E_EVENTS_PIECE_Y],x,y);
		s_EventsRingObjects[i] = Events_PlacePiece(g_EventsRingPieces[i][E_EVENTS_PIECE_MODEL],x,y,Events_RingGroundAt(x,y),Util_NormalizeAngle(Events_RingFrameAngle() + g_EventsRingPieces[i][E_EVENTS_PIECE_R]));
	}

	new Float:x, Float:y;
	Events_RingToWorld(g_EventsRingPieces[EVENTS_RING_LABEL_PIECE][E_EVENTS_PIECE_X],g_EventsRingPieces[EVENTS_RING_LABEL_PIECE][E_EVENTS_PIECE_Y],x,y);
	strcopy(s_EventsRingLabelText,EVENTS_RING_LABEL_IDLE);
	s_EventsRingLabel = CreateDynamic3DTextLabel(s_EventsRingLabelText,EVENTS_RING_LABEL_COLOUR,x,y,Events_RingGroundAt(x,y) + EVENTS_RING_LABEL_HEIGHT,EVENTS_RING_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,0,0,0,-1,EVENTS_RING_LABEL_RANGE);
	s_EventsRingPlaced = true;
	return EVENTS_RING_PIECES;
}

stock Events_GetRingObject(piece)
{
	if (piece < 0 || piece >= EVENTS_RING_PIECES || !s_EventsRingPlaced)
	{
		return INVALID_STREAMER_ID;
	}

	return _:s_EventsRingObjects[piece];
}

stock Events_GetRingLabelId()
{
	return _:s_EventsRingLabel;
}

stock Events_SetRingLabel(const text[])
{
	if (!s_EventsRingPlaced || text[0] == EOS || (s_EventsRingLabelText[0] != EOS && !strcmp(text,s_EventsRingLabelText)))
	{
		return;
	}

	strcopy(s_EventsRingLabelText,text);
	UpdateDynamic3DTextLabelText(s_EventsRingLabel,EVENTS_RING_LABEL_COLOUR,s_EventsRingLabelText);
}

stock Events_GetRingLabel(dest[],size = sizeof(dest))
{
	strcopy(dest,s_EventsRingLabelText,size);
}
