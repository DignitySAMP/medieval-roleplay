stock Wounds_SpillBlood(Float:x,Float:y,Float:groundZ,world = 0)
{
	for (new i = 0;i < WOUND_POOL_SPLASHES;i++)
	{
		new Float:ang = float(random(360)), Float:off = float(random(floatround(WOUND_POOL_SPREAD * 100.0))) / 100.0, Float:px = x + floatsin(-ang,degrees) * off, Float:py = y + floatcos(-ang,degrees) * off, Float:pz = groundZ, Float:hx, Float:hy, Float:hz;

		if (world == 0 && CA_RayCastLine(px,py,groundZ + WOUND_POOL_RAY,px,py,groundZ - WOUND_POOL_RAY,hx,hy,hz) != 0)
		{
			pz = hz;
		}

		new STREAMER_TAG_OBJECT:pool = CreateDynamicObject(WOUND_POOL_MODEL,px,py,pz + WOUND_POOL_LIFT,0.0,0.0,float(random(360)),world,-1,-1,WOUND_BLOOD_STREAM,WOUND_BLOOD_STREAM);
		SetTimerEx("Wounds_DropBlood",WOUND_POOL_MS,false,"d",_:pool);
	}

	Nearby_StreamObjectsAt(x,y,groundZ,world,-1,WOUND_BLOOD_STREAM);
}

forward Wounds_DropBlood(objectid);

public Wounds_DropBlood(objectid)
{
	if (IsValidDynamicObject(STREAMER_TAG_OBJECT:objectid))
	{
		DestroyDynamicObject(STREAMER_TAG_OBJECT:objectid);
	}

	return 1;
}
