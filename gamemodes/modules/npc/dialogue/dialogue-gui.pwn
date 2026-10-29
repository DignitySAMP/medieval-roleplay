#define DIALOGUE_PANEL_TITLE "Conversation"
#define DIALOGUE_PANEL_WIDTH (380.0)
#define DIALOGUE_PAGE_SIZE (3)
#define DIALOGUE_TOPIC_HEIGHT (32.0)
#define DIALOGUE_PICK_GOODBYE (1001)
#define DIALOGUE_PICK_GROUPS (1002)
#define DIALOGUE_PICK_PREVIOUS (1003)
#define DIALOGUE_PICK_NEXT (1004)
#define DIALOGUE_CAM_SLOTS (12)
#define DIALOGUE_CAM_HOUSE_PIECES (2)
#define DIALOGUE_CAM_DISTANCE (2.2)
#define DIALOGUE_CAM_GOOD_DISTANCE (1.5)
#define DIALOGUE_CAM_MIN_DISTANCE (1.0)
#define DIALOGUE_CAM_MARGIN (0.45)
#define DIALOGUE_CAM_SIDE (0.35)
#define DIALOGUE_CAM_SIDE_PROBE (0.35)
#define DIALOGUE_CAM_PLAYER_GAP (0.8)
#define DIALOGUE_CAM_TALKER_GAP (0.8)
#define DIALOGUE_CAM_TALL_SCALE (0.4)

static const s_DialogueGroupNames[DIALOGUE_GROUP_COUNT][16] = {
    "Greeting", "Work", "Family", "Village", "Their trade"
};

static bool:s_DialoguePanelActive[MAX_PLAYERS];
static bool:s_DialoguePanelPaused[MAX_PLAYERS];
static s_DialoguePanelGenerations[MAX_PLAYERS];
static s_DialoguePanelGroups[MAX_PLAYERS] = {-1, ...};
static s_DialoguePanelPages[MAX_PLAYERS];
static const Float:s_DialogueCameraTurns[DIALOGUE_CAM_SLOTS] = {0.0, 25.0, -25.0, 50.0, -50.0, 80.0, -80.0, 110.0, -110.0, 140.0, -140.0, 180.0};
static bool:s_DialogueCameraClassic;
static bool:s_DialogueCameraLoaded[HOUSE_SEED_COUNT][DIALOGUE_CAM_HOUSE_PIECES];
static bool:s_DialogueCameraSolid[HOUSE_SEED_COUNT][DIALOGUE_CAM_HOUSE_PIECES];
static bool:s_DialogueCameraSet[MAX_PLAYERS];
static Float:s_DialogueCameraSpot[MAX_PLAYERS][6];

stock bool:Dialogue_IsPanelOpen(playerid)
{
    if (!Util_IsValidPlayer(playerid))
    {
        return false;
    }

    new title[KIT_TITLE_LEN];
    Kit_GetTitle(playerid, title);
    return title[0] != EOS && !strcmp(title, DIALOGUE_PANEL_TITLE);
}

stock Dialogue_GetCamera(actor,&Float:x,&Float:y,&Float:z,&Float:lookX,&Float:lookY,&Float:lookZ)
{
    new Float:heading, library[24], animation[24], bool:loop;
    Actors_GetPos(actor,lookX,lookY,lookZ,heading);
    Actors_GetAnimation(actor,library,sizeof(library),animation,sizeof(animation),loop);
    new bool:isLow = strfind(animation,"sit",true) != -1 || strfind(animation,"kneel",true) != -1 || strfind(animation,"CRCH",true) != -1 || strfind(animation,"BOM_Plant",true) != -1;
    x = lookX - 2.2 * floatsin(heading,degrees) + 0.35 * floatcos(heading,degrees);
    y = lookY + 2.2 * floatcos(heading,degrees) + 0.35 * floatsin(heading,degrees);
    z = lookZ + (isLow ? 0.75 : 1.15);
    lookZ += isLow ? 0.55 : 0.95;
}

stock Dialogue_SetCameraClassic(bool:classic)
{
    s_DialogueCameraClassic = classic;
}

stock bool:Dialogue_IsCameraClassic()
{
    return s_DialogueCameraClassic;
}

