stock Dice_RollFace(kind)
{
	switch (kind)
	{
		case DICE_KIND_WEIGHTED:
		{
			return random(100) < DICE_WEIGHTED_CHANCE ? 1 : 1 + random(DICE_FACES);
		}
		case DICE_KIND_HEAVY:
		{
			return random(100) < DICE_WEIGHTED_CHANCE ? 5 : 1 + random(DICE_FACES);
		}
	}

	return 1 + random(DICE_FACES);
}

stock Dice_ScoringFace(kind,face)
{
	return kind == DICE_KIND_DEVIL && face == 6 ? 1 : face;
}

static Dice_ScoreCounts(const counts[DICE_FACES + 1])
{
	new points = 0;

	for (new face = 1;face <= DICE_FACES;face++)
	{
		new count = counts[face];

		if (count >= 3)
		{
			new base = face == 1 ? 1000 : face * 100;
			points += base << (count - 3);
		}
		else if (face == 1)
		{
			points += count * 100;
		}
		else if (face == 5)
		{
			points += count * 50;
		}
		else if (count > 0)
		{
			return -1;
		}
	}

	return points;
}

stock Dice_Score(const faces[],count)
{
	new counts[DICE_FACES + 1];

	for (new i = 0;i < count;i++)
	{
		if (faces[i] < 1 || faces[i] > DICE_FACES)
		{
			return -1;
		}

		counts[faces[i]]++;
	}

	if (count == 0)
	{
		return -1;
	}

	new best = Dice_ScoreCounts(counts);

	for (new run = 0;run < 3;run++)
	{
		new low = run == 1 ? 2 : 1, high = run == 0 ? 6 : (run == 1 ? 6 : 5), bonus = run == 0 ? 1500 : (run == 1 ? 750 : 500), rest[DICE_FACES + 1], bool:has = true;

		for (new face = 1;face <= DICE_FACES;face++)
		{
			rest[face] = counts[face];
		}

		for (new face = low;face <= high;face++)
		{
			if (rest[face] == 0)
			{
				has = false;
				break;
			}

			rest[face]--;
		}

		if (!has)
		{
			continue;
		}

		new remaining = Dice_ScoreCounts(rest);

		if (remaining != -1 && bonus + remaining > best)
		{
			best = bonus + remaining;
		}
	}

	return best;
}

stock bool:Dice_HasScore(const faces[],count)
{
	new counts[DICE_FACES + 1];

	for (new i = 0;i < count;i++)
	{
		if (faces[i] >= 1 && faces[i] <= DICE_FACES)
		{
			counts[faces[i]]++;
		}
	}

	if (counts[1] > 0 || counts[5] > 0)
	{
		return true;
	}

	for (new face = 1;face <= DICE_FACES;face++)
	{
		if (counts[face] >= 3)
		{
			return true;
		}
	}

	return false;
}

stock Dice_BestScore(const faces[],count,&used = 0)
{
	new best = 0;
	used = 0;

	for (new mask = 1;mask < (1 << count);mask++)
	{
		new pick[DICE_COUNT], picked = 0;

		for (new i = 0;i < count;i++)
		{
			if (mask & (1 << i))
			{
				pick[picked++] = faces[i];
			}
		}

		new points = Dice_Score(pick,picked);

		if (points > best || (points == best && points > 0 && picked > used))
		{
			best = points;
			used = mask;
		}
	}

	return best;
}
