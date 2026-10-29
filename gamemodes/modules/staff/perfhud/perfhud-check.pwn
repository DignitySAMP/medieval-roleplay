#define PERFHUD_CHECK_SETTLE_MS (5000)
#define PERFHUD_CHECK_HEADINGS (8)
#define PERFHUD_CHECK_HEADING_SECONDS (12)
#define PERFHUD_CHECK_TURN_MS (2000)

enum E_PERFHUD_SPOT
{
	E_PERFHUD_SPOT_NAME[24],
	Float:E_PERFHUD_SPOT_POS[3],
	Float:E_PERFHUD_SPOT_ANGLE,
}

static const s_PerfhudSpots[][E_PERFHUD_SPOT] = {
	{"first lag spot", {1139.928, -3432.958, 0.0}, 132.8},
	{"hilltop", {986.517, -3493.434, 0.0}, 256.9},
	{"Talmberg market", {1007.0, -3395.0, 0.0}, 180.0},
	{"monastery door", {707.0, -3603.0, 0.0}, 270.0},
	{"swamp edge", {1320.0, -3295.0, 0.0}, 0.0},
	{"church green", {1008.0, -3140.0, 0.0}, 0.0}
};

static bool:s_PerfhudChecking[MAX_PLAYERS];
static s_PerfhudCheckHour[MAX_PLAYERS];
static s_PerfhudCheckWeather[MAX_PLAYERS];

stock bool:Perfhud_IsChecking(playerid)
{
	return playerid >= 0 && playerid < MAX_PLAYERS && s_PerfhudChecking[playerid];
}

static Float:Perfhud_GroundAt(Float:x,Float:y)
{
	new Float:hitX, Float:hitY, Float:hitZ;

	if (CA_RayCastLine(x,y,600.0,x,y,-50.0,hitX,hitY,hitZ) != 0)
	{
		return hitZ;
	}

	return 0.0;
}

#pragma warning push
#pragma warning disable 204
static async Task:Perfhud_RunCheck(playerid)
{
	new line[144];

	for (new spot = 0;spot < sizeof(s_PerfhudSpots);spot++)
	{
		new Float:x = s_PerfhudSpots[spot][E_PERFHUD_SPOT_POS][0], Float:y = s_PerfhudSpots[spot][E_PERFHUD_SPOT_POS][1];
		new Float:z = Perfhud_GroundAt(x,y) + 1.0;
		Util_SafeTeleport(playerid,x,y,z,s_PerfhudSpots[spot][E_PERFHUD_SPOT_ANGLE],0,0);
		SetCameraBehindPlayer(playerid);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("FPS check: %s (%.1f, %.1f, %.1f). It turns you round by itself.",s_PerfhudSpots[spot][E_PERFHUD_SPOT_NAME],x,y,z));
		wait_ms(PERFHUD_CHECK_SETTLE_MS);

		if (!IsPlayerConnected(playerid) || !s_PerfhudChecking[playerid])
		{
			return async false;
		}

		new low = 9999, high = 0, total = 0, count = 0;
		TogglePlayerControllable(playerid,false);

		for (new heading = 0;heading < PERFHUD_CHECK_HEADINGS;heading++)
		{
			new Float:angle = float(heading) * (360.0 / float(PERFHUD_CHECK_HEADINGS));
			SetPlayerFacingAngle(playerid,angle);
			SetCameraBehindPlayer(playerid);
			SetPlayerTime(playerid,s_PerfhudCheckHour[playerid],0);
			SetPlayerWeather(playerid,s_PerfhudCheckWeather[playerid]);
			wait_ms(PERFHUD_CHECK_TURN_MS);
			Perfhud_ResetSamples(playerid);

			for (new second = 0;second < PERFHUD_CHECK_HEADING_SECONDS;second++)
			{
				SetPlayerTime(playerid,s_PerfhudCheckHour[playerid],0);
				SetPlayerWeather(playerid,s_PerfhudCheckWeather[playerid]);
				wait_ms(1000);

				if (!IsPlayerConnected(playerid) || !s_PerfhudChecking[playerid])
				{
					if (IsPlayerConnected(playerid))
					{
						TogglePlayerControllable(playerid,true);
					}

					return async false;
				}
			}

			new median = Perfhud_GetSamplePercentile(playerid,50), slow = Perfhud_GetSamplePercentile(playerid,10), samples = Perfhud_GetSampleCount(playerid);

			if (samples > 0)
			{
				low = median < low ? median : low;
				high = median > high ? median : high;
				total += median;
				count++;
			}

			new Float:px, Float:py, Float:pz;
			GetPlayerPos(playerid,px,py,pz);
			format(line,sizeof(line),"FPS check %s facing %.0f: median %d fps, slowest tenth %d, %d samples at %.1f, %.1f, %.1f",s_PerfhudSpots[spot][E_PERFHUD_SPOT_NAME],angle,median,slow,samples,px,py,pz);
			SendClientMessage(playerid,0xAAAAAAFF,line);
			Log_Info("fpscheck","%s",line);
		}

		TogglePlayerControllable(playerid,true);
		format(line,sizeof(line),"FPS check %s medians: worst %d, avg %d, best %d",s_PerfhudSpots[spot][E_PERFHUD_SPOT_NAME],count > 0 ? low : -1,count > 0 ? total / count : -1,count > 0 ? high : -1);
		SendClientMessage(playerid,0xFFFFFFFF,line);
		Log_Info("fpscheck","%s",line);
	}

	s_PerfhudChecking[playerid] = false;
	Calendar_ApplyPlayer(playerid);
	SendClientMessage(playerid,0xFFFFFFFF,"FPS check done.");
	Log_Info("fpscheck","done");
	return async true;
}
#pragma warning pop

CMD<ADMIN_LEVEL_MANAGER>:fpscheck(cmdid, playerid, params[])
{
	#pragma unused cmdid

	if (s_PerfhudChecking[playerid])
	{
		s_PerfhudChecking[playerid] = false;
		Calendar_ApplyPlayer(playerid);
		SendClientMessage(playerid,0xFFFFFFFF,"FPS check stopped.");
		return true;
	}

	s_PerfhudChecking[playerid] = true;
	s_PerfhudCheckHour[playerid] = params[0] != EOS ? strval(params) % 24 : 12;
	s_PerfhudCheckWeather[playerid] = 1;
	Log_Info("fpscheck","start: hour %d, weather %d",s_PerfhudCheckHour[playerid],s_PerfhudCheckWeather[playerid]);

	if (!Perfhud_IsEnabled(playerid))
	{
		Perfhud_SetEnabled(playerid,true);
	}

	Perfhud_RunCheck(playerid);
	return true;
}

#include <pp-hooks>

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason
	s_PerfhudChecking[playerid] = false;
}
