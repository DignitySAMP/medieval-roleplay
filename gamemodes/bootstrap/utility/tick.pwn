#define TICK_SLICES (4)
#define TICK_SLICE_MS (250)
#define TICK_SLICE_SIZE ((MAX_PLAYERS + TICK_SLICES - 1) / TICK_SLICES)

static s_TickSlice;

forward Tick_OnPlayerSecond(playerid);

public Tick_OnPlayerSecond(playerid)
{
	return true;
}

Timer_Declare(Tick_SliceTimer)
{
	new first = s_TickSlice * TICK_SLICE_SIZE, last = first + TICK_SLICE_SIZE;

	if (last > MAX_PLAYERS)
	{
		last = MAX_PLAYERS;
	}

	for (new playerid = first;playerid < last;playerid++)
	{
		if (!IsPlayerConnected(playerid) || IsPlayerNPC(playerid))
		{
			continue;
		}

		pawn_call_public("Tick_OnPlayerSecond","d",playerid);
	}

	s_TickSlice = (s_TickSlice + 1) % TICK_SLICES;
	return true;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	s_TickSlice = 0;
	Timer_Start(Tick_SliceTimer,TICK_SLICE_MS);
}
