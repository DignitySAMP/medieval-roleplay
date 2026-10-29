#define EVENTS_JOUST_SAMPLES (16)

enum E_JOUST_SAMPLE
{
    E_JOUST_TICK,
    Float:E_JOUST_X,
    Float:E_JOUST_Y,
    bool:E_JOUST_GALLOP,
    bool:E_JOUST_WALK,
    bool:E_JOUST_HELM,
    E_JOUST_LOWER
}

static s_JoustSamples[2][EVENTS_JOUST_SAMPLES][E_JOUST_SAMPLE];
static s_JoustCounts[2];
static s_JoustPlayers[2] = {INVALID_PLAYER_ID,INVALID_PLAYER_ID};
static s_JoustLowerTicks[2];
static bool:s_JoustHelms[2];
static bool:s_JoustFouls[2];
static s_JoustBoxes[2];
static s_JoustCourse;
static s_JoustSerial;
static s_JoustCommonTick;
static bool:s_JoustActive;
static bool:s_JoustJudged;
static s_JoustExitTicks[MAX_PLAYERS];
static s_SparringKnight = INVALID_PLAYER_ID;
static s_SparringKnightSeq;
static s_SparringOffer = INVALID_PLAYER_ID;
static s_SparringCharacter;

stock bool:Events_GetRiderCrossing(Float:beforeA,Float:beforeB,Float:afterA,Float:afterB,&Float:fraction)
{
    new Float:before = beforeB - beforeA, Float:after = afterB - afterA;
    if (before <= 0.0 || after > 0.0 || afterA <= beforeA || afterB >= beforeB)
    {
        return false;
    }
    fraction = before / (before - after);
    return true;
}

stock bool:Events_LerpJoustPosition(startTick,endTick,tick,Float:beforeX,Float:beforeY,Float:afterX,Float:afterY,&Float:positionX,&Float:positionY)
{
    if (endTick <= startTick || tick < startTick || tick > endTick)
    {
        return false;
    }
    new Float:fraction = float(tick - startTick) / float(endTick - startTick);
    positionX = beforeX + (afterX - beforeX) * fraction;
    positionY = beforeY + (afterY - beforeY) * fraction;
    return true;
}

stock Events_JoustPoints(E_LANCE_POSE:pose,bool:isGalloping,bool:isWalking,Float:laneError,bool:isHelm)
{
    return Events_JudgeQuintain(pose,isGalloping,isWalking,laneError,isHelm) > 0 ? (isHelm ? 2 : 1) : 0;
}

stock Float:Events_JoustStrike(E_LANCE_POSE:pose,bool:isGalloping,bool:isHelm,Float:luck)
{
    return (pose == E_LANCE_LOWERED ? 1.0 : 0.5) * (isGalloping ? 1.0 : 0.5) * (isHelm ? 1.3 : 1.0) + Util_Clamp(luck,-0.1,0.1);
}

stock Float:Events_JoustSeat(willpower,bondTier,bool:hasHit)
{
    return 0.6 + float(max(willpower,0)) * 0.05 + float(max(bondTier,0)) * 0.02 + (hasHit ? 0.1 : 0.0);
}

