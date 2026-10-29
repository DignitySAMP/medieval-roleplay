#define HELP_MAX_TOPICS (192)
#define HELP_QUESTION_LEN (64)
#define HELP_ANSWER_LEN (640)
#define HELP_SECTION_NAME_LEN (24)

enum E_HELP_SECTION
{
	HELP_SECTION_START,
	HELP_SECTION_SURVIVAL,
	HELP_SECTION_WORK,
	HELP_SECTION_COMBAT,
	HELP_SECTION_FAITH,
	HELP_SECTION_FAMILY,
	HELP_SECTION_ROLEPLAY,
	HELP_SECTION_COUNT
}

enum E_HELP_TOPIC
{
	E_HELP_SECTION:E_HELP_TOPIC_SECTION,
	E_HELP_TOPIC_QUESTION[HELP_QUESTION_LEN],
	E_HELP_TOPIC_ANSWER[HELP_ANSWER_LEN],
	bool:E_HELP_TOPIC_BROADCAST
}

static const s_HelpSectionNames[HELP_SECTION_COUNT][HELP_SECTION_NAME_LEN] = {
	"Getting started",
	"Survival",
	"Work and crafting",
	"Combat",
	"Faith",
	"Family and death",
	"Roleplay"
};

new g_HelpTopics[HELP_MAX_TOPICS][E_HELP_TOPIC];
new g_HelpTopicCount;

stock bool:Help_Register(E_HELP_SECTION:section,const question[],const answer[],bool:broadcast = true)
{
	if (g_HelpTopicCount >= HELP_MAX_TOPICS)
	{
		Log_Error("help","topic table full - '%s' not registered",question);
		return false;
	}

	g_HelpTopics[g_HelpTopicCount][E_HELP_TOPIC_SECTION] = section;
	strcopy(g_HelpTopics[g_HelpTopicCount][E_HELP_TOPIC_QUESTION],question,HELP_QUESTION_LEN);
	strcopy(g_HelpTopics[g_HelpTopicCount][E_HELP_TOPIC_ANSWER],answer,HELP_ANSWER_LEN);
	g_HelpTopics[g_HelpTopicCount][E_HELP_TOPIC_BROADCAST] = broadcast;
	g_HelpTopicCount++;
	return true;
}

stock Help_GetTopicCount()
{
	return g_HelpTopicCount;
}

stock E_HELP_SECTION:Help_GetTopicSection(index)
{
	if (index < 0 || index >= g_HelpTopicCount)
	{
		return HELP_SECTION_COUNT;
	}

	return g_HelpTopics[index][E_HELP_TOPIC_SECTION];
}

stock bool:Help_GetTopic(index,question[],answer[],questionSize = sizeof(question),answerSize = sizeof(answer))
{
	if (index < 0 || index >= g_HelpTopicCount)
	{
		question[0] = EOS;
		answer[0] = EOS;
		return false;
	}

	strcopy(question,g_HelpTopics[index][E_HELP_TOPIC_QUESTION],questionSize);
	strcopy(answer,g_HelpTopics[index][E_HELP_TOPIC_ANSWER],answerSize);
	return true;
}

stock bool:Help_IsBroadcast(index)
{
	return index >= 0 && index < g_HelpTopicCount && g_HelpTopics[index][E_HELP_TOPIC_BROADCAST];
}

stock Help_GetSectionName(E_HELP_SECTION:section,dest[],size = sizeof(dest))
{
	if (section < HELP_SECTION_START || section >= HELP_SECTION_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_HelpSectionNames[section],size);
}

stock Help_CountInSection(E_HELP_SECTION:section)
{
	new count = 0;

	for (new i = 0;i < g_HelpTopicCount;i++)
	{
		if (g_HelpTopics[i][E_HELP_TOPIC_SECTION] == section)
		{
			count++;
		}
	}

	return count;
}
