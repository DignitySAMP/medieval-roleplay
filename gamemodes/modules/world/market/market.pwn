#define MARKET_STREAM_STALL (150.0)
#define MARKET_STREAM_GOODS (70.0)
#define MARKET_OPEN_HOUR (9)
#define MARKET_CLOSE_HOUR (16)

static bool:s_MarketOpen;
static bool:s_MarketFair;
static s_MarketOverride = -1;

static STREAMER_TAG_OBJECT:s_MarketObjects[MARKET_SEED_PROPS] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};

stock Market_PlaceOf(prop)
{
	for (new place = 0;place < MARKET_SEED_PLACES;place++)
	{
		if (prop >= g_MarketPlaceDefs[place][E_MARKET_PLACE_DEF_FIRST] && prop < g_MarketPlaceDefs[place][E_MARKET_PLACE_DEF_FIRST] + g_MarketPlaceDefs[place][E_MARKET_PLACE_DEF_COUNT])
		{
			return place;
		}
	}

	return -1;
}

stock Float:Market_StreamDistance(prop)
{
	new place = Market_PlaceOf(prop);

	if (place != -1 && g_MarketPlaceDefs[place][E_MARKET_PLACE_DEF_FIRST] == prop)
	{
		return MARKET_STREAM_STALL;
	}

	return MARKET_STREAM_GOODS;
}

stock Market_Place()
{
	for (new prop = 0;prop < MARKET_SEED_PROPS;prop++)
	{
		if (!s_MarketOpen && g_MarketPropDefs[prop][E_MARKET_PROP_DEF_MODEL] != MARKET_STALL_BODY)
		{
			if (IsValidDynamicObject(s_MarketObjects[prop]))
			{
				DestroyDynamicObject(s_MarketObjects[prop]);
			}
			s_MarketObjects[prop] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
			continue;
		}

		if (s_MarketObjects[prop] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
		{
			continue;
		}

		s_MarketObjects[prop] = CreateDynamicObject(g_MarketPropDefs[prop][E_MARKET_PROP_DEF_MODEL],g_MarketPropDefs[prop][E_MARKET_PROP_DEF_POS][0],g_MarketPropDefs[prop][E_MARKET_PROP_DEF_POS][1],g_MarketPropDefs[prop][E_MARKET_PROP_DEF_POS][2],0.0,0.0,g_MarketPropDefs[prop][E_MARKET_PROP_DEF_POS][3],0,0,-1,Market_StreamDistance(prop));
	}
}

stock STREAMER_TAG_OBJECT:Market_GetObject(prop)
{
	if (prop < 0 || prop >= MARKET_SEED_PROPS)
	{
		return STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	return s_MarketObjects[prop];
}

stock Market_CountPlaced()
{
	new count = 0;

	for (new prop = 0;prop < MARKET_SEED_PROPS;prop++)
	{
		if (IsValidDynamicObject(s_MarketObjects[prop]))
		{
			count++;
		}
	}

	return count;
}

stock bool:Market_IsOpen()
{
    return s_MarketOpen;
}

stock bool:Market_IsScheduled(day,month,year,hour)
{
    return Calendar_DaysSinceEpoch(day,month,year) % 7 == 6 && hour >= MARKET_OPEN_HOUR && hour < MARKET_CLOSE_HOUR;
}

stock bool:Market_Contains(Float:x,Float:y,world = 0,interior = 0)
{
    return world == 0 && interior == 0 && VectorSize(x - g_MarketSquare[0],y - g_MarketSquare[1],0.0) < 25.0;
}

stock Market_Refresh()
{
    new day, month, year;
    Calendar_GetDate(day,month,year);
    new bool:open = s_MarketOverride == -1 ? (s_MarketFair || Market_IsScheduled(day,month,year,Calendar_GetHour())) : s_MarketOverride == 1;
    if (open == s_MarketOpen)
    {
        return;
    }
    s_MarketOpen = open;
    Market_Place();
    Nearby_StreamObjectsAt(g_MarketSquare[0],g_MarketSquare[1],g_MarketSquare[2],0,0,MARKET_STREAM_STALL + 25.0);
    pawn_call_public("Market_OnChanged","d",_:open);
}

stock Market_SetOverride(value)
{
    s_MarketOverride = value >= 0 ? min(value,1) : -1;
    Market_Refresh();
}

stock Market_GetOverride()
{
    return s_MarketOverride;
}

stock bool:Market_IsFairOpen()
{
    return s_MarketFair;
}

stock Market_SetFairOpen(bool:open)
{
    s_MarketFair = open;
    Market_Refresh();
}

forward Market_OnChanged(open);
public Market_OnChanged(open)
{
    return 1;
}

stock Market_GetSquare(&Float:x,&Float:y,&Float:z)
{
    x = g_MarketSquare[0];
    y = g_MarketSquare[1];
    z = g_MarketSquare[2];
}