stock Float:Dialogue_SegmentGap(Float:px,Float:py,Float:pz,Float:ax,Float:ay,Float:az,Float:bx,Float:by,Float:bz)
{
    new Float:dx = bx - ax, Float:dy = by - ay, Float:dz = bz - az, Float:length = dx * dx + dy * dy + dz * dz, Float:t = 0.0;

    if (length >= 0.0001)
    {
        t = Util_Clamp(((px - ax) * dx + (py - ay) * dy + (pz - az) * dz) / length,0.0,1.0);
    }

    new Float:gapX = px - (ax + dx * t), Float:gapY = py - (ay + dy * t), Float:gapZ = (pz - (az + dz * t)) * DIALOGUE_CAM_TALL_SCALE;
    return floatsqroot(gapX * gapX + gapY * gapY + gapZ * gapZ);
}

stock Dialogue_PickCameraSlot(const Float:usable[],const bool:crowdedByOther[],const bool:crowdedByTalker[],count = DIALOGUE_CAM_SLOTS)
{
    for (new pass = 0; pass < 4; pass++)
    {
        new best = -1;

        for (new i = 0; i < count; i++)
        {
            if (crowdedByOther[i] || usable[i] < DIALOGUE_CAM_MIN_DISTANCE || ((pass == 0 || pass == 2) && crowdedByTalker[i]))
            {
                continue;
            }

            if (pass < 2)
            {
                if (usable[i] >= DIALOGUE_CAM_GOOD_DISTANCE)
                {
                    return i;
                }

                continue;
            }

            if (best == -1 || usable[i] > usable[best] + 0.001)
            {
                best = i;
            }
        }

        if (best != -1)
        {
            return best;
        }
    }

    return -1;
}

static bool:Dialogue_CameraHit(Float:fromX,Float:fromY,Float:fromZ,Float:toX,Float:toY,Float:toZ,&Float:hitX,&Float:hitY,&Float:hitZ)
{
    new model = CA_RayCastLine(fromX,fromY,fromZ,toX,toY,toZ,hitX,hitY,hitZ);
    return model != 0 && model != WATER_OBJECT;
}

static Float:Dialogue_CameraReach(Float:lookX,Float:lookY,Float:lookZ,Float:heading,Float:turn,Float:camZ,&Float:x,&Float:y,&Float:z)
{
    new Float:angle = heading + turn, Float:sideX = DIALOGUE_CAM_SIDE * floatcos(angle,degrees), Float:sideY = DIALOGUE_CAM_SIDE * floatsin(angle,degrees);
    new Float:wantX = lookX - DIALOGUE_CAM_DISTANCE * floatsin(angle,degrees) + sideX, Float:wantY = lookY + DIALOGUE_CAM_DISTANCE * floatcos(angle,degrees) + sideY;
    new Float:hitX, Float:hitY, Float:hitZ, Float:usable = DIALOGUE_CAM_DISTANCE, Float:full = Util_GetDistance3D(lookX,lookY,lookZ,wantX,wantY,camZ);
    x = wantX;
    y = wantY;
    z = camZ;

    if (Dialogue_CameraHit(lookX,lookY,lookZ,wantX,wantY,camZ,hitX,hitY,hitZ))
    {
        new Float:scale = (Util_GetDistance3D(lookX,lookY,lookZ,hitX,hitY,hitZ) - DIALOGUE_CAM_MARGIN) / full;

        if (scale <= 0.0)
        {
            return 0.0;
        }

        usable = scale * DIALOGUE_CAM_DISTANCE;
        x = lookX + (wantX - lookX) * scale;
        y = lookY + (wantY - lookY) * scale;
        z = lookZ + (camZ - lookZ) * scale;
    }

    for (new probe = 0; probe < 4; probe++)
    {
        new Float:offsetX = (probe == 0 ? DIALOGUE_CAM_SIDE_PROBE : (probe == 1 ? -DIALOGUE_CAM_SIDE_PROBE : 0.0)), Float:offsetY = (probe == 2 ? DIALOGUE_CAM_SIDE_PROBE : (probe == 3 ? -DIALOGUE_CAM_SIDE_PROBE : 0.0));

        if (Dialogue_CameraHit(x,y,z,x + offsetX,y + offsetY,z,hitX,hitY,hitZ))
        {
            return 0.0;
        }
    }

    return usable;
}

static bool:Dialogue_CameraBlockedBy(subject,Float:camX,Float:camY,Float:camZ,Float:lookX,Float:lookY,Float:lookZ,Float:gap)
{
    if (!IsPlayerConnected(subject) || IsPlayerNPC(subject))
    {
        return false;
    }

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(subject,px,py,pz);
    return Dialogue_SegmentGap(px,py,pz,camX,camY,camZ,lookX,lookY,lookZ) < gap;
}

