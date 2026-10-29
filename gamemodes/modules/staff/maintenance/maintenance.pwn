#define MAINTENANCE_MAX_MINUTES (60)
#define MAINTENANCE_REASON_LEN (96)
#define MAINTENANCE_KICK_SECONDS (3)
#define MAINTENANCE_EXIT_SECONDS (8)

static s_MaintenanceDeadline;
static s_MaintenanceLastLeft;
static s_MaintenanceStoppedAt;
static bool:s_MaintenanceKicked;
static s_MaintenanceReason[MAINTENANCE_REASON_LEN];

stock bool:Maintenance_IsPending()
{
    return s_MaintenanceDeadline != 0 || s_MaintenanceStoppedAt != 0;
}

stock bool:Maintenance_IsStopping()
{
    return s_MaintenanceStoppedAt != 0;
}

stock bool:Maintenance_ShouldRefuseJoin(playerid)
{
    return Maintenance_IsPending() && IsPlayerConnected(playerid) && !IsPlayerNPC(playerid);
}

stock Maintenance_GetSecondsLeft()
{
    if (s_MaintenanceDeadline == 0)
    {
        return 0;
    }

    return max(0,s_MaintenanceDeadline - gettime());
}

stock Maintenance_GetReason(dest[],size = sizeof(dest))
{
    strcopy(dest,s_MaintenanceReason,size);
}

stock bool:Maintenance_IsNoticeDue(seconds)
{
    switch (seconds)
    {
        case 600, 300, 180, 120, 60, 30, 10:
        {
            return true;
        }
    }

    return false;
}

static Maintenance_Broadcast(const text[])
{
    foreach (new playerid : Player)
    {
        if (!IsPlayerNPC(playerid))
        {
            SendClientMessage(playerid,STAFF_NOTE_COLOUR,text);
            Subtitle_Show(playerid,text);
        }
    }
}

static Maintenance_SaveAll()
{
    foreach (new playerid : Player)
    {
        if (!IsPlayerNPC(playerid))
        {
            pawn_call_public("Database_OnPlayerSave","dd",playerid,_:E_SAVE_REASON_SHUTDOWN);
        }
    }
}

stock Maintenance_Announce(seconds)
{
    new text[128];
    if (seconds >= 60 && seconds % 60 == 0)
    {
        format(text,sizeof(text),"The server restarts for maintenance in %d %s. Find a safe place to stop.",seconds / 60,seconds == 60 ? ("minute") : ("minutes"));
    }
    else
    {
        format(text,sizeof(text),"The server restarts for maintenance in %d seconds. Try again in a few minutes.",seconds);
    }

    Maintenance_SaveAll();
    Maintenance_Broadcast(text);
}

stock bool:Maintenance_Start(minutes,const reason[] = "")
{
    if (Maintenance_IsPending() || minutes < 1 || minutes > MAINTENANCE_MAX_MINUTES || strlen(reason) >= MAINTENANCE_REASON_LEN)
    {
        return false;
    }

    if (fexist("maintenance.done") && !fremove("maintenance.done"))
    {
        return false;
    }

    strcopy(s_MaintenanceReason,reason);
    for (new i = 0;s_MaintenanceReason[i] != EOS;i++)
    {
        if (s_MaintenanceReason[i] < ' ' || s_MaintenanceReason[i] > '~' || s_MaintenanceReason[i] == '~' || s_MaintenanceReason[i] == '{' || s_MaintenanceReason[i] == '}')
        {
            s_MaintenanceReason[i] = ' ';
        }
    }

    s_MaintenanceDeadline = gettime() + minutes * 60;
    s_MaintenanceLastLeft = minutes * 60;
    Maintenance_Announce(s_MaintenanceLastLeft);
    if (s_MaintenanceReason[0] != EOS)
    {
        foreach (new playerid : Player)
        {
            if (!IsPlayerNPC(playerid))
            {
                SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("Maintenance reason: %s",s_MaintenanceReason));
            }
        }
    }

    Log_Info("maintenance","countdown started for %d minutes: %s",minutes,s_MaintenanceReason);
    return true;
}

stock bool:Maintenance_Cancel()
{
    if (!Maintenance_IsPending() || Maintenance_IsStopping())
    {
        return false;
    }

    s_MaintenanceDeadline = 0;
    s_MaintenanceLastLeft = 0;
    s_MaintenanceReason[0] = EOS;
    Maintenance_Broadcast("The maintenance restart was cancelled. You can carry on playing.");
    Log_Emit(LOG_LEVEL_INFO,"maintenance","countdown cancelled");
    return true;
}

