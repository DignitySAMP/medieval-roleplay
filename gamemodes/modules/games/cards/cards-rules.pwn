stock bool:Cards_IsValid(card)
{
	return card >= 0 && card < CARDS_DECK;
}

stock Cards_Suit(card)
{
	return card / CARDS_RANKS;
}

stock Cards_Rank(card)
{
	return card % CARDS_RANKS;
}

stock Cards_Make(suit,rank)
{
	return suit * CARDS_RANKS + rank;
}

stock Cards_Name(card,dest[],size = sizeof(dest))
{
	if (!Cards_IsValid(card))
	{
		strcopy(dest,"no card",size);
		return;
	}

	format(dest,size,"%s of %s",g_CardsRankNames[Cards_Rank(card)],g_CardsSuitNames[Cards_Suit(card)]);
}

stock bool:Cards_Matches(card,other)
{
	return Cards_IsValid(card) && Cards_IsValid(other) && Cards_Rank(card) == Cards_Rank(other);
}

stock Cards_Compare(card,other)
{
	if (Cards_Rank(card) != Cards_Rank(other))
	{
		return Cards_Rank(card) > Cards_Rank(other) ? 1 : -1;
	}

	if (Cards_Suit(card) != Cards_Suit(other))
	{
		return Cards_Suit(card) > Cards_Suit(other) ? 1 : -1;
	}

	return 0;
}

stock Cards_Shuffle(deck[],count = sizeof(deck))
{
	for (new i = 0;i < count;i++)
	{
		deck[i] = i;
	}

	for (new i = count - 1;i > 0;i--)
	{
		new j = random(i + 1), swap = deck[i];
		deck[i] = deck[j];
		deck[j] = swap;
	}
}

stock Cards_Highest(const cards[],count)
{
	new best = -1;

	for (new i = 0;i < count;i++)
	{
		if (Cards_IsValid(cards[i]) && (best == -1 || Cards_Compare(cards[i],cards[best]) > 0))
		{
			best = i;
		}
	}

	return best;
}

stock Cards_CountMatches(const cards[],count,middle)
{
	new matches = 0;

	for (new i = 0;i < count;i++)
	{
		if (Cards_Matches(cards[i],middle))
		{
			matches++;
		}
	}

	return matches;
}