static bool:Dialogue_CameraCrowded(playerid,Float:camX,Float:camY,Float:camZ,Float:lookX,Float:lookY,Float:lookZ)
{
    foreach (new other : Player)
    {
        if (other == playerid || GetPlayerVirtualWorld(other) != GetPlayerVirtualWorld(playerid) || GetPlayerInterior(other) != GetPlayerInterior(playerid))
        {
            continue;
        }

        if (Dialogue_CameraBlockedBy(other,camX,camY,camZ,lookX,lookY,lookZ,DIALOGUE_CAM_PLAYER_GAP))
        {
            return true;
        }
    }

    return false;
}

static Dialogue_CameraRaiseHouse(playerid,objects[DIALOGUE_CAM_HOUSE_PIECES])
{
    new house = Houses_GetInside(playerid), Float:x, Float:y, Float:z;

    for (new piece = 0; piece < DIALOGUE_CAM_HOUSE_PIECES; piece++)
    {
        objects[piece] = -1;
    }

    if (house == -1)
    {
        return;
    }

    Houses_LocalToWorld(0.0,0.0,0.0,x,y,z);

    for (new piece = 0; piece < DIALOGUE_CAM_HOUSE_PIECES; piece++)
    {
        new model = g_HouseDefs[house][E_HOUSE_DEF_MODELS][piece];

        if (model != 0 && !s_DialogueCameraLoaded[house][piece])
        {
            static const names[DIALOGUE_CAM_HOUSE_PIECES][6] = {"shell", "dress"};
            new file[96];
            format(file,sizeof(file),"interiors/%s/%s_%s.dff",g_HouseDefs[house][E_HOUSE_DEF_KEY],g_HouseDefs[house][E_HOUSE_DEF_KEY],names[piece]);
            s_DialogueCameraLoaded[house][piece] = true;
            s_DialogueCameraSolid[house][piece] = CA_LoadFromDff(model,file) == 1;
        }

        if (model != 0 && s_DialogueCameraSolid[house][piece])
        {
            new index = CA_CreateObject(model,x,y,z,0.0,0.0,0.0,true);
            objects[piece] = index >= 0 && index != 0xFFFF ? index : -1;
        }
    }
}

static Dialogue_CameraDropHouse(const objects[DIALOGUE_CAM_HOUSE_PIECES])
{
    for (new piece = 0; piece < DIALOGUE_CAM_HOUSE_PIECES; piece++)
    {
        if (objects[piece] != -1)
        {
            CA_DestroyObject(objects[piece]);
        }
    }
}

stock bool:Dialogue_ChooseCamera(playerid,actor,&Float:x,&Float:y,&Float:z,&Float:lookX,&Float:lookY,&Float:lookZ,&slot = 0,&bool:frontClear = true)
{
    new Float:heading, Float:defaultX, Float:defaultY, Float:defaultZ;
    Dialogue_GetCamera(actor,defaultX,defaultY,defaultZ,lookX,lookY,lookZ);
    Actors_GetPos(actor,x,y,z,heading);
    slot = 0;
    frontClear = true;

    if (s_DialogueCameraClassic)
    {
        x = defaultX;
        y = defaultY;
        z = defaultZ;
        return true;
    }

    new Float:usable[DIALOGUE_CAM_SLOTS], bool:crowdedByOther[DIALOGUE_CAM_SLOTS], bool:crowdedByTalker[DIALOGUE_CAM_SLOTS], Float:spots[DIALOGUE_CAM_SLOTS][3];
    new houseObjects[DIALOGUE_CAM_HOUSE_PIECES];
    Dialogue_CameraRaiseHouse(playerid,houseObjects);

    for (new i = 0; i < DIALOGUE_CAM_SLOTS; i++)
    {
        usable[i] = Dialogue_CameraReach(lookX,lookY,lookZ,heading,s_DialogueCameraTurns[i],defaultZ,spots[i][0],spots[i][1],spots[i][2]);
        crowdedByOther[i] = Dialogue_CameraCrowded(playerid,spots[i][0],spots[i][1],spots[i][2],lookX,lookY,lookZ);
        crowdedByTalker[i] = Dialogue_CameraBlockedBy(playerid,spots[i][0],spots[i][1],spots[i][2],lookX,lookY,lookZ,DIALOGUE_CAM_TALKER_GAP);
    }

    Dialogue_CameraDropHouse(houseObjects);
    frontClear = usable[0] >= DIALOGUE_CAM_DISTANCE - 0.01;
    slot = Dialogue_PickCameraSlot(usable,crowdedByOther,crowdedByTalker);

    if (slot == -1)
    {
        return false;
    }

    x = spots[slot][0];
    y = spots[slot][1];
    z = spots[slot][2];
    return true;
}