stock bool:Maintenance_Request(const request[])
{
    new length = strlen(request), offset;
    while (offset < length && request[offset] <= ' ')
    {
        offset++;
    }

    new start = offset;
    while (offset < length && request[offset] > ' ')
    {
        offset++;
    }

    new token[16];
    if (offset == start || offset - start >= sizeof(token))
    {
        return false;
    }

    strmid(token,request,start,offset,sizeof(token));
    while (offset < length && request[offset] <= ' ')
    {
        offset++;
    }

    if (!strcmp(token,"cancel",true))
    {
        return offset == length && Maintenance_Cancel();
    }

    if (strlen(token) > 2)
    {
        return false;
    }

    for (new i = 0;token[i] != EOS;i++)
    {
        if (token[i] < '0' || token[i] > '9')
        {
            return false;
        }
    }

    new reason[MAINTENANCE_REASON_LEN], end = length;
    while (end > offset && request[end - 1] <= ' ')
    {
        end--;
    }

    if (end - offset >= sizeof(reason))
    {
        return false;
    }

    strmid(reason,request,offset,end,sizeof(reason));
    return Maintenance_Start(strval(token),reason);
}

stock bool:Maintenance_PollRequest()
{
    if (!fexist("maintenance.request"))
    {
        return false;
    }

    new File:handle = fopen("maintenance.request",io_read);
    if (!handle)
    {
        return false;
    }

    new request[MAINTENANCE_REASON_LEN + 24], extra[2];
    new read = fread(handle,request), trailing = fread(handle,extra);
    fclose(handle);
    if (!fremove("maintenance.request"))
    {
        return false;
    }

    if (read == 0 || read >= sizeof(request) - 1 || trailing != 0 || !Maintenance_Request(request))
    {
        Log_Info("maintenance","request refused; use 1-%d minutes and an optional reason, or cancel",MAINTENANCE_MAX_MINUTES);
        return false;
    }

    return true;
}

forward Maintenance_KickJoin(playerid,token);

public Maintenance_KickJoin(playerid,token)
{

    if (Maintenance_ShouldRefuseJoin(playerid) && Account_GetToken(playerid) == token)
    {
        Kick(playerid);
    }

    return true;
}

forward Maintenance_Tick();

public Maintenance_Tick()
{
    Maintenance_PollRequest();
    if (!Maintenance_IsPending())
    {
        return true;
    }

    if (!Maintenance_IsStopping())
    {
        new left = Maintenance_GetSecondsLeft();
        if (left > 0)
        {
            new notice;
            for (new seconds = s_MaintenanceLastLeft - 1;seconds >= left;seconds--)
            {
                if (Maintenance_IsNoticeDue(seconds))
                {
                    notice = seconds;
                }
            }

            s_MaintenanceLastLeft = left;
            if (notice != 0)
            {
                Maintenance_Announce(left);
            }

            return true;
        }

        s_MaintenanceDeadline = 0;
        s_MaintenanceStoppedAt = gettime();
        foreach (new playerid : Player)
        {
            if (!IsPlayerNPC(playerid))
            {
                TogglePlayerControllable(playerid,false);
                if (s_MaintenanceReason[0] != EOS)
                {
                    SendClientMessage(playerid,STAFF_NOTE_COLOUR,sprintf("Maintenance reason: %s",s_MaintenanceReason));
                }
            }
        }

        Maintenance_SaveAll();
        Maintenance_Broadcast("The server is restarting for maintenance. Try again in a few minutes.");
        return true;
    }

    new elapsed = gettime() - s_MaintenanceStoppedAt;
    if (!s_MaintenanceKicked && elapsed >= MAINTENANCE_KICK_SECONDS)
    {
        s_MaintenanceKicked = true;
        foreach (new playerid : Player)
        {
            Kick(playerid);
        }
    }

    if (!s_MaintenanceKicked || elapsed < MAINTENANCE_EXIT_SECONDS || Iter_Count(Player) != 0)
    {
        return true;
    }

    if (g_Mysql != MYSQL_INVALID_HANDLE && mysql_unprocessed_queries(g_Mysql) != 0)
    {
        return true;
    }

    new File:handle = fopen("maintenance.done",io_write);
    if (!handle)
    {
        return true;
    }

    new written = fwrite(handle,"done\n");
    fclose(handle);
    if (written > 0)
    {
        SendRconCommand("exit");
    }

    return true;
}

CMD<ADMIN_LEVEL_MANAGER>:maintenance(cmdid, playerid, params[])
{
    if (!Maintenance_Request(params))
    {
        if (Maintenance_IsStopping())
        {
            Gui_Notify(playerid,"Maintenance is already stopping the server. Try again in a few minutes.");
        }
        else
        {
            Command_Usage(playerid,cmdid,"<minutes 1-60> [reason], or cancel (a running countdown must be cancelled first)");
        }
    }
    else
    {
        Staff_Log(playerid,"maintenance",params);
    }

    return true;
}

static Maintenance_RefuseJoin(playerid)
{

    if (Maintenance_ShouldRefuseJoin(playerid))
    {
        new token = Account_NewToken(playerid);
        SendClientMessage(playerid,STAFF_NOTE_COLOUR,"The server is restarting for maintenance. Try again in a few minutes.");
        Subtitle_Show(playerid,"The server is restarting for maintenance. Try again in a few minutes.");
        SetTimerEx("Maintenance_KickJoin",500,false,"dd",playerid,token);
    }
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
    Maintenance_RefuseJoin(playerid);
}
