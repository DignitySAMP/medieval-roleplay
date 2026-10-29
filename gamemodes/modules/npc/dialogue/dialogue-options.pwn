enum
{
    DIALOGUE_GROUP_GREETING,
    DIALOGUE_GROUP_WORK,
    DIALOGUE_GROUP_FAMILY,
    DIALOGUE_GROUP_VILLAGE,
    DIALOGUE_GROUP_ROLE,
    DIALOGUE_GROUP_COUNT,
}

enum E_DIALOGUE_TOPIC
{
    E_DIALOGUE_TOPIC_GROUP,
    E_DIALOGUE_TOPIC_ID,
    E_DIALOGUE_TOPIC_LINE[CHAT_LINE_MAX],
}

static const s_DialogueTopics[][E_DIALOGUE_TOPIC] = {
    {DIALOGUE_GROUP_GREETING, DIALOGUE_TOPIC_HELLO, "Good day to you."},
    {DIALOGUE_GROUP_GREETING, DIALOGUE_TOPIC_NAME, "Who are you?"},
    {DIALOGUE_GROUP_GREETING, DIALOGUE_TOPIC_THANKS, "Thank you."},
    {DIALOGUE_GROUP_WORK, DIALOGUE_TOPIC_WORK, "Do you have any work for me?"},
    {DIALOGUE_GROUP_WORK, DIALOGUE_TOPIC_PLAN, "What are you up to?"},
    {DIALOGUE_GROUP_FAMILY, DIALOGUE_TOPIC_MEAL, "Can I eat here?"},
    {DIALOGUE_GROUP_FAMILY, DIALOGUE_TOPIC_FAMILY, "Tell me about your family."},
    {DIALOGUE_GROUP_VILLAGE, DIALOGUE_TOPIC_NEWS, "Any news in the village?"},
    {DIALOGUE_GROUP_VILLAGE, DIALOGUE_TOPIC_WEATHER, "What do you think of the weather?"},
    {DIALOGUE_GROUP_VILLAGE, DIALOGUE_TOPIC_INN, "Where is the inn?"},
    {DIALOGUE_GROUP_VILLAGE, DIALOGUE_TOPIC_CHURCH, "Where is the church?"},
    {DIALOGUE_GROUP_VILLAGE, DIALOGUE_TOPIC_ROADS, "Are the roads safe?"},
    {DIALOGUE_GROUP_VILLAGE, DIALOGUE_TOPIC_THIEVES, "What happens to thieves here?"},
    {DIALOGUE_GROUP_ROLE, DIALOGUE_TOPIC_GOODS, "What do you sell?"},
    {DIALOGUE_GROUP_ROLE, DIALOGUE_TOPIC_PRICE, "How much does it cost?"},
    {DIALOGUE_GROUP_ROLE, DIALOGUE_TOPIC_TRADE, "I'd like to trade with you."}
};

static const s_DialogueRoleTopics[ACTOR_ROLE_COUNT][96] = {
    "How are the crops this season?",
    "How are your animals?",
    "How is your household getting on?",
    "What games do you play?",
    "What was the village like when you were young?",
    "Tell me about your craft.",
    "How is the bread today?",
    "What news have you heard at the inn?",
    "How is business at the market?",
    "What is happening in the woods?",
    "How is the fishing?",
    "What's the talk about taxes?",
    "How are the sick in the village?",
    "How is the mill running?",
    "What is a day's labour like here?",
    "What is it like serving this household?",
    "How is life in the village?",
    "How is trading along the roads?",
    "What's happening in the parish?",
    "What news have you brought?",
    "What is life like in the gaol?",
    "How goes the watch?",
    "What is training in the yard like?",
    "How are the horses?",
    "What news do you carry on the roads?",
    "Why do you live out here?",
    "How is the village governed?",
    "Any word from the court?"
};

#define DIALOGUE_WHERE_MAX (6)

stock Dialogue_GetFamilyTopic(actor, choice)
{
    return Families_GetMemberTopic(Families_GetMemberOfActor(actor), choice);
}

forward bool:Dialogue_TopicShown(actor, topic);

stock bool:Dialogue_IsWhereTarget(actor, target)
{
    new targets[DIALOGUE_WHERE_MAX], count = Days_WhereTargets(Families_GetMemberOfActor(actor), targets);

    for (new i = 0; i < count; i++)
    {
        if (targets[i] == target)
        {
            return true;
        }
    }

    return false;
}

stock Dialogue_GetTopicCount(actor, group)
{
    if (!Actors_IsValid(actor) || group < 0 || group >= DIALOGUE_GROUP_COUNT)
    {
        return 0;
    }

    new count = 0;

    for (new i = 0; i < sizeof(s_DialogueTopics); i++)
    {
        if (s_DialogueTopics[i][E_DIALOGUE_TOPIC_GROUP] == group && Dialogue_TopicShown(actor, s_DialogueTopics[i][E_DIALOGUE_TOPIC_ID]))
        {
            count++;
        }
    }

    if (group == DIALOGUE_GROUP_FAMILY)
    {
        count += Families_GetMemberTopicCount(Families_GetMemberOfActor(actor));
    }
    else if (group == DIALOGUE_GROUP_ROLE)
    {
        count += 1 + Families_GetTradeRowCount(Families_GetVoiceOwner(actor));
    }
    else if (group == DIALOGUE_GROUP_VILLAGE)
    {
        new targets[DIALOGUE_WHERE_MAX];
        count += Days_WhereTargets(Families_GetMemberOfActor(actor), targets);
    }

    return count;
}