static Dialogue_FrameActor(playerid,actor)
{
    new Float:x, Float:y, Float:z, Float:lookX, Float:lookY, Float:lookZ;

    if (!Dialogue_ChooseCamera(playerid,actor,x,y,z,lookX,lookY,lookZ))
    {
        s_DialogueCameraSet[playerid] = false;
        SetCameraBehindPlayer(playerid);
        return;
    }

    s_DialogueCameraSet[playerid] = true;
    s_DialogueCameraSpot[playerid][0] = x;
    s_DialogueCameraSpot[playerid][1] = y;
    s_DialogueCameraSpot[playerid][2] = z;
    s_DialogueCameraSpot[playerid][3] = lookX;
    s_DialogueCameraSpot[playerid][4] = lookY;
    s_DialogueCameraSpot[playerid][5] = lookZ;
    SetPlayerCameraPos(playerid,x,y,z);
    SetPlayerCameraLookAt(playerid,lookX,lookY,lookZ,CAMERA_CUT);
}

stock Dialogue_ReframeCamera(playerid)
{
    new actor = Dialogue_GetActor(playerid);

    if (actor == -1 || !s_DialoguePanelActive[playerid] || !Actors_IsPlaced(actor))
    {
        return;
    }

    if (s_DialogueCameraSet[playerid] && Dialogue_CameraCrowded(playerid,s_DialogueCameraSpot[playerid][0],s_DialogueCameraSpot[playerid][1],s_DialogueCameraSpot[playerid][2],s_DialogueCameraSpot[playerid][3],s_DialogueCameraSpot[playerid][4],s_DialogueCameraSpot[playerid][5]))
    {
        Dialogue_FrameActor(playerid,actor);
    }
}

stock Dialogue_CameraScan(playerid,Float:range = 80.0)
{
    new Float:px, Float:py, Float:pz, total = 0, blocked = 0, moved = 0, behind = 0, bad = 0;
    GetPlayerPos(playerid,px,py,pz);

    for (new actor = 0; actor < ACTORS_MAX; actor++)
    {
        new Float:ax, Float:ay, Float:az;

        if (!Actors_IsValid(actor) || !Actors_IsPlaced(actor) || Actors_GetWorld(actor) != GetPlayerVirtualWorld(playerid))
        {
            continue;
        }

        Actors_GetPos(actor,ax,ay,az);

        if (VectorSize(ax - px,ay - py,0.0) > range)
        {
            continue;
        }

        new Float:x, Float:y, Float:z, Float:lookX, Float:lookY, Float:lookZ, slot, bool:frontClear, key[ACTORS_KEY_LEN];
        Actors_GetKey(actor,key);
        total++;
        new bool:found = Dialogue_ChooseCamera(playerid,actor,x,y,z,lookX,lookY,lookZ,slot,frontClear);

        if (!frontClear)
        {
            blocked++;
        }

        if (!found)
        {
            behind++;
            printf("[dialogue-cam] %s at %.1f %.1f %.1f: no clear spot, the player's own camera is used",key,ax,ay,az);
            continue;
        }

        new Float:hitX, Float:hitY, Float:hitZ, houseObjects[DIALOGUE_CAM_HOUSE_PIECES];
        Dialogue_CameraRaiseHouse(playerid,houseObjects);
        new bool:behindWall = Dialogue_CameraHit(lookX,lookY,lookZ,x,y,z,hitX,hitY,hitZ);
        Dialogue_CameraDropHouse(houseObjects);

        if (behindWall)
        {
            bad++;
            printf("[dialogue-cam] %s at %.1f %.1f %.1f: the chosen spot is behind geometry",key,ax,ay,az);
        }
        else if (slot != 0)
        {
            moved++;
            printf("[dialogue-cam] %s at %.1f %.1f %.1f: front blocked, slot %d (%.0f degrees)",key,ax,ay,az,slot,s_DialogueCameraTurns[slot]);
        }
    }

    new text[144];
    format(text,sizeof(text),"Talk camera scan: %d actors, front blocked %d, other angle %d, own camera %d, still behind geometry %d.",total,blocked,moved,behind,bad);
    SendClientMessage(playerid,0xFFFFFFFF,text);
    printf("[dialogue-cam] %s",text);
}

