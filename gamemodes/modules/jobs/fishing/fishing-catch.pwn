stock bool:Fishing_IsTwilight(hour)
{
	return (hour >= CALENDAR_DAWN_HOUR - 1 && hour <= CALENDAR_DAWN_HOUR + 1) || (hour >= CALENDAR_DUSK_HOUR - 1 && hour <= CALENDAR_DUSK_HOUR + 1);
}

stock Fishing_BreedWeight(breed,water,E_SEASON:season,hour,E_MOON:moon,baitBit,bool:isNight)
{
	if (!Fishing_IsRodBreed(breed) || !(g_FishBreeds[breed][E_FISH_BREED_WATER] & (1 << water)) || !(g_FishBreeds[breed][E_FISH_BREED_SEASONS] & (1 << _:season)) || !(g_FishBreeds[breed][E_FISH_BREED_BAIT] & baitBit))
	{
		return 0;
	}

	new weight = g_FishBreeds[breed][E_FISH_BREED_RARITY], time = g_FishBreeds[breed][E_FISH_BREED_TIME];

	if (g_FishBreeds[breed][E_FISH_BREED_PEAK] & (1 << _:season))
	{
		weight *= FISHING_PEAK_BONUS;
	}

	if ((time & FISH_TIME_TWILIGHT) && Fishing_IsTwilight(hour))
	{
		weight *= 2;
	}
	else if ((time & FISH_TIME_NIGHT) && isNight)
	{
		weight *= 2;
	}
	else if (time != 0)
	{
		weight /= 2;
	}

	if (g_FishBreeds[breed][E_FISH_BREED_FULL_MOON] && moon == MOON_FULL)
	{
		weight *= 2;
	}

	if (moon == MOON_NEW)
	{
		weight = weight * 3 / 4;
	}

	return max(weight,1);
}

stock Fishing_RollCatch(water,E_SEASON:season,hour,E_MOON:moon,baitBit,bool:isNight,&grams)
{
	new total = 0, weights[sizeof(g_FishBreeds)];

	for (new i = 0;i < sizeof(g_FishBreeds);i++)
	{
		weights[i] = Fishing_BreedWeight(i,water,season,hour,moon,baitBit,isNight);
		total += weights[i];
	}

	grams = 0;

	if (total == 0)
	{
		return -1;
	}

	new roll = random(total), breed = -1;

	for (new i = 0;i < sizeof(g_FishBreeds);i++)
	{
		if (roll < weights[i])
		{
			breed = i;
			break;
		}

		roll -= weights[i];
	}

	new Float:r = float(random(1001)) / 1000.0, gramsMin = g_FishBreeds[breed][E_FISH_BREED_GRAMS_MIN], gramsMax = g_FishBreeds[breed][E_FISH_BREED_GRAMS_MAX];
	grams = gramsMin + floatround(float(gramsMax - gramsMin) * r * r);
	return breed;
}

stock Fishing_GetStrength(grams)
{
	if (grams <= 100)
	{
		return 0;
	}

	return Util_ClampInt(floatround(30.0 * floatlog(float(grams) / 1000.0,10.0) + 30.0),0,100);
}

stock Fishing_GetWaitMs(hour,E_MOON:moon)
{
	new waitMs = FISHING_WAIT_MIN_MS + random(FISHING_WAIT_MAX_MS - FISHING_WAIT_MIN_MS + 1);

	if (Fishing_IsTwilight(hour))
	{
		waitMs = waitMs * 3 / 5;
	}

	if (moon == MOON_NEW)
	{
		waitMs = waitMs * 5 / 4;
	}

	return min(waitMs,FISHING_WAIT_MAX_MS);
}

stock Fishing_FormatCatch(breed,grams,dest[],size = sizeof(dest))
{
	new name[ITEM_NAME_LEN];
	Item_GetName(ITEM_KIND_MATERIAL,g_FishBreeds[breed][E_FISH_BREED_ITEM],name);
	name[0] = tolower(name[0]);

	if (grams >= 1000)
	{
		format(dest,size,"%.1f kg %s",float(grams) / 1000.0,name);
	}
	else
	{
		format(dest,size,"%d g %s",grams,name);
	}
}
