#define BOOT_MAX_LOADERS (64)
#define BOOT_NAME_LEN (32)

enum E_BOOT_LOADER
{
	E_BOOT_NAME[BOOT_NAME_LEN],
	E_BOOT_AFTER[BOOT_NAME_LEN],
	bool:E_BOOT_DONE,
}

static s_BootLoaders[BOOT_MAX_LOADERS][E_BOOT_LOADER];
static s_BootLoaderCount;
static s_BootRunning = -1;
static bool:s_BootFinished = false;

stock bool:Boot_IsFinished()
{
	return s_BootFinished;
}

stock Boot_RegisterLoader(const name[], const after[] = "")
{
	if (s_BootLoaderCount >= BOOT_MAX_LOADERS)
	{
		Log_Error("boot", "no room for loader %s: raise BOOT_MAX_LOADERS, this loader would never run", name);
		return;
	}

	format(s_BootLoaders[s_BootLoaderCount][E_BOOT_NAME], BOOT_NAME_LEN, "%s", name);
	format(s_BootLoaders[s_BootLoaderCount][E_BOOT_AFTER], BOOT_NAME_LEN, "%s", after);
	s_BootLoaders[s_BootLoaderCount][E_BOOT_DONE] = false;
	s_BootLoaderCount++;
}

stock Boot_GetLoaderCount()
{
	return s_BootLoaderCount;
}

stock Boot_GetLoaderName(index, dest[], size = sizeof(dest))
{
	if (index < 0 || index >= s_BootLoaderCount)
	{
		dest[0] = EOS;
		return;
	}

	format(dest, size, "%s", s_BootLoaders[index][E_BOOT_NAME]);
}

static bool:Boot_IsDone(const name[])
{
	for (new i = 0;i < s_BootLoaderCount;i++)
	{
		if (!strcmp(s_BootLoaders[i][E_BOOT_NAME], name))
		{
			return s_BootLoaders[i][E_BOOT_DONE];
		}
	}

	return true;
}

static Boot_Finish()
{
	s_BootRunning = -1;
	s_BootFinished = true;
	pawn_call_public("OnServerFinishLoading", "");
}

stock Boot_LoaderDone()
{
	if (s_BootRunning == -1)
	{
		return;
	}

	s_BootLoaders[s_BootRunning][E_BOOT_DONE] = true;
	s_BootRunning = -1;
	Boot_Next();
}

stock Boot_Run()
{
	if (!IsDatabaseReady())
	{
		Log_Warn("boot", "database not ready, %d loaders skipped", s_BootLoaderCount);
		Boot_Finish();
		return;
	}

	Migrations_Run();
}

forward Boot_Next();

public Boot_Next()
{
	new pending = 0;

	for (new i = 0;i < s_BootLoaderCount;i++)
	{
		if (s_BootLoaders[i][E_BOOT_DONE])
		{
			continue;
		}

		pending++;

		if (s_BootLoaders[i][E_BOOT_AFTER][0] != EOS && !Boot_IsDone(s_BootLoaders[i][E_BOOT_AFTER]))
		{
			continue;
		}

		s_BootRunning = i;
		pawn_call_public(s_BootLoaders[i][E_BOOT_NAME], "");
		return 1;
	}

	if (pending > 0)
	{
		Log_Warn("boot", "%d loaders wait on something that never finished", pending);
	}

	Boot_Finish();
	return 1;
}