static Dialogue_QueuePanel(playerid)
{
    SetTimerEx("Dialogue_PanelDeferred", 0, false, "dd", playerid, s_DialoguePanelGenerations[playerid]);
}

stock Dialogue_PausePanel(playerid,bool:paused)
{
    s_DialoguePanelPaused[playerid] = paused;
    s_DialoguePanelGenerations[playerid]++;

    if (!paused && s_DialoguePanelActive[playerid])
    {
        Dialogue_QueuePanel(playerid);
    }
}

static Dialogue_ShowPanel(playerid)
{
    new actor = Dialogue_GetActor(playerid), epoch = Gui_BeginFlow(playerid);

    while (s_DialoguePanelActive[playerid] && Dialogue_GetActor(playerid) == actor)
    {
        if (!Dialogue_CanChoose(playerid))
        {
            Dialogue_End(playerid);
            return;
        }

        new group = s_DialoguePanelGroups[playerid], page = s_DialoguePanelPages[playerid];
        new name[ACTORS_NAME_LEN], caption[64], Float:contentX, Float:contentY, Float:contentWidth;
        new count = group == -1 ? DIALOGUE_GROUP_COUNT : Dialogue_GetTopicCount(actor, group);
        new first = group == -1 ? 0 : page * DIALOGUE_PAGE_SIZE;
        new rows = group == -1 ? count : min(DIALOGUE_PAGE_SIZE, count - first);
        new Float:rowHeight = group == -1 ? KIT_ROW : DIALOGUE_TOPIC_HEIGHT;
        Actors_GetName(actor, name);
        Kit_Begin(playerid, KIT_LAYER_SCREEN, DIALOGUE_PANEL_TITLE);
        Kit_OpenPanel(playerid, KIT_ANCHOR_BOTTOM, DIALOGUE_PANEL_WIDTH, 14.0 + float(rows) * rowHeight + 20.0, name, contentX, contentY, contentWidth);

        if (group == -1)
        {
            strcopy(caption, "Choose something to talk about.");
        }
        else
        {
            format(caption, sizeof(caption), "%s - page %d of %d", s_DialogueGroupNames[group], page + 1, (count + DIALOGUE_PAGE_SIZE - 1) / DIALOGUE_PAGE_SIZE);
        }

        Kit_AddText(playerid, contentX, contentY, caption, KIT_COLOUR_MUTED, KIT_TEXT_ROW, TEXT_DRAW_FONT_1, false, contentWidth);
        contentY += 14.0;

        for (new row = 0; row < rows; row++)
        {
            new line[CHAT_LINE_MAX];

            if (group == -1)
            {
                strcopy(line, s_DialogueGroupNames[row]);
            }
            else
            {
                Dialogue_GetTopicLine(actor, group, first + row, line);
            }

            Kit_AddHit(playerid, contentX - 3.0, contentY + float(row) * rowHeight - 1.0, contentWidth + 6.0, rowHeight, first + row);
            Kit_AddText(playerid, contentX, contentY + float(row) * rowHeight, line, KIT_COLOUR_TEXT, KIT_TEXT_ROW, TEXT_DRAW_FONT_1, false, contentWidth);
        }

        contentY += float(rows) * rowHeight + 6.0;

        if (group != -1)
        {
            Kit_AddButton(playerid, contentX, contentY, 52.0, "Topics", DIALOGUE_PICK_GROUPS);

            if (page > 0)
            {
                Kit_AddButton(playerid, contentX + 58.0, contentY, 52.0, "Previous", DIALOGUE_PICK_PREVIOUS);
            }

            if (first + rows < count)
            {
                Kit_AddButton(playerid, contentX + 116.0, contentY, 52.0, "Next", DIALOGUE_PICK_NEXT);
            }
        }

        Kit_AddButton(playerid, contentX + contentWidth - 70.0, contentY, 70.0, "Goodbye", DIALOGUE_PICK_GOODBYE);
        new pick = await Kit_Present(playerid);

        if (!Gui_IsFlowCurrent(playerid, epoch) || !s_DialoguePanelActive[playerid] || Dialogue_GetActor(playerid) != actor)
        {
            return;
        }

        if (pick == KIT_BACK)
        {
            Dialogue_End(playerid);
            return;
        }

        if (pick == DIALOGUE_PICK_GOODBYE)
        {
            if (Dialogue_CanChoose(playerid) && Dialogue_IsReady(playerid))
            {
                Chat_Speak(playerid, CHAT_SAY, "Goodbye.");
                Actors_Say(actor, "God keep you.");
                Dialogue_End(playerid);
            }
            else
            {
                Dialogue_End(playerid);
            }

            return;
        }

        if (pick == DIALOGUE_PICK_GROUPS)
        {
            s_DialoguePanelGroups[playerid] = -1;
            s_DialoguePanelPages[playerid] = 0;
        }
        else if (pick == DIALOGUE_PICK_PREVIOUS && page > 0)
        {
            s_DialoguePanelPages[playerid]--;
        }
        else if (pick == DIALOGUE_PICK_NEXT && first + rows < count)
        {
            s_DialoguePanelPages[playerid]++;
        }
        else if (pick >= first && pick < first + rows)
        {
            if (group == -1)
            {
                s_DialoguePanelGroups[playerid] = pick;
                s_DialoguePanelPages[playerid] = 0;
            }
            else
            {
                Dialogue_ChooseTopic(playerid, group, pick);
            }
        }
    }
}

