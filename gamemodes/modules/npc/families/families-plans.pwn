#define FAMILY_CLOSE_RANGE (40.0)
#define FAMILY_CLOSE_EXTRA (6)
#define FAMILY_PERSONA_DEVOUT (1)
#define FAMILY_PERSONA_GOSSIP (2)
#define FAMILY_PERSONA_FORAGER (4)
#define FAMILY_PERSONA_HOMEBODY (8)
#define FAMILY_PERSONA_TRADER (16)
#define FAMILY_PERSONA_WORKER (32)

stock Families_PlanHash(seed,day,salt)
{
    new value = seed * 1103515245 + day * 1664525 + salt * 1013904223;
    return (value ^ (value >>> 16)) & 0x7fffffff;
}

stock Families_GetPersonality(member)
{
    if (member < 0 || member >= FAMILY_SEED_MEMBERS)
    {
        return FAMILY_PERSONA_HOMEBODY;
    }
    new role = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE];
    if (strfind(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_WHO],"widow",true) != -1)
    {
        return FAMILY_PERSONA_DEVOUT;
    }
    switch (E_ACTOR_ROLE:role)
    {
        case ACTOR_ROLE_FORESTER, ACTOR_ROLE_HEALER: return FAMILY_PERSONA_FORAGER;
        case ACTOR_ROLE_MERCHANT: return FAMILY_PERSONA_TRADER;
        case ACTOR_ROLE_FARMER, ACTOR_ROLE_HERDER, ACTOR_ROLE_LABOURER: return FAMILY_PERSONA_WORKER;
        case ACTOR_ROLE_CRAFT, ACTOR_ROLE_BAKER, ACTOR_ROLE_INNKEEPER, ACTOR_ROLE_MILLER, ACTOR_ROLE_SERVANT: return FAMILY_PERSONA_HOMEBODY;
    }
    if (g_FamilyDefs[Families_GetMemberFamily(member)][E_FAMILY_DEF_PIETY] >= 3)
    {
        return FAMILY_PERSONA_DEVOUT;
    }
    return 1 << (Families_PlanHash(member + 1,0,0) % 4);
}

stock bool:Families_IsPlanNode(node,bool:mushrooms)
{
    new species = Work_GetNodeHerb(node);
    if (species == -1 || Work_GetNodeStock(node) <= 0 || Work_GetNodeWorld(node) != 0 || Work_GetNodeInterior(node) != 0)
    {
        return false;
    }
    new item = Work_GetHerbItem(species);
    return mushrooms ? (item == ITEM_CEP || item == ITEM_FIELD_MUSHROOM) : Work_IsHerbRemedy(species);
}

stock Families_FindPlanNode(member,day,slot,bool:mushrooms)
{
    new family = Families_GetMemberFamily(member), Float:hx, Float:hy, Float:hz, Float:a;
    Families_DoorPos(member,hx,hy,hz,a);
    new best = -1, Float:score = 600.0;
    for (new node = 0; node < WORK_MAX_NODES; node++)
    {
        new Float:x, Float:y, Float:z;
        if (!Families_IsPlanNode(node,mushrooms) || !Work_GetNodePos(node,x,y,z))
        {
            continue;
        }
        new Float:distance = VectorSize(x - hx,y - hy,z - hz);
        if (distance > 500.0)
        {
            continue;
        }
        distance += float(Families_PlanHash(member + family + 1,day,node + slot) % 100);
        if (distance < score)
        {
            best = node;
            score = distance;
        }
    }
    return best;
}

stock bool:Families_HasTravelBudget(total,nearby,bool:close = false)
{
    return total < WALKERS_POOL && nearby < WALKERS_PER_PLAYER + (close ? FAMILY_CLOSE_EXTRA : 0);
}

stock bool:Families_ShouldTravel(bool:placed,bool:watched)
{
    return placed && watched;
}

forward bool:Families_FormatVoice(member,slot,dest[],size);
