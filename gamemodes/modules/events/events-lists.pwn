#define MODEL_TOURNEY_TILT (-8211)
#define MODEL_TOURNEY_TILT_END (-8212)
#define MODEL_TOURNEY_LISTS (-8213)
#define MODEL_TOURNEY_LISTS_GATE (-8214)
#define MODEL_TOURNEY_LISTS_POST (-8215)
#define MODEL_TOURNEY_BUTT (-8216)
#define MODEL_TOURNEY_HERALD (-8217)
#define MODEL_TOURNEY_SPLINTERS (-8220)
#define MODEL_TOURNEY_QUINTAIN (-8221)
#define MODEL_TOURNEY_QUINTAIN_ARM (-8222)
#define EVENTS_LISTS_PIECES (31)
#define EVENTS_LISTS_HERALD_PIECE (27)
#define EVENTS_LISTS_STREAM (200.0)
#define EVENTS_LISTS_RAY_UP (8.0)
#define EVENTS_LISTS_RAY_REACH (16.0)
#define EVENTS_HERALD_DECK_Y (7.35)
#define EVENTS_HERALD_DECK_Z (1.0)

enum E_EVENTS_PIECE
{
	E_EVENTS_PIECE_MODEL,
	Float:E_EVENTS_PIECE_X,
	Float:E_EVENTS_PIECE_Y,
	Float:E_EVENTS_PIECE_R,
}

new const g_EventsListsPieces[EVENTS_LISTS_PIECES][E_EVENTS_PIECE] = {
	{MODEL_TOURNEY_TILT_END, -15.0, 0.0, 0.0},
	{MODEL_TOURNEY_TILT, -12.0, 0.0, 0.0},
	{MODEL_TOURNEY_TILT, -6.0, 0.0, 0.0},
	{MODEL_TOURNEY_TILT, 0.0, 0.0, 0.0},
	{MODEL_TOURNEY_TILT, 6.0, 0.0, 0.0},
	{MODEL_TOURNEY_TILT, 12.0, 0.0, 0.0},
	{MODEL_TOURNEY_TILT_END, 15.0, 0.0, 180.0},
	{MODEL_TOURNEY_LISTS, -15.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, -9.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, -3.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, 3.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, 9.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, 15.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS, -15.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS, -9.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS, -3.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS, 3.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS, 9.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS, 15.0, -6.0, 180.0},
	{MODEL_TOURNEY_LISTS_GATE, -18.0, -3.0, 90.0},
	{MODEL_TOURNEY_LISTS, -18.0, 3.0, 90.0},
	{MODEL_TOURNEY_LISTS, 18.0, -3.0, 270.0},
	{MODEL_TOURNEY_LISTS_GATE, 18.0, 3.0, 270.0},
	{MODEL_TOURNEY_LISTS_POST, -18.0, -6.0, 0.0},
	{MODEL_TOURNEY_LISTS_POST, -18.0, 6.0, 0.0},
	{MODEL_TOURNEY_LISTS_POST, 18.0, -6.0, 0.0},
	{MODEL_TOURNEY_LISTS_POST, 18.0, 6.0, 0.0},
	{MODEL_TOURNEY_HERALD, 0.0, 7.6, 0.0},
	{MODEL_TOURNEY_BUTT, 20.0, -8.0, 270.0},
	{MODEL_TOURNEY_BUTT, 35.0, -8.0, 270.0},
	{MODEL_TOURNEY_BUTT, 50.0, -8.0, 270.0}
};

new const g_EventsListsExtraModels[EVENTS_SEED_EXTRAS] = {
	MODEL_VILLAGE_PAVILION,
	MODEL_VILLAGE_PAVILION,
	MODEL_VILLAGE_TRAINING_DUMMY,
	MODEL_VILLAGE_ARCHERY_TARGET,
	MODEL_VILLAGE_TILT_RAIL,
	MODEL_VILLAGE_LISTS_FENCE
};

static STREAMER_TAG_OBJECT:s_EventsListsObjects[EVENTS_LISTS_PIECES];
static STREAMER_TAG_OBJECT:s_EventsListsExtras[EVENTS_SEED_EXTRAS];
static Float:s_EventsHeraldStandZ;
static bool:s_EventsListsPlaced;

stock Float:Events_ListsFrameAngle()
{
	return 90.0 - EVENTS_TILT_HEADING;
}

stock Events_ListsToWorld(Float:frameX,Float:frameY,&Float:x,&Float:y)
{
	new Float:rzf = Events_ListsFrameAngle();
	x = g_EventsLists[0] + frameX * floatcos(rzf,degrees) - frameY * floatsin(rzf,degrees);
	y = g_EventsLists[1] + frameX * floatsin(rzf,degrees) + frameY * floatcos(rzf,degrees);
}

