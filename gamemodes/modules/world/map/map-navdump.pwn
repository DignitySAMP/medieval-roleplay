#define NAVDUMP_SENTINEL "nav/dump.auto"
#define NAVDUMP_DELAY_MS (15000)

forward Nav_DumpObjects();

public Nav_DumpObjects()
{
	new top = Streamer_GetUpperBound(STREAMER_TYPE_OBJECT),count = 0,skipped = 0;

	printf("[navdump] begin upper=%d",top);

	for (new id = 1;id <= top;id++)
	{
		if (!IsValidDynamicObject(DynamicObject:id))
		{
			continue;
		}

		new Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz;
		GetDynamicObjectPos(DynamicObject:id,x,y,z);
		GetDynamicObjectRot(DynamicObject:id,rx,ry,rz);

		if (IsDynamicObjectMoving(DynamicObject:id))
		{
			skipped++;
			continue;
		}

		printf("[navdump] o %d %.3f %.3f %.3f %.3f %.3f %.3f %d %d %d",Streamer_GetIntData(STREAMER_TYPE_OBJECT,id,E_STREAMER_MODEL_ID),x,y,z,rx,ry,rz,Streamer_GetIntData(STREAMER_TYPE_OBJECT,id,E_STREAMER_WORLD_ID),Streamer_GetIntData(STREAMER_TYPE_OBJECT,id,E_STREAMER_INTERIOR_ID),Map_IsMapModel(Streamer_GetIntData(STREAMER_TYPE_OBJECT,id,E_STREAMER_MODEL_ID)) ? 1 : 0);
		count++;
	}

	printf("[navdump] done objects=%d moving_skipped=%d",count,skipped);
	return 1;
}

hook OnServerFinishLoading()
{
	if (fexist(NAVDUMP_SENTINEL))
	{
		SetTimer("Nav_DumpObjects",NAVDUMP_DELAY_MS,false);
	}
}
