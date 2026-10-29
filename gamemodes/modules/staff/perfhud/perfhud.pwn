#define PERFHUD_UPDATE_MS (2500)
#define PERFHUD_DRUNK_SEED (2000)
#define PERFHUD_X (634.0)
#define PERFHUD_Y (6.0)
#define PERFHUD_SAMPLE_MAX (32)

static bool:s_PerfhudEnabled[MAX_PLAYERS];
static bool:s_PerfhudVisible[MAX_PLAYERS];
static s_PerfhudTimers[MAX_PLAYERS];
static s_PerfhudLastLevels[MAX_PLAYERS];
static s_PerfhudFrames[MAX_PLAYERS];
static PlayerText:s_PerfhudTexts[MAX_PLAYERS];
static s_PerfhudSamples[MAX_PLAYERS][PERFHUD_SAMPLE_MAX];
static s_PerfhudSampleCount[MAX_PLAYERS];

stock bool:Perfhud_IsEnabled(playerid)
{
    return Util_IsValidPlayer(playerid) && s_PerfhudEnabled[playerid];
}

stock bool:Perfhud_IsVisible(playerid)
{
    return Perfhud_IsEnabled(playerid) && s_PerfhudVisible[playerid];
}

stock Perfhud_GetFps(playerid)
{
    if (!Perfhud_IsEnabled(playerid))
    {
        return -1;
    }

    return s_PerfhudFrames[playerid];
}

stock Perfhud_Percentile(const values[],count,percent)
{
    if (count <= 0)
    {
        return -1;
    }

    new sorted[PERFHUD_SAMPLE_MAX], total = count < PERFHUD_SAMPLE_MAX ? count : PERFHUD_SAMPLE_MAX;

    for (new i = 0;i < total;i++)
    {
        new value = values[i], j = i;

        while (j > 0 && sorted[j - 1] > value)
        {
            sorted[j] = sorted[j - 1];
            j--;
        }

        sorted[j] = value;
    }

    return sorted[(total - 1) * percent / 100];
}

stock Perfhud_ResetSamples(playerid)
{
    if (Util_IsValidPlayer(playerid))
    {
        s_PerfhudSampleCount[playerid] = 0;
    }
}

stock Perfhud_GetSampleCount(playerid)
{
    return Util_IsValidPlayer(playerid) ? s_PerfhudSampleCount[playerid] : 0;
}

stock Perfhud_GetSamplePercentile(playerid,percent)
{
    if (!Util_IsValidPlayer(playerid))
    {
        return -1;
    }

    return Perfhud_Percentile(s_PerfhudSamples[playerid],s_PerfhudSampleCount[playerid],percent);
}

stock Perfhud_EstimateFps(previousLevel,currentLevel,previousFps)
{
    new frames = previousLevel - currentLevel;

    if (previousLevel > 0 && frames > 0 && frames < 1000)
    {
        return frames;
    }

    return previousFps;
}

static Perfhud_SetVisible(playerid,bool:isVisible)
{
    if (!s_PerfhudEnabled[playerid] || s_PerfhudVisible[playerid] == isVisible)
    {
        return;
    }

    s_PerfhudVisible[playerid] = isVisible;

    if (isVisible)
    {
        PlayerTextDrawShow(playerid,s_PerfhudTexts[playerid]);
    }
    else
    {
        PlayerTextDrawHide(playerid,s_PerfhudTexts[playerid]);
    }
}

stock bool:Perfhud_SetEnabled(playerid,bool:isEnabled)
{
    if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid))
    {
        return false;
    }

    if (s_PerfhudEnabled[playerid] == isEnabled)
    {
        return true;
    }

    if (isEnabled)
    {
        s_PerfhudTexts[playerid] = CreatePlayerTextDraw(playerid,PERFHUD_X,PERFHUD_Y,"FPS: ...  Ping: ...  Loss: ...");

        if (s_PerfhudTexts[playerid] == INVALID_PLAYER_TEXT_DRAW)
        {
            return false;
        }

        PlayerTextDrawLetterSize(playerid,s_PerfhudTexts[playerid],0.20,1.0);
        PlayerTextDrawAlignment(playerid,s_PerfhudTexts[playerid],TEXT_DRAW_ALIGN_RIGHT);
        PlayerTextDrawColour(playerid,s_PerfhudTexts[playerid],0xD8CCB2FF);
        PlayerTextDrawBackgroundColour(playerid,s_PerfhudTexts[playerid],0x000000FF);
        PlayerTextDrawSetShadow(playerid,s_PerfhudTexts[playerid],0);
        PlayerTextDrawSetOutline(playerid,s_PerfhudTexts[playerid],1);
        PlayerTextDrawFont(playerid,s_PerfhudTexts[playerid],TEXT_DRAW_FONT_1);
        PlayerTextDrawSetProportional(playerid,s_PerfhudTexts[playerid],true);
        s_PerfhudEnabled[playerid] = true;
        s_PerfhudLastLevels[playerid] = GetPlayerDrunkLevel(playerid);
        s_PerfhudFrames[playerid] = -1;
        s_PerfhudTimers[playerid] = SetTimerEx("Perfhud_Update",PERFHUD_UPDATE_MS,true,"d",playerid);
        Perfhud_Update(playerid);
    }
    else
    {
        Perfhud_SetVisible(playerid,false);
        KillTimer(s_PerfhudTimers[playerid]);
        PlayerTextDrawDestroy(playerid,s_PerfhudTexts[playerid]);
        s_PerfhudTexts[playerid] = INVALID_PLAYER_TEXT_DRAW;
        s_PerfhudTimers[playerid] = 0;
        s_PerfhudEnabled[playerid] = false;
        s_PerfhudLastLevels[playerid] = 0;
        s_PerfhudFrames[playerid] = -1;
    }

    return true;
}

