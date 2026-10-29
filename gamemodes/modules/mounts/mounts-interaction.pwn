#include <pp-hooks>

hook Infobox_OnInteracting(playerid)
{
    if (Mount_IsRiding(playerid))
    {
        Mount_Dismount(playerid);
    }
}

hook Anim_OnChanging(playerid,const library[],const name[])
{
    if (Mount_IsRiding(playerid) && (library[0] == EOS || name[0] == EOS || strcmp(library,"BIKED",true) || strcmp(name,"BIKEd_Ride",true)))
    {
        Mount_Dismount(playerid);
    }
}

hook Util_OnTeleporting(playerid,bool:keepMounted)
{
    if (!keepMounted && Mount_IsRiding(playerid))
    {
        Mount_Dismount(playerid);
    }
}
