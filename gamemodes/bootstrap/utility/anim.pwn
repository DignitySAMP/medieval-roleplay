forward Anim_OnChanging(playerid,const library[],const name[]);

public Anim_OnChanging(playerid,const library[],const name[])
{
    return 1;
}

stock bool:Anim_ApplySafe(playerid,const library[],const name[],Float:delta,bool:loop,bool:lockX,bool:lockY,bool:freeze,time,FORCE_SYNC:forceSync = SYNC_NONE)
{
    if (name[0] != EOS && strcmp(name,"null",true))
    {
        pawn_call_public("Anim_OnChanging","dss",playerid,library,name);
    }

    return ApplyAnimation(playerid,library,name,delta,loop,lockX,lockY,freeze,time,forceSync);
}

stock bool:Anim_Clear(playerid,FORCE_SYNC:forceSync = SYNC_NONE)
{
    pawn_call_public("Anim_OnChanging","dss",playerid,"","");
    return ClearAnimations(playerid,forceSync);
}

#define ApplyAnimation Anim_ApplySafe
#define ClearAnimations Anim_Clear

stock Anim_Apply(playerid,const lib[],const name[],Float:delta = 4.1,bool:loop = false,bool:lockx = false,bool:locky = false,bool:freeze = false,time = 0,FORCE_SYNC:forcesync = SYNC_ALL)
{
	ApplyAnimation(playerid,lib,name,delta,loop,lockx,locky,freeze,time,forcesync);
}

stock Anim_ClearToNull(playerid,const lib[])
{
	ApplyAnimation(playerid,lib,"null",0.0,false,false,false,false,0,SYNC_NONE);
}

stock Anim_CarryLift(playerid)
{
	ApplyAnimation(playerid,"BSKTBALL","bball_jump_cancel_o",4.1,false,false,false,true,1,SYNC_ALL);
}

stock Anim_CarryPutdown(playerid)
{
	ApplyAnimation(playerid,"BSKTBALL","bball_jump_cancel_o",4.1,false,false,false,true,1,SYNC_ALL);
}