forward Dialogue_PanelDeferred(playerid, generation);

public Dialogue_PanelDeferred(playerid, generation)
{
    if (generation == s_DialoguePanelGenerations[playerid] && s_DialoguePanelActive[playerid] && !s_DialoguePanelPaused[playerid] && Dialogue_CanChoose(playerid) && !Gui_IsBusy(playerid))
    {
        Dialogue_ShowPanel(playerid);
    }

    return 1;
}

#include <pp-hooks>

hook Dialogue_OnStart(playerid, actor)
{
    Dialogue_FrameActor(playerid,actor);

    s_DialoguePanelGenerations[playerid]++;
    s_DialoguePanelActive[playerid] = true;
    s_DialoguePanelPaused[playerid] = false;
    s_DialoguePanelGroups[playerid] = -1;
    s_DialoguePanelPages[playerid] = 0;
    Dialogue_QueuePanel(playerid);
}

hook Dialogue_OnEnd(playerid, actor)
{
    #pragma unused actor

    s_DialoguePanelActive[playerid] = false;
    s_DialoguePanelPaused[playerid] = false;
    s_DialogueCameraSet[playerid] = false;
    s_DialoguePanelGenerations[playerid]++;

    if (Dialogue_IsPanelOpen(playerid))
    {
        Kit_Close(playerid);
    }

    if (Families_IsGuest(playerid))
    {
        Families_CameraWide(playerid);
    }
    else
    {
        SetCameraBehindPlayer(playerid);
    }
}

hook Kit_OnPicked(playerid,value)
{
    if (value != DIALOGUE_PICK_GOODBYE || !Dialogue_IsPanelOpen(playerid) || !Dialogue_IsTalking(playerid))
    {
        return;
    }

    new actor = Dialogue_GetActor(playerid);
    new bool:sayGoodbye = Dialogue_CanChoose(playerid) && Dialogue_IsReady(playerid);
    Actors_SetMenuTalking(playerid,-1);
    Dialogue_End(playerid);
    if (sayGoodbye)
    {
        Chat_Speak(playerid,CHAT_SAY,"Goodbye.");
        Actors_Say(actor,"God keep you.");
    }
}

hook Kit_OnVisibilityChanged(playerid, bool:isVisible)
{
    if (!isVisible && s_DialoguePanelActive[playerid] && !s_DialoguePanelPaused[playerid])
    {
        Dialogue_QueuePanel(playerid);
    }
}

hook OnPlayerConnect(playerid)
{
    s_DialoguePanelGenerations[playerid]++;
    s_DialoguePanelActive[playerid] = false;
    s_DialoguePanelPaused[playerid] = false;
    s_DialoguePanelGroups[playerid] = -1;
    s_DialoguePanelPages[playerid] = 0;
    s_DialogueCameraSet[playerid] = false;
}

hook Session_OnStateChanged(playerid, E_SESSION_STATE:from, E_SESSION_STATE:to)
{
    #pragma unused from

    if (to != SESSION_PLAYING)
    {
        s_DialoguePanelActive[playerid] = false;
        s_DialoguePanelPaused[playerid] = false;
        s_DialoguePanelGenerations[playerid]++;
        Dialogue_End(playerid, false);
    }
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason

    s_DialoguePanelActive[playerid] = false;
    s_DialoguePanelPaused[playerid] = false;
    s_DialoguePanelGenerations[playerid]++;
}