stock Dialogue_GetTopicId(actor, group, choice, &extra = -1)
{
    extra = -1;

    if (choice < 0 || choice >= Dialogue_GetTopicCount(actor, group))
    {
        return -1;
    }

    for (new i = 0; i < sizeof(s_DialogueTopics); i++)
    {
        if (s_DialogueTopics[i][E_DIALOGUE_TOPIC_GROUP] == group && Dialogue_TopicShown(actor, s_DialogueTopics[i][E_DIALOGUE_TOPIC_ID]) && choice-- == 0)
        {
            return s_DialogueTopics[i][E_DIALOGUE_TOPIC_ID];
        }
    }

    if (group == DIALOGUE_GROUP_ROLE)
    {
        if (choice == 0)
        {
            return DIALOGUE_TOPIC_ROLE;
        }

        extra = Families_GetMemberTradeRow(Families_GetVoiceOwner(actor), choice - 1);
        return extra == -1 ? -1 : DIALOGUE_TOPIC_TRADEROW;
    }

    if (group == DIALOGUE_GROUP_VILLAGE)
    {
        new targets[DIALOGUE_WHERE_MAX];

        if (choice >= Days_WhereTargets(Families_GetMemberOfActor(actor), targets))
        {
            return -1;
        }

        extra = targets[choice];
        return DIALOGUE_TOPIC_WHERE;
    }

    extra = Dialogue_GetFamilyTopic(actor, choice);
    return extra == -1 ? -1 : DIALOGUE_TOPIC_TABLE;
}

stock bool:Dialogue_FormatTopicLine(actor, topic, extra, destination[], size = sizeof(destination))
{
    destination[0] = EOS;

    if (!Actors_IsValid(actor))
    {
        return false;
    }

    if (topic == DIALOGUE_TOPIC_ROLE)
    {
        strcopy(destination, s_DialogueRoleTopics[Actors_GetRole(actor)], size);
        return true;
    }

    if (topic == DIALOGUE_TOPIC_TRADEROW)
    {
        return Families_GetTradeRowMember(extra) == Families_GetVoiceOwner(actor) && Families_FormatTradeQuestion(extra, destination, size);
    }

    if (topic == DIALOGUE_TOPIC_WHERE)
    {
        if (!Dialogue_IsWhereTarget(actor, extra))
        {
            return false;
        }

        new name[36];
        Days_GetTemplateName(extra, name);

        for (new i = 0; name[i] != EOS; i++)
        {
            name[i] = tolower(name[i]);
        }

        format(destination, size, "Where can I find the %s?", name);
        return true;
    }

    if (topic == DIALOGUE_TOPIC_TABLE)
    {
        new member = Families_GetMemberOfActor(actor);

        if (member == -1 || extra < 0 || extra >= FAMILY_SEED_TOPICS)
        {
            return false;
        }

        new topicText[CHAT_LINE_MAX];
        Families_FormatTopic(Families_GetMemberFamily(member), extra, topicText);
        format(destination, size, "You said '%s'. Why?", topicText);
        return true;
    }

    for (new i = 0; i < sizeof(s_DialogueTopics); i++)
    {
        if (s_DialogueTopics[i][E_DIALOGUE_TOPIC_ID] == topic)
        {
            strcopy(destination, s_DialogueTopics[i][E_DIALOGUE_TOPIC_LINE], size);
            return true;
        }
    }

    return false;
}

stock bool:Dialogue_GetTopicLine(actor, group, choice, destination[], size = sizeof(destination))
{
    new extra, topic = Dialogue_GetTopicId(actor, group, choice, extra);

    if (topic == -1)
    {
        destination[0] = EOS;
        return false;
    }

    return Dialogue_FormatTopicLine(actor, topic, extra, destination, size);
}

stock bool:Dialogue_CanChoose(playerid)
{
    if (!Session_IsPlaying(playerid))
    {
        return false;
    }

    new actor = Dialogue_GetActor(playerid);

    if (!Actors_IsPlaced(actor) || !Actors_IsOpen(actor) || Actors_GetWorld(actor) != GetPlayerVirtualWorld(playerid))
    {
        return false;
    }

    new Float:positionX, Float:positionY, Float:positionZ;
    Actors_GetPos(actor, positionX, positionY, positionZ);
    return IsPlayerInRangeOfPoint(playerid, DIALOGUE_REACH * 1.5, positionX, positionY, positionZ);
}

stock bool:Dialogue_ChooseTopic(playerid, group, choice)
{
    new line[CHAT_LINE_MAX], actor = Dialogue_GetActor(playerid), extra, topic = Dialogue_GetTopicId(actor, group, choice, extra);

    if (!Dialogue_CanChoose(playerid) || topic == -1 || !Dialogue_FormatTopicLine(actor, topic, extra, line))
    {
        return false;
    }

    if (!Dialogue_IsReady(playerid))
    {
        Gui_Notify(playerid, "Give them a moment to answer.");
        return false;
    }

    Chat_Speak(playerid, CHAT_SAY, line);
    return bool:Dialogue_Hear(playerid, topic, extra, line);
}
