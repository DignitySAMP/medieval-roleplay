stock Emotes_RegisterHelp()
{
    for (new category = 0;category < Emotes_GetCategoryCount();category++)
    {
        new name[24], question[HELP_QUESTION_LEN], answer[HELP_ANSWER_LEN] = "Type a command and a listed variant number, or use /animations to choose. Move, press Sprint or type /sa to stop. ";
        Emotes_GetCategoryName(category,name);
        format(question,sizeof(question),"Which commands are in %s?",name);

        new count = Emotes_GetCategoryEntries(category);

        for (new slot = 0;slot < count;slot++)
        {
            new emote = Emotes_GetCategoryEntry(category,slot), command[EMOTE_COMMAND_LEN], variants[EMOTE_VARIANTS_LEN];
            Emotes_GetCommand(emote,command);
            Emotes_FormatVariants(command,variants);

            if (slot != 0)
            {
                strcat(answer,", ");
            }

            if (Emotes_GetCommandEntries(command) > 1)
            {
                strcat(answer,sprintf("/%s [%s]",command,variants));
            }
            else
            {
                strcat(answer,sprintf("/%s",command));
            }
        }

        strcat(answer,".");
        Help_Register(HELP_SECTION_ROLEPLAY,question,answer,false);
    }

    for (new emote = 0;emote < Emotes_Count();emote++)
    {
        new command[EMOTE_COMMAND_LEN], name[EMOTE_NAME_LEN], variants[EMOTE_VARIANTS_LEN], description[COMMANDS_TEXT_LEN];
        Emotes_GetCommand(emote,command);

        if (Emotes_GetCommandEntry(command,0) != emote)
        {
            continue;
        }

        Emotes_GetName(emote,name);
        Emotes_FormatVariants(command,variants);

        if (!strcmp(command,"kiss"))
        {
            strcopy(description,"Kiss variants 1-6 play a solo pose. /kiss 7 asks the nearest person you're facing for an embrace and kiss.");
        }
        else if (Emotes_GetCommandEntries(command) > 1)
        {
            format(description,sizeof(description),"Play an emote. Variants: %s. Move, press Sprint or type /sa to stop.",variants);
        }
        else
        {
            format(description,sizeof(description),"Play %s. Move, press Sprint or type /sa to stop.",name);
        }

        Command_Describe(command,description,"","Animations");
    }

    new pairs[HELP_ANSWER_LEN] = "Paired commands ask the nearest person you're facing. They answer with Walk + N. ";

    for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
    {
        new command[EMOTE_COMMAND_LEN];
        Emotes_GetPairCommand(kind,command);

        if (kind != 0)
        {
            strcat(pairs,", ");
        }

        if (Emotes_GetCommandEntries(command) > 1)
        {
            strcat(pairs,sprintf("/%s %d",command,Emotes_GetPairVariant(kind)));
        }
        else
        {
            strcat(pairs,sprintf("/%s",command));
            new describe[144];
            format(describe,sizeof(describe),"%s with the nearest person you're facing. Uses the emote menu's consent rules.",g_EmotePairDefs[kind][E_EP_NAME]);
            Command_Describe(command,describe,"","Animations");
        }
    }

    strcat(pairs,". Carrying requires someone who's down or bound.");
    Help_Register(HELP_SECTION_ROLEPLAY,"Which commands work with someone else?",pairs,false);
    Command_Describe("stopanim","Stop your current emote or paired animation.","","Animations");
    Command_Describe("sa","Stop your current emote or paired animation. Short for /stopanim.","","Animations");
}

#include <pp-hooks>

hook OnGameModeInit()
{
    Help_Register(HELP_SECTION_ROLEPLAY,"How do I sit, lean or kneel?","~w~Press ~y~Walk + N (left Alt + N)~w~ or type ~y~/animations~w~ to open Emotes. Choose ~y~Sitting~w~, ~y~Leaning~w~ or ~y~Kneel and pray~w~, then click an animation. Choose a numbered variant if the command has several. Move or press ~y~Walk + N (left Alt + N)~w~ again to stop. In a category, choose ~y~Pin favourites~w~ and click an animation to add it to the top of the menu.",false);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I sit, wave or dance?","~w~Press ~y~Walk + N (left Alt + N)~w~ or type ~y~/animations~w~ for the emotes: sit, lie down, lean, kneel and pray, gestures, greetings, idles, work, dance and music. An emote plays where you stand until you move or press the keys again. Pin your favourites to the top.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I shake hands, hug or dance with someone?","~w~Press ~y~Walk + N (left Alt + N)~w~ or type ~y~/animations~w~ to open Emotes. Pick ~y~With someone else~w~. They're asked first and answer with ~y~Walk + N~w~. You can carry someone who's down or bound, or give a friend a shoulder to lean on.",false);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I play music?","~w~Use a ~y~lute~w~, ~y~flute~w~ or ~y~drum~w~ from your bag. People near you can tip you; an inn keeps a small purse for a musician who plays to the room.",false);
	Command_Describe("animations","Open the emote menu to sit, wave, dance or choose another animation.","","Talking");
	Command_Describe("anims","Open the emote menu. Short for /animations.","","Talking");
    Emotes_RegisterHelp();
	Command_Describe("emote","Staff: play an emote by number.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Perform_PromptContext");
	SetTimer("Emotes_PairTick",200,true);
	SetTimer("Perform_Tick",1000,true);

	for (new i = 0;i < sizeof(g_EmoteLibs);i++)
	{
		AnimPreload_Register(g_EmoteLibs[i]);
	}

	Perform_LendAnimsToPresets();
}

new const g_EmoteCutRows[] = {216, 217, 218, 403, 404};

stock Emotes_CutMigrationSql(bool:shift,characterid,dest[],size = sizeof(dest))
{
	new part[96];

	if (!shift)
	{
		strcopy(dest,"DELETE FROM character_emote_slots WHERE emote IN (",size);

		for (new i = 0;i < sizeof(g_EmoteCutRows);i++)
		{
			format(part,sizeof(part),"%s%d",i > 0 ? (", ") : (""),g_EmoteCutRows[i]);
			strcat(dest,part,size);
		}

		strcat(dest,")",size);
	}
	else
	{
		strcopy(dest,"UPDATE character_emote_slots SET emote = emote - (",size);

		for (new i = 0;i < sizeof(g_EmoteCutRows);i++)
		{
			format(part,sizeof(part),"%s(emote > %d)",i > 0 ? (" + ") : (""),g_EmoteCutRows[i]);
			strcat(dest,part,size);
		}

		format(part,sizeof(part),") WHERE emote > %d",g_EmoteCutRows[0]);
		strcat(dest,part,size);
	}

	if (characterid > 0)
	{
		format(part,sizeof(part)," AND character_id = %d",characterid);
		strcat(dest,part,size);
	}
}

hook OnMigrationRun()
{
	Migration_Add("emotes-1-slots","CREATE TABLE IF NOT EXISTS character_emote_slots (character_id INT UNSIGNED NOT NULL, slot TINYINT NOT NULL, emote SMALLINT NOT NULL, PRIMARY KEY (character_id, slot)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("emotes-2-poses-removed","DELETE FROM character_emote_slots WHERE emote BETWEEN 107 AND 110");
	Migration_Add("emotes-3-poses-closed-up","UPDATE character_emote_slots SET emote = emote - 4 WHERE emote > 110");
	new sql[320];
	Emotes_CutMigrationSql(false,0,sql);
	Migration_Add("emotes-4-private-and-squat-removed",sql);
	Emotes_CutMigrationSql(true,0,sql);
	Migration_Add("emotes-5-private-and-squat-closed-up",sql);
}
