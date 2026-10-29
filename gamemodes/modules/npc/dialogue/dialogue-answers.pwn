#define DIALOGUE_VOICE_ANY (-1)
#define DIALOGUE_VOICE_ERRANDS (100)
#define DIALOGUE_VOICE_SHUT (101)
#define DIALOGUE_NEAR_PACES (30.0)

enum E_DIALOGUE_ANSWER
{
    E_DIALOGUE_ANSWER_TOPIC,
    E_DIALOGUE_ANSWER_VOICE,
    E_DIALOGUE_ANSWER_ACTION,
    E_DIALOGUE_ANSWER_TEXT[128],
}

static const s_DialogueAnswers[][E_DIALOGUE_ANSWER] = {
    {DIALOGUE_TOPIC_HELLO, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "God give you good day."},
    {DIALOGUE_TOPIC_HELLO, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "And to you. What brings you here?"},
    {DIALOGUE_TOPIC_HELLO, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "Well met."},
    {DIALOGUE_TOPIC_HELLO, _:ACTOR_ROLE_CHILD, DIALOGUE_ACTION_NONE, "Hello! Have you come far?"},
    {DIALOGUE_TOPIC_HELLO, _:ACTOR_ROLE_GUARD, DIALOGUE_ACTION_NONE, "Good day. Keep the peace and we'll get along."},
    {DIALOGUE_TOPIC_HELLO, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Keep walking, unless you want trouble."},

    {DIALOGUE_TOPIC_THANKS, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "It's nothing."},
    {DIALOGUE_TOPIC_THANKS, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "Think nothing of it."},
    {DIALOGUE_TOPIC_THANKS, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "You're welcome."},
    {DIALOGUE_TOPIC_THANKS, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Don't thank me. Just go."},

    {DIALOGUE_TOPIC_WORK, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "I've nothing for you. The families in the village often need something fetched, so ask them."},
    {DIALOGUE_TOPIC_WORK, DIALOGUE_VOICE_ERRANDS, DIALOGUE_ACTION_NONE, "I post errands now and then. Press Y on me and look for Errands in the list."},
    {DIALOGUE_TOPIC_WORK, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Not the kind you'd want. Move along."},

    {DIALOGUE_TOPIC_MEAL, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "Not here. Ask a family before the meal bell. Some will feed you for a coin."},
    {DIALOGUE_TOPIC_MEAL, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Not with me. Go and find an inn."},

    {DIALOGUE_TOPIC_FAMILY, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "My family lives far from here. I don't see them often."},
    {DIALOGUE_TOPIC_FAMILY, _:ACTOR_ROLE_TRADER, DIALOGUE_ACTION_NONE, "My wife keeps the house while I'm out selling."},
    {DIALOGUE_TOPIC_FAMILY, _:ACTOR_ROLE_PRIEST, DIALOGUE_ACTION_NONE, "The Church is my family now. The parish is all the children I'll have."},
    {DIALOGUE_TOPIC_FAMILY, _:ACTOR_ROLE_GAOLER, DIALOGUE_ACTION_NONE, "My wife says I spend more time with the prisoners than with her."},
    {DIALOGUE_TOPIC_FAMILY, _:ACTOR_ROLE_GUARD, DIALOGUE_ACTION_NONE, "A wife and two little ones. I don't see enough of them on this duty."},
    {DIALOGUE_TOPIC_FAMILY, _:ACTOR_ROLE_COURIER, DIALOGUE_ACTION_NONE, "They're at home somewhere down the road. A courier is never home long."},
    {DIALOGUE_TOPIC_FAMILY, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "None of your business."},

    {DIALOGUE_TOPIC_NEWS, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "Nothing worth repeating. The crier in Talmberg calls out every new notice."},
    {DIALOGUE_TOPIC_NEWS, _:ACTOR_ROLE_PRIEST, DIALOGUE_ACTION_NONE, "Mass is said at the monastery church every day. Come and hear it."},
    {DIALOGUE_TOPIC_NEWS, _:ACTOR_ROLE_CRIER, DIALOGUE_ACTION_NONE, "I call out every new notice in Talmberg. Stay close and you'll hear the next one."},
    {DIALOGUE_TOPIC_NEWS, _:ACTOR_ROLE_GUARD, DIALOGUE_ACTION_NONE, "A few drunks and a few thieves. The wanted are on the roll at the gaol register."},
    {DIALOGUE_TOPIC_NEWS, _:ACTOR_ROLE_COURIER, DIALOGUE_ACTION_NONE, "I carry other people's news in sealed letters. I don't read them."},
    {DIALOGUE_TOPIC_NEWS, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "The news is you've got a purse and I don't."},

    {DIALOGUE_TOPIC_ROADS, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "Road wardens watch the main roads. Off them, bandits wait in the woods."},
    {DIALOGUE_TOPIC_ROADS, _:ACTOR_ROLE_TRADER, DIALOGUE_ACTION_NONE, "Safe enough on the main road. I've lost goods to bandits off it."},
    {DIALOGUE_TOPIC_ROADS, _:ACTOR_ROLE_GUARD, DIALOGUE_ACTION_NONE, "We ride the main roads. Stay on them and you'll be safe enough."},
    {DIALOGUE_TOPIC_ROADS, _:ACTOR_ROLE_COURIER, DIALOGUE_ACTION_NONE, "I ride them every day. Keep to the main road and you'll get there."},
    {DIALOGUE_TOPIC_ROADS, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Safe for me. Less so for you."},

    {DIALOGUE_TOPIC_THIEVES, DIALOGUE_VOICE_ANY, DIALOGUE_ACTION_NONE, "Whoever sees a theft can name the thief. The guards bind them, then it's the gaol, the pillory or a fine."},
    {DIALOGUE_TOPIC_THIEVES, _:ACTOR_ROLE_GAOLER, DIALOGUE_ACTION_NONE, "They end up in my cells under the guardhouse, hungry and cold."},
    {DIALOGUE_TOPIC_THIEVES, _:ACTOR_ROLE_GUARD, DIALOGUE_ACTION_NONE, "We bind them and take them to the gaol register. Then it's the gaol, the pillory, the stocks or a fine."},
    {DIALOGUE_TOPIC_THIEVES, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Only the ones who get caught are thieves."},
    {DIALOGUE_TOPIC_THIEVES, _:ACTOR_ROLE_BAILIFF, DIALOGUE_ACTION_NONE, "A theft someone saw goes on the roll of the wanted with a bounty. The fine is paid at the gaol register."},

    {DIALOGUE_TOPIC_GOODS, _:ACTOR_ROLE_TRADER, DIALOGUE_ACTION_TRADE, "Have a look at my goods."},
    {DIALOGUE_TOPIC_GOODS, DIALOGUE_VOICE_SHUT, DIALOGUE_ACTION_NONE, "My stall is shut for now. Come back when it's open."},
    {DIALOGUE_TOPIC_GOODS, _:ACTOR_ROLE_STABLEHAND, DIALOGUE_ACTION_NONE, "Horses, when the stable has some. Press Y on me to buy, stable or fetch one."},
    {DIALOGUE_TOPIC_GOODS, _:ACTOR_ROLE_COURIER, DIALOGUE_ACTION_NONE, "I don't sell goods. I carry letters. Press Y on me to send one."},
    {DIALOGUE_TOPIC_GOODS, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Nothing you'd want to be caught holding."},

    {DIALOGUE_TOPIC_PRICE, _:ACTOR_ROLE_TRADER, DIALOGUE_ACTION_TRADE, "Every price is on my list. Here, see what each thing costs."},
    {DIALOGUE_TOPIC_PRICE, DIALOGUE_VOICE_SHUT, DIALOGUE_ACTION_NONE, "I can't sell you anything while my stall is shut. Come back when it's open."},
    {DIALOGUE_TOPIC_PRICE, _:ACTOR_ROLE_STABLEHAND, DIALOGUE_ACTION_NONE, "It depends on the horse. Press Y on me and choose Buy a horse to see the prices."},
    {DIALOGUE_TOPIC_PRICE, _:ACTOR_ROLE_COURIER, DIALOGUE_ACTION_NONE, "Press Y on me. The price of a letter is on the Send a letter row."},

    {DIALOGUE_TOPIC_TRADE, _:ACTOR_ROLE_TRADER, DIALOGUE_ACTION_TRADE, "Let's see what you've got."},
    {DIALOGUE_TOPIC_TRADE, DIALOGUE_VOICE_SHUT, DIALOGUE_ACTION_NONE, "Not now, my stall is shut. Come back when it's open."},

    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_FARMER, DIALOGUE_ACTION_NONE, "Growing, slowly. Ask me again at harvest and I'll tell you if it was worth the sweat."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_HERDER, DIALOGUE_ACTION_NONE, "Fed and counted. I count them twice a day, because wolves don't knock."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_WIFE, DIALOGUE_ACTION_NONE, "We get by. There's always a mouth to feed and a floor to sweep."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_CHILD, DIALOGUE_ACTION_NONE, "Tag, and hiding in the hay. Mother says I'm getting too old for it."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_ELDER, DIALOGUE_ACTION_NONE, "Smaller, and the winters were longer. We knew every face on the road."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_CRAFT, DIALOGUE_ACTION_NONE, "It takes years to learn and a moment to spoil. I'm still learning."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_BAKER, DIALOGUE_ACTION_NONE, "Fresh this morning. The oven has me up long before the bell."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_INNKEEPER, DIALOGUE_ACTION_NONE, "Travellers talk when they drink. Most of it is lies, but the roads are busy."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_MERCHANT, DIALOGUE_ACTION_NONE, "Coin is tight. People haggle over every penny this year."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_FORESTER, DIALOGUE_ACTION_NONE, "Boar in the thickets and poachers after the count's deer. I watch for both."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_FISHER, DIALOGUE_ACTION_NONE, "Some days the river gives and some days it doesn't. Today it gave a little."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_CLERK, DIALOGUE_ACTION_NONE, "The count wants his share, same as every year. The rolls are full of names that still owe."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_HEALER, DIALOGUE_ACTION_NONE, "Coughs and fevers, as always. Keep warm and eat well and you'll stay out of my hands."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_MILLER, DIALOGUE_ACTION_NONE, "The stones turn and the grain comes through. Everyone grumbles about my share, as always."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_LABOURER, DIALOGUE_ACTION_NONE, "Long and hard. The pay barely covers bread, but it's honest work."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_SERVANT, DIALOGUE_ACTION_NONE, "Busy from dawn till dark. They're fair to me, mostly."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_VILLAGER, DIALOGUE_ACTION_NONE, "Quiet, mostly. We work, we eat and we go to mass."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_TRADER, DIALOGUE_ACTION_NONE, "Slow and risky. Bandits wait off the main roads, which is why I never leave them."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_PRIEST, DIALOGUE_ACTION_NONE, "The parish is well. A few sick to visit, and a wedding or two if God is kind."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_CRIER, DIALOGUE_ACTION_NONE, "Whatever the count and the reeve want known. I call it out the moment it's posted."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_GAOLER, DIALOGUE_ACTION_NONE, "Cold and hungry. Prisoners eat what their friends bring them, so make friends."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_GUARD, DIALOGUE_ACTION_NONE, "Quiet so far. Anyone who breaks the peace goes on the roll of the wanted."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_YARD_MASTER, DIALOGUE_ACTION_NONE, "Hard on the arms and harder on pride. Everyone starts with the training stick."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_STABLEHAND, DIALOGUE_ACTION_NONE, "Fed, watered and groomed. A horse that's kept well will carry you far."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_COURIER, DIALOGUE_ACTION_NONE, "Sealed letters, and I don't open them. What's in them stays between sender and reader."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_BANDIT, DIALOGUE_ACTION_NONE, "Nobody comes asking for taxes out here. Now move along."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_REEVE, DIALOGUE_ACTION_NONE, "The count rules the county and I see that his word is kept here. The decrees say the rest."},
    {DIALOGUE_TOPIC_ROLE, _:ACTOR_ROLE_BAILIFF, DIALOGUE_ACTION_NONE, "The count's court sits when it must. Fines get paid and the guilty go to the gaol or the pillory."}
};

static const s_DialogueWeatherAnswers[4][96] = {
    "Dry today, thank God. Good weather for working outside.",
    "Rain again. The roads will be mud by Vespers.",
    "Thick fog today. Keep to the road or you'll lose your way in it.",
    "Snow. Stay near a fire when you can. The cold gets into you fast."
};

static Dialogue_AnswerVoice(actor, topic)
{
    new E_ACTOR_ROLE:role = Actors_GetRole(actor);

    if (topic == DIALOGUE_TOPIC_WORK || topic == DIALOGUE_TOPIC_ERRAND)
    {
        if (role == ACTOR_ROLE_INNKEEPER || role == ACTOR_ROLE_PRIEST || role == ACTOR_ROLE_YARD_MASTER || role == ACTOR_ROLE_REEVE || role == ACTOR_ROLE_BAILIFF || role == ACTOR_ROLE_HERDER)
        {
            return DIALOGUE_VOICE_ERRANDS;
        }
    }
    else if ((topic == DIALOGUE_TOPIC_GOODS || topic == DIALOGUE_TOPIC_PRICE || topic == DIALOGUE_TOPIC_TRADE) && role == ACTOR_ROLE_TRADER)
    {
        if (!Trader_IsValid(Actors_GetOwner(actor)) || !Trader_IsOpen())
        {
            return DIALOGUE_VOICE_SHUT;
        }
    }

    return _:role;
}

static Dialogue_CountRows(topic, voice)
{
    new count = 0;

    for (new i = 0; i < sizeof(s_DialogueAnswers); i++)
    {
        if (s_DialogueAnswers[i][E_DIALOGUE_ANSWER_TOPIC] == topic && s_DialogueAnswers[i][E_DIALOGUE_ANSWER_VOICE] == voice)
        {
            count++;
        }
    }

    return count;
}

static Dialogue_FindRow(topic, voice, variant)
{
    for (new i = 0; i < sizeof(s_DialogueAnswers); i++)
    {
        if (s_DialogueAnswers[i][E_DIALOGUE_ANSWER_TOPIC] == topic && s_DialogueAnswers[i][E_DIALOGUE_ANSWER_VOICE] == voice && variant-- == 0)
        {
            return i;
        }
    }

    return -1;
}

static Dialogue_RowVoice(actor, topic)
{
    new voice = Dialogue_AnswerVoice(actor, topic);
    return Dialogue_CountRows(topic, voice) > 0 ? voice : DIALOGUE_VOICE_ANY;
}

static bool:Dialogue_OutdoorPos(actor, &Float:x, &Float:y)
{
    new Float:z;

    if (Actors_GetWorld(actor) == 0 && Actors_GetPos(actor, x, y, z))
    {
        return true;
    }

    new member = Families_GetMemberOfActor(actor);

    if (member == -1)
    {
        return false;
    }

    new house = Families_GetHouse(Families_GetMemberFamily(member));
    x = g_HouseDefs[house][E_HOUSE_DEF_DOOR][0];
    y = g_HouseDefs[house][E_HOUSE_DEF_DOOR][1];
    return true;
}

static Dialogue_Compass(Float:fromX, Float:fromY, Float:toX, Float:toY, dest[], size = sizeof(dest))
{
    static const names[8][12] = {"north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"};
    new Float:angle = atan2(toX - fromX, toY - fromY);

    if (angle < 0.0)
    {
        angle += 360.0;
    }

    strcopy(dest, names[floatround(angle / 45.0, floatround_round) % 8], size);
}

static Dialogue_FormatWay(Float:fromX, Float:fromY, Float:toX, Float:toY, const place[], const near[], dest[], size = sizeof(dest))
{
    new Float:distance = VectorSize(toX - fromX, toY - fromY, 0.0), name[48];
    strcopy(name, place);
    name[0] = toupper(name[0]);

    if (distance < DIALOGUE_NEAR_PACES)
    {
        format(dest, size, near, place);
        return;
    }

    new way[12];
    Dialogue_Compass(fromX, fromY, toX, toY, way);
    format(dest, size, "%s is %s of here, about %d paces.", name, way, (floatround(distance) + 5) / 10 * 10);
}

static Dialogue_FormatInn(actor, dest[], size = sizeof(dest))
{
    new Float:fromX, Float:fromY;

    if (!Dialogue_OutdoorPos(actor, fromX, fromY))
    {
        strcopy(dest, "I can't point the way from in here. Step outside and ask anyone on the street.", size);
        return;
    }

    new best = -1, Float:bestDistance = 99999.0;

    for (new member = 0; member < FAMILY_SEED_MEMBERS; member++)
    {
        new other = Families_GetMemberActor(member);

        if (other == -1 || Actors_GetRole(other) != ACTOR_ROLE_INNKEEPER)
        {
            continue;
        }

        new house = Families_GetHouse(Families_GetMemberFamily(member));
        new Float:distance = VectorSize(g_HouseDefs[house][E_HOUSE_DEF_DOOR][0] - fromX, g_HouseDefs[house][E_HOUSE_DEF_DOOR][1] - fromY, 0.0);

        if (distance < bestDistance)
        {
            bestDistance = distance;
            best = house;
        }
    }

    if (best == -1)
    {
        strcopy(dest, "I couldn't tell you. I don't go drinking.", size);
        return;
    }

    Dialogue_FormatWay(fromX, fromY, g_HouseDefs[best][E_HOUSE_DEF_DOOR][0], g_HouseDefs[best][E_HOUSE_DEF_DOOR][1], g_HouseDefs[best][E_HOUSE_DEF_NAME], "You're at it. This is %s.", dest, size);
}

static Dialogue_FormatChurch(actor, dest[], size = sizeof(dest))
{
    new Float:fromX, Float:fromY, Float:x, Float:y, Float:z, Float:a;

    if (!Dialogue_OutdoorPos(actor, fromX, fromY))
    {
        strcopy(dest, "I can't point the way from in here. Step outside and look for the monastery church.", size);
        return;
    }

    Faith_GetPriestSpot(0, x, y, z, a);
    Dialogue_FormatWay(fromX, fromY, x, y, "the monastery church", "You're in it. This is %s.", dest, size);
}

static Dialogue_FormatName(actor, dest[], size = sizeof(dest))
{
    if (Actors_GetRole(actor) == ACTOR_ROLE_BANDIT)
    {
        strcopy(dest, "Names are for friends. You're not one.", size);
        return;
    }

    new first[ACTORS_NAME_LEN], title[ACTORS_TITLE_LEN];
    Actors_GetFirstName(actor, first);
    Actors_GetTitle(actor, title);

    if (title[0] == EOS)
    {
        strcopy(title, g_ActorRoleNames[Actors_GetRole(actor)]);
    }

    title[0] = tolower(title[0]);
    format(dest, size, "I'm %s. The %s, if you're asking.", first, title);
}

static Dialogue_WeatherKind()
{
    new weather = Calendar_GetWeather();

    if (Weather_IsSnowing())
    {
        return 3;
    }

    if (weather == 8 || weather == 16)
    {
        return 1;
    }

    return weather == 9 ? 2 : 0;
}

static Dialogue_VoiceSlot(topic, variant)
{
    switch (topic)
    {
        case DIALOGUE_TOPIC_HELLO: return _:FAMILY_VOICE_HELLO;
        case DIALOGUE_TOPIC_THANKS: return _:FAMILY_VOICE_THANKS;
        case DIALOGUE_TOPIC_NAME: return _:FAMILY_VOICE_NAME;
        case DIALOGUE_TOPIC_FAMILY: return variant == 0 ? (_:FAMILY_VOICE_FAMILY1) : (_:FAMILY_VOICE_FAMILY2);
        case DIALOGUE_TOPIC_NEWS: return _:FAMILY_VOICE_NEWS;
        case DIALOGUE_TOPIC_WEATHER: return _:FAMILY_VOICE_DRY + Dialogue_WeatherKind();
        case DIALOGUE_TOPIC_ROADS: return _:FAMILY_VOICE_ROADS;
        case DIALOGUE_TOPIC_THIEVES: return _:FAMILY_VOICE_THIEVES;
        case DIALOGUE_TOPIC_ROLE: return _:FAMILY_VOICE_ROLE;
        case DIALOGUE_TOPIC_WORK, DIALOGUE_TOPIC_ERRAND: return _:FAMILY_VOICE_WORK;
        case DIALOGUE_TOPIC_MEAL: return _:FAMILY_VOICE_MEAL;
    }

    return -1;
}

forward Monks_GetFee(step);

static Dialogue_FillFee(text[], const token[], value, size = sizeof(text))
{
    new at = strfind(text, token);

    if (at == -1)
    {
        return;
    }

    new number[12];
    valstr(number, value);
    strdel(text, at, at + strlen(token));
    strins(text, number, at, size);
}

static Dialogue_FillFees(text[], size = sizeof(text))
{
    if (strfind(text, "{fee_") == -1)
    {
        return;
    }

    Dialogue_FillFee(text, "{fee_examine}", Monks_GetFee(0), size);
    Dialogue_FillFee(text, "{fee_bandage}", Monks_GetFee(1), size);
    Dialogue_FillFee(text, "{fee_clean}", Monks_GetFee(2), size);
    Dialogue_FillFee(text, "{fee_splint}", Monks_GetFee(3), size);
    Dialogue_FillFee(text, "{fee_remedy}", Monks_GetFee(4), size);
    Dialogue_FillFee(text, "{fee_lance}", Monks_GetFee(5), size);
    Dialogue_FillFee(text, "{fee_stitch}", Monks_GetFee(6), size);
    Dialogue_FillFee(text, "{fee_set}", Monks_GetFee(7), size);
}

static bool:Dialogue_Voice(owner, slot, dest[], size = sizeof(dest))
{
    if (!Families_FormatVoice(owner, slot, dest, size))
    {
        return false;
    }

    Dialogue_FillFees(dest, size);
    return true;
}

stock bool:Dialogue_TopicShown(actor, topic)
{
    if (topic != DIALOGUE_TOPIC_GOODS && topic != DIALOGUE_TOPIC_PRICE && topic != DIALOGUE_TOPIC_TRADE)
    {
        return true;
    }

    if (Families_GetVoiceOwner(actor) != -1)
    {
        return false;
    }

    return Dialogue_CountRows(topic, _:Actors_GetRole(actor)) > 0;
}

static bool:Dialogue_IsMemberTopic(member, topic)
{
    for (new choice = 0, count = Families_GetMemberTopicCount(member); choice < count; choice++)
    {
        if (Families_GetMemberTopic(member, choice) == topic)
        {
            return true;
        }
    }

    return false;
}

stock Dialogue_GetAnswerCount(actor, topic, extra)
{
    if (topic == DIALOGUE_TOPIC_ERRAND)
    {
        topic = DIALOGUE_TOPIC_WORK;
    }

    if (!Actors_IsValid(actor) || topic < 0 || topic >= DIALOGUE_TOPIC_COUNT)
    {
        return 0;
    }

    new member = Families_GetMemberOfActor(actor), owner = Families_GetVoiceOwner(actor);

    if (topic == DIALOGUE_TOPIC_TABLE)
    {
        return member != -1 && Dialogue_IsMemberTopic(member, extra) ? 1 : 0;
    }

    if (topic == DIALOGUE_TOPIC_TRADEROW)
    {
        return owner != -1 && Families_GetTradeRowMember(extra) == owner ? 1 : 0;
    }

    if (topic == DIALOGUE_TOPIC_WHERE)
    {
        return Dialogue_IsWhereTarget(actor, extra) ? 1 : 0;
    }

    if (topic == DIALOGUE_TOPIC_NAME || topic == DIALOGUE_TOPIC_WEATHER || topic == DIALOGUE_TOPIC_INN || topic == DIALOGUE_TOPIC_CHURCH)
    {
        return 1;
    }

    if (topic == DIALOGUE_TOPIC_PLAN)
    {
        return 1;
    }

    if (member != -1)
    {
        switch (topic)
        {
            case DIALOGUE_TOPIC_WORK, DIALOGUE_TOPIC_ERRAND, DIALOGUE_TOPIC_MEAL, DIALOGUE_TOPIC_NEWS: return 1;
            case DIALOGUE_TOPIC_FAMILY: return 2;
        }
    }

    if (owner != -1)
    {
        if (topic == DIALOGUE_TOPIC_FAMILY)
        {
            return Families_HasVoice(owner, _:FAMILY_VOICE_FAMILY1) && Families_HasVoice(owner, _:FAMILY_VOICE_FAMILY2) ? 2 : 0;
        }

        if (Families_HasVoice(owner, Dialogue_VoiceSlot(topic, 0)))
        {
            return 1;
        }
    }

    return Dialogue_CountRows(topic, Dialogue_RowVoice(actor, topic));
}

stock Dialogue_FormatAnswer(actor, topic, extra, dest[], size = sizeof(dest), variant = -1)
{
    if (topic == DIALOGUE_TOPIC_ERRAND)
    {
        topic = DIALOGUE_TOPIC_WORK;
    }

    dest[0] = EOS;
    new count = Dialogue_GetAnswerCount(actor, topic, extra);

    if (count == 0)
    {
        return -1;
    }

    if (variant < 0 || variant >= count)
    {
        variant = random(count);
    }

    new member = Families_GetMemberOfActor(actor), owner = Families_GetVoiceOwner(actor);

    switch (topic)
    {
        case DIALOGUE_TOPIC_TABLE:
        {
            Families_FormatTopicAnswer(extra, dest, size);
            return DIALOGUE_ACTION_NONE;
        }
        case DIALOGUE_TOPIC_TRADEROW:
        {
            Families_FormatTradeAnswer(extra, dest, size);
            Dialogue_FillFees(dest, size);
            return Families_GetTradeRowAction(extra);
        }
        case DIALOGUE_TOPIC_WHERE:
        {
            new where[128];
            Days_FormatWhere(extra, where);
            format(dest, size, "%s? %s", g_FamilyMemberDefs[extra][E_FAMILY_MEMBER_DEF_NAME], where);
            return DIALOGUE_ACTION_NONE;
        }
        case DIALOGUE_TOPIC_NAME:
        {
            if (owner == -1 || !Dialogue_Voice(owner, Dialogue_VoiceSlot(topic, variant), dest, size))
            {
                Dialogue_FormatName(actor, dest, size);
            }

            return DIALOGUE_ACTION_NONE;
        }
        case DIALOGUE_TOPIC_WEATHER:
        {
            if (owner == -1 || !Dialogue_Voice(owner, Dialogue_VoiceSlot(topic, variant), dest, size))
            {
                strcopy(dest, s_DialogueWeatherAnswers[Dialogue_WeatherKind()], size);
            }

            return DIALOGUE_ACTION_NONE;
        }
        case DIALOGUE_TOPIC_INN:
        {
            Dialogue_FormatInn(actor, dest, size);
            return DIALOGUE_ACTION_NONE;
        }
        case DIALOGUE_TOPIC_CHURCH:
        {
            Dialogue_FormatChurch(actor, dest, size);
            return DIALOGUE_ACTION_NONE;
        }
    }

    if (topic == DIALOGUE_TOPIC_PLAN)
    {
        if (member != -1)
        {
            Days_FormatPlanAnswer(member,dest,size);
        }
        else if (owner == -1 || !Dialogue_Voice(owner, _:FAMILY_VOICE_PLAN, dest, size))
        {
            strcopy(dest,"I'm seeing to my usual work.",size);
        }
        return DIALOGUE_ACTION_NONE;
    }

    if (member != -1)
    {
        switch (topic)
        {
            case DIALOGUE_TOPIC_WORK, DIALOGUE_TOPIC_ERRAND: return DIALOGUE_ACTION_WORK;
            case DIALOGUE_TOPIC_MEAL: return DIALOGUE_ACTION_MEAL;
            case DIALOGUE_TOPIC_FAMILY:
            {
                if (!Dialogue_Voice(member, Dialogue_VoiceSlot(topic, variant), dest, size))
                {
                    Families_FormatTalkAnswer(Families_GetMemberFamily(member), variant, dest, size);
                }

                return DIALOGUE_ACTION_NONE;
            }
            case DIALOGUE_TOPIC_NEWS:
            {
                if (!Dialogue_Voice(member, Dialogue_VoiceSlot(topic, variant), dest, size))
                {
                    Families_FormatTalkAnswer(Families_GetMemberFamily(member), 2, dest, size);
                }

                return DIALOGUE_ACTION_NONE;
            }
        }
    }

    if (owner != -1 && Dialogue_Voice(owner, Dialogue_VoiceSlot(topic, variant), dest, size))
    {
        return DIALOGUE_ACTION_NONE;
    }

    new row = Dialogue_FindRow(topic, Dialogue_RowVoice(actor, topic), variant);

    if (row == -1)
    {
        return -1;
    }

    strcopy(dest, s_DialogueAnswers[row][E_DIALOGUE_ANSWER_TEXT], size);
    return s_DialogueAnswers[row][E_DIALOGUE_ANSWER_ACTION];
}