stock bool:Events_IsAtJoustGate(playerid,side,course)
{
    if (!Util_IsValidPlayer(playerid) || !IsPlayerConnected(playerid) || !Session_IsPlaying(playerid) || !Mount_IsRiding(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
    {
        return false;
    }
    new horseid = Mount_GetHorse(playerid);
    if (Horse_IsNoGallop(horseid) || !Mount_TypeCanGallop(Horse_GetType(horseid)) || (Mount_GetLance(playerid) == E_LANCE_NONE && IsPlayerAttachedObjectSlotUsed(playerid,ATTACH_SLOT_HAND)))
    {
        return false;
    }
    new direction = course % 2 == 0 ? 1 : -1;
    new Float:positionX, Float:positionY;
    Events_ListsToWorld(float(side == 0 ? -direction : direction) * 17.0,float(direction) * (side == 0 ? -EVENTS_JOUST_LANE : EVENTS_JOUST_LANE),positionX,positionY);
    return IsPlayerInRangeOfPoint(playerid,3.0,positionX,positionY,Events_ListsGroundAt(positionX,positionY) + MOUNT_RIDE_HEIGHT);
}

stock bool:Events_IsJouster(playerid)
{
    return s_JoustActive && (playerid == s_JoustPlayers[0] || playerid == s_JoustPlayers[1]);
}

stock Events_GetSparringKnight()
{
    return s_SparringKnight;
}

static Events_SetJoustPose(side,E_LANCE_POSE:pose)
{
    new playerid = s_JoustPlayers[side];
    if (playerid == s_SparringKnight)
    {
        new Float:offsets[3], Float:rotations[3], Float:scales[3];
        Mount_GetLanceFit(pose,s_JoustHelms[side],offsets,rotations,scales);
        SetPlayerAttachedObject(playerid,ATTACH_SLOT_HAND,pose == E_LANCE_BROKEN ? MODEL_TOURNEY_LANCE_STUB : MODEL_TOURNEY_LANCE,ATTACH_BONE_RIGHT_HAND,offsets[0],offsets[1],offsets[2],rotations[0],rotations[1],rotations[2],scales[0],scales[1],scales[2]);
    }
    else
    {
        Mount_SetLanceAim(playerid,s_JoustHelms[side]);
        Mount_SetLance(playerid,pose);
    }
}

stock Events_StopRiddenJoust(bool:keepLances = false)
{
    s_JoustActive = false;
    if (keepLances)
    {
        SetTimerEx("Events_JoustStandDown",EVENTS_STAND_DOWN_MS,false,"d",s_JoustSerial);
    }
    for (new side = 0;side < 2;side++)
    {
        new playerid = s_JoustPlayers[side];
        if (playerid == INVALID_PLAYER_ID)
        {
            continue;
        }
        if (s_JoustBoxes[side] > 0)
        {
            Infobox_Hide(playerid,s_JoustBoxes[side]);
            s_JoustBoxes[side] = 0;
        }
        if (playerid == s_SparringKnight)
        {
            Rider_Stop(playerid);
            if (!keepLances)
            {
                RemovePlayerAttachedObject(playerid,ATTACH_SLOT_HAND);
            }
        }
        else
        {
            Mount_ClearLane(playerid);
            if (!keepLances)
            {
                Mount_SetLance(playerid,E_LANCE_NONE);
            }
            Combat_SetTourney(playerid,false);
        }
        if (!keepLances)
        {
            s_JoustPlayers[side] = INVALID_PLAYER_ID;
        }
    }
}

stock Events_EndSparring()
{
    s_SparringOffer = INVALID_PLAYER_ID;
    s_SparringCharacter = 0;
    Events_StopRiddenJoust();
    if (s_SparringKnight != INVALID_PLAYER_ID)
    {
        NpcRiders_Destroy(s_SparringKnight);
        s_SparringKnight = INVALID_PLAYER_ID;
    }
}

static Events_SampleJouster(side)
{
    new playerid = s_JoustPlayers[side], now = GetTickCount();
    new sample[E_JOUST_SAMPLE], Float:positionX, Float:positionY, Float:positionZ;
    if (playerid == s_SparringKnight)
    {
        new Float:angle;
        Rider_GetPos(playerid,positionX,positionY,positionZ,angle);
        sample[E_JOUST_GALLOP] = true;
    }
    else
    {
        new KEY:keys, updown, leftright;
        GetPlayerPos(playerid,positionX,positionY,positionZ);
        GetPlayerKeys(playerid,keys,updown,leftright);
        sample[E_JOUST_GALLOP] = Mount_IsGalloping(playerid);
        sample[E_JOUST_WALK] = (keys & KEY_WALK) != KEY:0 || updown != KEY_UP;
    }
    Events_WorldToLists(positionX,positionY,sample[E_JOUST_X],sample[E_JOUST_Y]);
    sample[E_JOUST_TICK] = now;
    sample[E_JOUST_HELM] = s_JoustHelms[side];
    sample[E_JOUST_LOWER] = s_JoustLowerTicks[side];
    new count = s_JoustCounts[side];
    if (count == 0 && playerid != s_SparringKnight)
    {
        new direction = s_JoustCourse % 2 == 0 ? 1 : -1;
        new Float:start = float(side == 0 ? -direction : direction) * 17.0;
        if (floatabs(sample[E_JOUST_X] - start) > 2.0)
        {
            return;
        }
    }
    if (count > 0)
    {
        new previous = (count - 1) % EVENTS_JOUST_SAMPLES;
        new elapsed = now - s_JoustSamples[side][previous][E_JOUST_TICK];
        if (elapsed <= 0)
        {
            s_JoustSamples[side][previous][E_JOUST_LOWER] = sample[E_JOUST_LOWER];
            s_JoustSamples[side][previous][E_JOUST_HELM] = sample[E_JOUST_HELM];
            return;
        }
        for (new index = count - 2;index >= max(0,count - EVENTS_JOUST_SAMPLES);index--)
        {
            previous = index % EVENTS_JOUST_SAMPLES;
            elapsed = now - s_JoustSamples[side][previous][E_JOUST_TICK];
            if (elapsed >= 150)
            {
                break;
            }
        }
        new Float:speed = VectorSize(sample[E_JOUST_X] - s_JoustSamples[side][previous][E_JOUST_X],sample[E_JOUST_Y] - s_JoustSamples[side][previous][E_JOUST_Y],0.0) * 1000.0 / float(elapsed);
        new Float:limit = 10.8;
        if (playerid != s_SparringKnight)
        {
            new horseid = Mount_GetHorse(playerid);
            limit *= Mount_TypeSpeedFactor(Horse_GetType(horseid)) * Horse_GetSpeed(horseid) * Mount_GetSpeedScale(playerid);
        }
        if ((elapsed >= 150 && speed > limit) || floatabs(sample[E_JOUST_Y]) > EVENTS_JOUST_LANE + 3.0)
        {
            if (!s_JoustFouls[side])
            {
                Log_Warn("events","joust foul player %d speed %.2f lane %.2f",playerid,speed,sample[E_JOUST_Y]);
                if (playerid != s_SparringKnight)
                {
                    Gui_Notify(playerid,"Your course is a miss. Stay in your lane and ride at your horse's pace.");
                }
            }
            s_JoustFouls[side] = true;
        }
    }
    for (new i = 0;i < sizeof(sample);i++)
    {
        s_JoustSamples[side][count % EVENTS_JOUST_SAMPLES][i] = sample[i];
    }
    s_JoustCounts[side]++;
}

static bool:Events_ReadJoustSample(side,tick,dest[E_JOUST_SAMPLE])
{
    new count = s_JoustCounts[side];
    for (new index = max(0,count - EVENTS_JOUST_SAMPLES);index < count - 1;index++)
    {
        new before = index % EVENTS_JOUST_SAMPLES, after = (index + 1) % EVENTS_JOUST_SAMPLES;
        new start = s_JoustSamples[side][before][E_JOUST_TICK], finish = s_JoustSamples[side][after][E_JOUST_TICK];
        if (tick < start || tick > finish)
        {
            continue;
        }
        for (new i = 0;i < sizeof(dest);i++)
        {
            dest[i] = s_JoustSamples[side][tick == finish ? after : before][i];
        }
        if (!Events_LerpJoustPosition(start,finish,tick,s_JoustSamples[side][before][E_JOUST_X],s_JoustSamples[side][before][E_JOUST_Y],s_JoustSamples[side][after][E_JOUST_X],s_JoustSamples[side][after][E_JOUST_Y],dest[E_JOUST_X],dest[E_JOUST_Y]))
        {
            return false;
        }
        dest[E_JOUST_TICK] = tick;
        return true;
    }
    return false;
}

static Events_ShowJoustBox(side,E_LANCE_POSE:pose)
{
    new playerid = s_JoustPlayers[side];
    if (playerid == s_SparringKnight || Gui_IsBusy(playerid))
    {
        if (s_JoustBoxes[side] > 0)
        {
            Infobox_Hide(playerid,s_JoustBoxes[side]);
            s_JoustBoxes[side] = 0;
        }
        return;
    }
    new lanceName[16];
    switch (pose)
    {
        case E_LANCE_UPRIGHT: strcopy(lanceName,"up");
        case E_LANCE_LOWERING: strcopy(lanceName,"lowering");
        case E_LANCE_LOWERED: strcopy(lanceName,"steady");
        case E_LANCE_SAGGING: strcopy(lanceName,"sagging");
        default: strcopy(lanceName,"broken");
    }
    s_JoustBoxes[side] = Infobox_Show(playerid,"The joust",sprintf("Lance: ~y~%s~w~   Aim: ~y~%s~w~~n~Hold forward and gallop.~n~~y~Y~w~ lowers. ~y~H~w~ switches aim.~n~~y~F~w~ twice forfeits the bout.",lanceName,s_JoustHelms[side] ? ("helm") : ("shield")),4);
}

stock bool:Events_StartRiddenJoust(playerA,playerB,course)
{
    Events_StopRiddenJoust();
    s_JoustPlayers[0] = playerA;
    s_JoustPlayers[1] = playerB;
    s_JoustCourse = course;
    s_JoustSerial++;
    s_JoustJudged = false;
    s_JoustCommonTick = GetTickCount();
    for (new side = 0;side < 2;side++)
    {
        new playerid = s_JoustPlayers[side];
        if (playerid == INVALID_PLAYER_ID || (playerid != s_SparringKnight && !Mount_IsRiding(playerid)))
        {
            Events_ResolveCourse(0,0,side);
            return false;
        }
        s_JoustCounts[side] = 0;
        s_JoustLowerTicks[side] = 0;
        s_JoustHelms[side] = false;
        s_JoustFouls[side] = false;
        s_JoustExitTicks[playerid] = 0;
        new direction = course % 2 == 0 ? 1 : -1;
        new Float:frameX = float(side == 0 ? -direction : direction) * 17.0;
        new Float:laneY = float(direction) * (side == 0 ? -EVENTS_JOUST_LANE : EVENTS_JOUST_LANE);
        new Float:startX, Float:startY, Float:endX, Float:endY;
        Events_ListsToWorld(frameX,laneY,startX,startY);
        Events_ListsToWorld(-frameX,laneY,endX,endY);
        if (playerid == s_SparringKnight)
        {
            NpcRiders_Destroy(s_SparringKnight);
            new skins = Skins_CountStarter(0);
            s_SparringKnight = NpcRiders_Create(sprintf("Sparring_Knight_%d",++s_SparringKnightSeq % 100),skins > 0 ? Skins_GetStarter(0,0) : 1,0,startX,startY,Events_ListsGroundAt(startX,startY),Util_GetAngleToPoint(startX,startY,endX,endY));
            s_JoustPlayers[side] = s_SparringKnight;
            playerid = s_SparringKnight;
            if (playerid == INVALID_PLAYER_ID)
            {
                Events_ResolveCourse(0,0,1);
                return false;
            }
            new Float:points[6];
            points[0] = startX;
            points[1] = startY;
            points[2] = Events_ListsGroundAt(startX,startY);
            points[3] = endX;
            points[4] = endY;
            points[5] = Events_ListsGroundAt(endX,endY);
            Actors_Unregister(Actors_FindByKey(sprintf("rider:%d",playerid)));
            Actors_RegisterRider(sprintf("rider:%d",playerid),playerid,"Sparring knight","Joust practice");
            NpcRiders_RideRoute(playerid,points,2,MOUNT_GAIT_GALLOP);
        }
        else
        {
            Events_StopPractice(playerid);
            if (course == 0)
            {
                Util_SafeTeleport(playerid,startX,startY,Events_ListsGroundAt(startX,startY) + MOUNT_RIDE_HEIGHT,Util_GetAngleToPoint(startX,startY,endX,endY),0,0,true);
            }
            Mount_SetLane(playerid,startX,startY,endX,endY);
            Combat_SetTourney(playerid,true);
            if (course == 0)
            {
                Gui_Notify(playerid,"Ride on and gallop. Press ~y~Y~w~ to lower your lance about 15 m apart. ~y~H~w~ switches shield or helm aim.");
            }
        }
        Events_SetJoustPose(side,E_LANCE_UPRIGHT);
        if (playerid == s_SparringKnight)
        {
            Events_SampleJouster(side);
        }
        Events_ShowJoustBox(side,E_LANCE_UPRIGHT);
    }
    s_JoustActive = true;
    Events_Say(sprintf("Course %d of %d. Lower your lances!",course + 1,course < 3 ? 3 : 5));
    return true;
}

static Events_JudgeRiddenCrossing(tick)
{
    new samples[2][E_JOUST_SAMPLE], points[2], E_LANCE_POSE:poses[2], Float:strikes[2], bool:falls[2];
    for (new side = 0;side < 2;side++)
    {
        if (!Events_ReadJoustSample(side,tick,samples[side]))
        {
            return;
        }
        poses[side] = Events_GetLanceState(samples[side][E_JOUST_LOWER] != 0,tick - samples[side][E_JOUST_LOWER]);
        new Float:laneError = samples[side][E_JOUST_Y] + (s_JoustCourse % 2 == 0 ? 1.0 : -1.0) * (side == 0 ? EVENTS_JOUST_LANE : -EVENTS_JOUST_LANE);
        points[side] = s_JoustFouls[side] ? 0 : Events_JoustPoints(poses[side],samples[side][E_JOUST_GALLOP],samples[side][E_JOUST_WALK],laneError,samples[side][E_JOUST_HELM]);
        strikes[side] = points[side] > 0 ? Events_JoustStrike(poses[side],samples[side][E_JOUST_GALLOP],samples[side][E_JOUST_HELM],float(random(21) - 10) / 100.0) : 0.0;
    }
    s_JoustJudged = true;
    for (new side = 0;side < 2;side++)
    {
        new playerid = s_JoustPlayers[side], willpower = playerid == s_SparringKnight ? 5 : Character_GetAttribute(playerid,_:ATTR_WILLPOWER);
        new bond = playerid == s_SparringKnight ? 3 : Horses_GetTier(Mount_GetHorse(playerid));
        falls[side] = strikes[1 - side] > Events_JoustSeat(willpower,bond,points[side] > 0);
        if (points[side] > 0)
        {
            Events_SetJoustPose(side,E_LANCE_BROKEN);
            new name[MAX_PLAYER_NAME], opponent[MAX_PLAYER_NAME];
            if (playerid == s_SparringKnight)
            {
                strcopy(name,"The sparring knight");
            }
            else
            {
                Character_GetName(playerid,name);
            }
            if (s_JoustPlayers[1 - side] == s_SparringKnight)
            {
                strcopy(opponent,"the sparring knight");
            }
            else
            {
                Character_GetName(s_JoustPlayers[1 - side],opponent);
            }
            Events_Say(points[side] == 2 ? sprintf("A hit on the helm! 2 points to %s.",name) : sprintf("%s breaks a lance on %s's shield. 1 point.",name,opponent));
            pawn_call_public("Events_OnCourse","ddd",playerid,s_JoustPlayers[1 - side],points[side]);
            foreach (new viewer : Player)
            {
                if (!IsPlayerNPC(viewer) && GetPlayerVirtualWorld(viewer) == 0 && IsPlayerInRangeOfPoint(viewer,40.0,g_EventsLists[0],g_EventsLists[1],g_EventsLists[2]))
                {
                    PlayerPlaySound(viewer,1135,0.0,0.0,0.0);
                }
            }
        }
    }
    if (points[0] + points[1] == 0)
    {
        Events_Say("Both lances miss.");
    }
    for (new side = 0;side < 2;side++)
    {
        if (falls[side] && s_JoustPlayers[side] != s_SparringKnight)
        {
            Mount_Throw(s_JoustPlayers[side],"The lance throws you from the saddle. The bout is over.");
            new Float:angle = Events_ListsFrameAngle(), Float:push = side == 0 ? -0.08 : 0.08;
            SetPlayerVelocity(s_JoustPlayers[side],-floatsin(angle,degrees) * push,floatcos(angle,degrees) * push,0.03);
        }
    }
    Events_ResolveCourse(points[0],points[1],falls[0] && falls[1] ? 2 : (falls[0] ? 0 : (falls[1] ? 1 : -1)));
}

stock Events_WatchRiddenJoust(bool:isTime)
{
    if (!s_JoustActive)
    {
        return;
    }
    for (new side = 0;side < 2;side++)
    {
        new playerid = s_JoustPlayers[side];
        if (playerid != s_SparringKnight && (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid) || !Mount_IsRiding(playerid) || Vitals_GetHealth(playerid) <= 0.0 || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || !IsPlayerInRangeOfPoint(playerid,50.0,g_EventsLists[0],g_EventsLists[1],g_EventsLists[2])))
        {
            Events_ForfeitJoust(playerid);
            return;
        }
        if (playerid == s_SparringKnight)
        {
            new Float:positionX, Float:positionY, Float:positionZ, Float:angle, Float:frameX, Float:frameY;
            Rider_GetPos(playerid,positionX,positionY,positionZ,angle);
            Events_WorldToLists(positionX,positionY,frameX,frameY);
            if (s_JoustLowerTicks[side] == 0 && floatabs(frameX) < 7.0)
            {
                s_JoustLowerTicks[side] = GetTickCount();
            }
            Events_SampleJouster(side);
        }
        new E_LANCE_POSE:pose = Events_GetLanceState(s_JoustLowerTicks[side] != 0,GetTickCount() - s_JoustLowerTicks[side]);
        new bool:hasPoseChanged = playerid == s_SparringKnight || Mount_GetLance(playerid) != pose;
        if (hasPoseChanged)
        {
            Events_SetJoustPose(side,pose);
        }
        if (playerid != s_SparringKnight && (hasPoseChanged || s_JoustBoxes[side] <= 0 || !Infobox_IsShown(playerid,s_JoustBoxes[side]) || Gui_IsBusy(playerid)))
        {
            Events_ShowJoustBox(side,pose);
        }
    }
    if (s_JoustCounts[0] < 2 || s_JoustCounts[1] < 2)
    {
        if (isTime)
        {
            Events_ResolveCourse(0,0);
        }
        return;
    }
    new commonTick = min(s_JoustSamples[0][(s_JoustCounts[0] - 1) % EVENTS_JOUST_SAMPLES][E_JOUST_TICK],s_JoustSamples[1][(s_JoustCounts[1] - 1) % EVENTS_JOUST_SAMPLES][E_JOUST_TICK]);
    new before[2][E_JOUST_SAMPLE], after[2][E_JOUST_SAMPLE], bool:hasSamples = commonTick > s_JoustCommonTick;
    for (new side = 0;side < 2;side++)
    {
        if (!Events_ReadJoustSample(side,s_JoustCommonTick,before[side]) || !Events_ReadJoustSample(side,commonTick,after[side]))
        {
            hasSamples = false;
        }
    }
    new Float:fraction, Float:direction = s_JoustCourse % 2 == 0 ? 1.0 : -1.0;
    if (hasSamples && Events_GetRiderCrossing(before[0][E_JOUST_X] * direction,before[1][E_JOUST_X] * direction,after[0][E_JOUST_X] * direction,after[1][E_JOUST_X] * direction,fraction))
    {
        Events_JudgeRiddenCrossing(s_JoustCommonTick + floatround(float(commonTick - s_JoustCommonTick) * fraction));
        return;
    }
    s_JoustCommonTick = commonTick;
    if (isTime)
    {
        Events_Say("The course ran out of time. Both riders score no points.");
        Events_ResolveCourse(0,0);
    }
}

stock Events_OfferSparring(event,playerid)
{
    #pragma unused event
    s_SparringOffer = playerid;
    s_SparringCharacter = playerid == INVALID_PLAYER_ID ? 0 : Character_GetId(playerid);
    Events_Say("Only one rider entered. The herald offers a practice bout against the sparring knight. No prize is awarded.");
    if (playerid != INVALID_PLAYER_ID)
    {
        SetTimerEx("Events_SparringDeferred",0,false,"d",playerid);
    }
}

stock bool:Events_IsSparringOffered(playerid)
{
    return playerid != INVALID_PLAYER_ID && s_SparringOffer == playerid && IsPlayerConnected(playerid) && Character_GetId(playerid) == s_SparringCharacter && s_SparringKnight == INVALID_PLAYER_ID && Events_GetRunningContest() == CONTEST_JOUST && Events_GetRunPhase() == RUN_CALLING;
}

stock bool:Events_PrepareSparring(playerid)
{
    if (!Events_IsSparringOffered(playerid))
    {
        return false;
    }
    new Float:positionX, Float:positionY;
    Events_ListsToWorld(17.0,EVENTS_JOUST_LANE,positionX,positionY);
    new skins = Skins_CountStarter(0);
    s_SparringKnight = NpcRiders_Create(sprintf("Sparring_Knight_%d",++s_SparringKnightSeq % 100),skins > 0 ? Skins_GetStarter(0,0) : 1,0,positionX,positionY,Events_ListsGroundAt(positionX,positionY),0.0);
    if (s_SparringKnight == INVALID_PLAYER_ID)
    {
        Gui_Notify(playerid,"The sparring knight can't ride now. The practice bout has been called off.");
        Events_FinishSparring();
        return false;
    }
    Actors_Unregister(Actors_FindByKey(sprintf("rider:%d",s_SparringKnight)));
    Actors_RegisterRider(sprintf("rider:%d",s_SparringKnight),s_SparringKnight,"Sparring knight","Joust practice");
    Gui_Notify(playerid,"Bring your horse to the west gate within 60 seconds. The sparring bout gives no prize.");
    return true;
}

stock Events_WatchSparringOffer(bool:isTime)
{
    if (s_SparringKnight != INVALID_PLAYER_ID && IsPlayerConnected(s_SparringOffer) && Character_GetId(s_SparringOffer) == s_SparringCharacter && Mount_IsRiding(s_SparringOffer) && Session_IsPlaying(s_SparringOffer) && GetPlayerVirtualWorld(s_SparringOffer) == 0 && GetPlayerInterior(s_SparringOffer) == 0)
    {
        if (Events_IsAtJoustGate(s_SparringOffer,0,Events_GetCourse()))
        {
            Events_BeginSparringCourse();
            return;
        }
    }
    if (isTime || s_SparringOffer == INVALID_PLAYER_ID || !IsPlayerConnected(s_SparringOffer) || Character_GetId(s_SparringOffer) != s_SparringCharacter)
    {
        Events_Say("The sparring bout is called off. No prize is awarded.");
        Events_FinishSparring();
    }
}

forward Events_JoustStandDown(serial);
public Events_JoustStandDown(serial)
{
    if (!s_JoustActive && serial == s_JoustSerial)
    {
        Events_StopRiddenJoust();
    }
    return 1;
}

forward Events_OnCourse(winnerid,loserid,result);
public Events_OnCourse(winnerid,loserid,result)
{
    return 1;
}

forward bool:Events_JoustContext(playerid);
public bool:Events_JoustContext(playerid)
{
    return Events_IsJouster(playerid);
}

forward bool:Events_JoustDismount(playerid);
public bool:Events_JoustDismount(playerid)
{
    new entryA, entryB;
    Events_GetBout(entryA,entryB);
    new event = Events_GetRunningEvent();
    if (event == -1 || Events_GetRunningContest() != CONTEST_JOUST || (Events_GetRunPhase() != RUN_BOUT && Events_GetRunPhase() != RUN_GAP) || (Events_PlayerOf(event,CONTEST_JOUST,entryA) != playerid && Events_PlayerOf(event,CONTEST_JOUST,entryB) != playerid))
    {
        return true;
    }
    new now = GetTickCount();
    if (s_JoustExitTicks[playerid] != 0 && now - s_JoustExitTicks[playerid] <= 3000)
    {
        Events_ForfeitJoust(playerid);
        return true;
    }
    s_JoustExitTicks[playerid] = now;
    Gui_Notify(playerid,"Press ~y~F~w~ again within 3 seconds to dismount and forfeit the joust.");
    return false;
}

#include <pp-hooks>

hook OnPlayerUpdate(playerid)
{
    if (Events_IsJouster(playerid) && playerid != s_SparringKnight && !s_JoustJudged)
    {
        Events_SampleJouster(playerid == s_JoustPlayers[0] ? 0 : 1);
        Events_WatchRiddenJoust(false);
    }
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
    if (!Events_IsJouster(playerid) || s_JoustJudged || Gui_IsBusy(playerid))
    {
        return;
    }
    new side = playerid == s_JoustPlayers[0] ? 0 : 1;
    if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && s_JoustLowerTicks[side] == 0)
    {
        s_JoustLowerTicks[side] = GetTickCount();
    }
    if ((newkeys & KEY_CTRL_BACK) && !(oldkeys & KEY_CTRL_BACK))
    {
        s_JoustHelms[side] = !s_JoustHelms[side];
    }
    Events_SampleJouster(side);
    new E_LANCE_POSE:pose = Events_GetLanceState(s_JoustLowerTicks[side] != 0,GetTickCount() - s_JoustLowerTicks[side]);
    Events_SetJoustPose(side,pose);
    Events_ShowJoustBox(side,pose);
}

hook Mount_OnDismounted(playerid,horseid)
{
    #pragma unused horseid
    if (!s_JoustJudged)
    {
        Events_ForfeitJoust(playerid);
    }
}

hook OnPlayerDisconnect(playerid,reason)
{
    #pragma unused reason
    Events_ForfeitJoust(playerid);
    s_JoustExitTicks[playerid] = 0;
    for (new side = 0;side < 2;side++)
    {
        if (s_JoustPlayers[side] == playerid)
        {
            s_JoustPlayers[side] = INVALID_PLAYER_ID;
            s_JoustBoxes[side] = 0;
        }
    }
}