forward Perfhud_Update(playerid);

public Perfhud_Update(playerid)
{
    if (!Perfhud_IsEnabled(playerid))
    {
        return true;
    }

    new text[96], frames[12];

    if (s_PerfhudFrames[playerid] < 0)
    {
        format(frames,sizeof(frames),"...");
    }
    else
    {
        format(frames,sizeof(frames),"%d",s_PerfhudFrames[playerid]);
    }

    format(text,sizeof(text),"FPS: %s  Ping: %d ms  Loss: %.1f%%",frames,GetPlayerPing(playerid),NetStats_PacketLossPercent(playerid));
    PlayerTextDrawSetString(playerid,s_PerfhudTexts[playerid],text);
    Perfhud_SetVisible(playerid,!Kit_IsOpen(playerid) && Kit_AreWorldLabelsShown(playerid));
    return true;
}

CMD<ADMIN_LEVEL_MANAGER>:fps(cmdid, playerid, params[])
{
    #pragma unused cmdid, params
    Perfhud_SetEnabled(playerid,!Perfhud_IsEnabled(playerid));
    return true;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
    s_PerfhudEnabled[playerid] = false;
    s_PerfhudVisible[playerid] = false;
    s_PerfhudTimers[playerid] = 0;
    s_PerfhudLastLevels[playerid] = 0;
    s_PerfhudFrames[playerid] = -1;
    s_PerfhudSampleCount[playerid] = 0;
    s_PerfhudTexts[playerid] = INVALID_PLAYER_TEXT_DRAW;
}

hook OnPlayerDisconnect(playerid,reason)
{
    if (s_PerfhudEnabled[playerid])
    {
        KillTimer(s_PerfhudTimers[playerid]);
        PlayerTextDrawDestroy(playerid,s_PerfhudTexts[playerid]);
    }

    s_PerfhudEnabled[playerid] = false;
    s_PerfhudVisible[playerid] = false;
    s_PerfhudTimers[playerid] = 0;
    s_PerfhudTexts[playerid] = INVALID_PLAYER_TEXT_DRAW;
}

hook OnPlayerUpdate(playerid)
{
    if (!Perfhud_IsEnabled(playerid))
    {
        return;
    }

    new level = GetPlayerDrunkLevel(playerid);

    if (level < 100)
    {
        SetPlayerDrunkLevel(playerid,PERFHUD_DRUNK_SEED);
        s_PerfhudLastLevels[playerid] = PERFHUD_DRUNK_SEED;
    }
    else if (level != s_PerfhudLastLevels[playerid])
    {
        new frames = s_PerfhudLastLevels[playerid] - level;
        s_PerfhudFrames[playerid] = Perfhud_EstimateFps(s_PerfhudLastLevels[playerid],level,s_PerfhudFrames[playerid]);
        s_PerfhudLastLevels[playerid] = level;

        if (frames > 0 && frames < 1000 && s_PerfhudSampleCount[playerid] < PERFHUD_SAMPLE_MAX)
        {
            s_PerfhudSamples[playerid][s_PerfhudSampleCount[playerid]++] = frames;
        }
    }

    Perfhud_SetVisible(playerid,!Kit_IsOpen(playerid) && Kit_AreWorldLabelsShown(playerid));
}

hook Kit_OnVisibilityChanged(playerid,bool:isVisible)
{
    Perfhud_SetVisible(playerid,!isVisible && Kit_AreWorldLabelsShown(playerid));
}