stock Float:Events_ListsGroundAt(Float:x,Float:y)
{
	new Float:z;

	if (!Placement_FindSurface(x,y,g_EventsLists[2] + EVENTS_LISTS_RAY_UP,EVENTS_LISTS_RAY_REACH,z))
	{
		return g_EventsLists[2];
	}

	return z;
}

stock Float:Events_PieceHalfLength(model)
{
	switch (model)
	{
		case MODEL_TOURNEY_TILT, MODEL_TOURNEY_LISTS, MODEL_TOURNEY_LISTS_GATE: return 3.0;
		case MODEL_VILLAGE_TILT_RAIL, MODEL_VILLAGE_LISTS_FENCE: return 2.0;
	}

	return 0.0;
}

stock STREAMER_TAG_OBJECT:Events_PlacePiece(model,Float:x,Float:y,Float:z,Float:rz)
{
	new Float:half = Events_PieceHalfLength(model), Float:ry = 0.0;

	if (half > 0.0)
	{
		new Float:dx = half * floatcos(rz,degrees), Float:dy = half * floatsin(rz,degrees), Float:low = Events_ListsGroundAt(x - dx,y - dy), Float:high = Events_ListsGroundAt(x + dx,y + dy);
		ry = -atan2(high - low,half * 2.0);
		z = (low + high) / 2.0;
	}

	return CreateDynamicObject(model,x,y,z,0.0,ry,rz,0,0,-1,EVENTS_LISTS_STREAM,EVENTS_LISTS_STREAM);
}

stock Events_PlaceLists()
{
	if (s_EventsListsPlaced || g_EventsLists[0] == 0.0)
	{
		return 0;
	}

	for (new i = 0;i < EVENTS_LISTS_PIECES;i++)
	{
		new Float:x, Float:y, Float:rz = Util_NormalizeAngle(Events_ListsFrameAngle() + g_EventsListsPieces[i][E_EVENTS_PIECE_R]);
		Events_ListsToWorld(g_EventsListsPieces[i][E_EVENTS_PIECE_X],g_EventsListsPieces[i][E_EVENTS_PIECE_Y],x,y);

		if (i >= EVENTS_LISTS_PIECES - 3)
		{
			new butt = i - (EVENTS_LISTS_PIECES - 3);
			x = g_EventsButts[butt][0];
			y = g_EventsButts[butt][1];
			rz = Util_NormalizeAngle(atan2(g_EventsLine[0] - x,-(g_EventsLine[1] - y)));
		}

		new Float:z = Events_ListsGroundAt(x,y);

		if (i == EVENTS_LISTS_HERALD_PIECE)
		{
			s_EventsHeraldStandZ = z;
		}

		s_EventsListsObjects[i] = Events_PlacePiece(g_EventsListsPieces[i][E_EVENTS_PIECE_MODEL],x,y,z,rz);
	}

	for (new i = 0;i < EVENTS_SEED_EXTRAS;i++)
	{
		new Float:fx = g_EventsExtras[i][0], Float:fy = g_EventsExtras[i][1], Float:x, Float:y;
		Events_ListsToWorld(fx,fy,x,y);
		s_EventsListsExtras[i] = Events_PlacePiece(g_EventsListsExtraModels[i],x,y,Events_ListsGroundAt(x,y),Util_NormalizeAngle(Events_ListsFrameAngle() + atan2(-fx,fy)));
	}

	s_EventsListsPlaced = true;
	return EVENTS_LISTS_PIECES + EVENTS_SEED_EXTRAS;
}

stock bool:Events_GetHeraldDeck(&Float:x,&Float:y,&Float:z)
{
	if (!s_EventsListsPlaced)
	{
		return false;
	}

	Events_ListsToWorld(0.0,EVENTS_HERALD_DECK_Y,x,y);
	z = s_EventsHeraldStandZ + EVENTS_HERALD_DECK_Z;
	return true;
}

stock Events_GetListsExtra(extra)
{
	if (extra < 0 || extra >= EVENTS_SEED_EXTRAS || !s_EventsListsPlaced)
	{
		return INVALID_STREAMER_ID;
	}

	return _:s_EventsListsExtras[extra];
}

stock Events_GetListsObject(piece)
{
	if (piece < 0 || piece >= EVENTS_LISTS_PIECES || !s_EventsListsPlaced)
	{
		return INVALID_STREAMER_ID;
	}

	return _:s_EventsListsObjects[piece];
}
