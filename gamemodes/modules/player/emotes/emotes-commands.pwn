CMD<ADMIN_LEVEL_NONE>:animations(cmdid, playerid, params[])
{
	#pragma unused cmdid, params
	Emotes_Open(playerid);
	return 1;
}

CMD<ADMIN_LEVEL_NONE>:anims(cmdid, playerid, params[])
{
	#pragma unused cmdid, params
	Emotes_Open(playerid);
	return 1;
}

stock bool:Emotes_RunCommand(playerid,const command[],variant = 0)
{
    if (!strcmp(command,"stopanim",true) || !strcmp(command,"sa",true))
    {
        return Emotes_StopAll(playerid);
    }

    if (!Emotes_CanOpen(playerid))
    {
        return false;
    }

    if (variant == 0)
    {
        for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
        {
            if (!strcmp(command,g_EmotePairDefs[kind][E_EP_COMMAND],true))
            {
                variant = g_EmotePairDefs[kind][E_EP_VARIANT];
                break;
            }
        }

        if (variant == 0 && (!strcmp(command,"jogging",true) || !strcmp(command,"jog",true)))
        {
            variant = Character_GetSex(playerid) == 0 ? 1 : 2;
        }

        if (variant == 0)
        {
            new emote = Emotes_GetCommandEntry(command,0);

            if (Emotes_IsValid(emote))
            {
                variant = Emotes_GetVariant(emote);
            }
        }
    }

    new emote = Emotes_FindCommand(command,variant);

    if (emote != -1)
    {
        return Emotes_Play(playerid,emote);
    }

    for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
    {
        if (g_EmotePairDefs[kind][E_EP_VARIANT] == variant && !strcmp(command,g_EmotePairDefs[kind][E_EP_COMMAND],true))
        {
            new targetid = Emotes_FindFacingPlayer(playerid);

            if (targetid == INVALID_PLAYER_ID)
            {
                Gui_Notify(playerid,"Face the person you want to ask and stand close to them first.");
                return false;
            }

            return Emotes_Ask(playerid,targetid,kind);
        }
    }

    return false;
}

stock bool:Emotes_ParseVariant(const command[],const params[],&variant)
{
    new position = 0;
    variant = 0;

    while (params[position] == ' ')
    {
        position++;
    }

    if (params[position] == EOS)
    {
        return true;
    }

    if (params[position] < '0' || params[position] > '9')
    {
        return false;
    }

    while (params[position] >= '0' && params[position] <= '9')
    {
        variant = variant * 10 + params[position++] - '0';

        if (variant > Emotes_GetCommandMaximum(command))
        {
            return false;
        }
    }

    while (params[position] == ' ')
    {
        position++;
    }

    return params[position] == EOS && Emotes_HasVariant(command,variant);
}

static Emotes_HandleCommand(cmdid,playerid,const params[])
{
    new command[EMOTE_COMMAND_LEN], variant;
    GetCommandName(cmdid,command);

    if (!Emotes_CanAct(playerid))
    {
        Gui_Notify(playerid,"You can't use an emote right now. Close any open panel and finish what you're doing first.");
        return 1;
    }

    if (!Emotes_ParseVariant(command,params,variant))
    {
        return Command_Usage(playerid,cmdid,"[variant]");
    }

    Emotes_RunCommand(playerid,command,variant);
    return 1;
}

CMD<ADMIN_LEVEL_NONE>:sit(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:crosslegs(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:sitseat(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:sitback(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:squat(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:lie(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:lieside(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:sleep(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:lean(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:leanarms(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:leancounter(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:kneel(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:pray(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:headbow(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:cross(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:wave(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:beckon(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:point(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:shakehead(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:nod(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:cheer(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:clap(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:laugh(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:weep(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:mourn(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:scratch(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:fist(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:bow(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:curtsy(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:salute(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:kneellord(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:foldarms(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:hips(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:tired(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:sway(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:warmhands(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:yawn(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:chat(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:drink(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:sack(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:scrub(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:saw(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:dance(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:reel(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:jig(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:rounddance(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:clapalong(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:lute(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:flute(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:drum(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:handshake(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:hug(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:kiss(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:pairbow(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:pairdance(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:support(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:carryperson(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:private(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:angry(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:balcony(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:bar(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:barber(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:bat(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:batidle(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:camcrouch(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:carry(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:carryidle(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:clothes(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:cmon(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:cover(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:crossarms(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:cry(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:deal(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:drunk(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:eat(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:facepalm(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:fall(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:fight(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:flip(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:foodsit(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:fucku(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:gethit(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:getup(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:gkick(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:guardstance(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:handstand(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:handsup(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:hurt(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:injured(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:jog(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:jogging(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:jump(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:knife(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:knifehold(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:ko(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:lay(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:liftdown(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:liftup(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:look(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:office(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:playidle(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:puke(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:recruit(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:sa(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:siteat(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:sitfood(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:slapass(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:slide(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:stopanim(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:throw(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:walk(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:wash(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:aim(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:aimgun(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:bomb(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:bop(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:casino(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:copambient(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:cpr(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:danceextra(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:dancing(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:dazed(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:exhale(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:flagdrop(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:goggles(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:gunhold(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:hail(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:handsign(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:handtalk(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:patdown(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:pistolwhip(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:plunger(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:pointgun(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:press(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:reloadanim(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:riflehold(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:shakebottle(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:smoke(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:smokeidle(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:spray(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:stop(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:strip(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:swatraid(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:swipe(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:taichi(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}

CMD<ADMIN_LEVEL_NONE>:time(cmdid, playerid, params[])
{
    return Emotes_HandleCommand(cmdid,playerid,params);
}
