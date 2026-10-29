stock Gene_Rand(&seed,range)
{
	seed = seed * 1103515245 + 12345;
	new value = (seed >>> 16) & 0x7FFF;
	return range > 0 ? value % range : 0;
}

stock Gene_A1(cell)
{
	return (cell >> 4) & 0xF;
}

stock Gene_A2(cell)
{
	return cell & 0xF;
}

stock Gene_Pair(a1,a2)
{
	return ((a1 & 0xF) << 4) | (a2 & 0xF);
}

static Gene_Pick(&seed,const weights[],count)
{
	new total = 0;

	for (new i = 0;i < count;i++)
	{
		total += weights[i];
	}

	if (total <= 0)
	{
		return 0;
	}

	new roll = Gene_Rand(seed,total);

	for (new i = 0;i < count;i++)
	{
		if (roll < weights[i])
		{
			return i;
		}

		roll -= weights[i];
	}

	return count - 1;
}

static Gene_PickDominant(&seed,percent)
{
	return Gene_Rand(seed,100) < percent ? 1 : 0;
}

stock Gene_Roll(E_HORSES_BREED:breed,genes[],&seed)
{
	for (new locus = 0;locus < 4;locus++)
	{
		genes[locus] = Gene_Pair(Gene_Pick(seed,g_HorsesStatPool[breed][locus],3),Gene_Pick(seed,g_HorsesStatPool[breed][locus],3));
	}

	genes[HORSES_LOCUS_BASE] = Gene_Pair(Gene_PickDominant(seed,g_HorsesCoatPool[breed][0]),Gene_PickDominant(seed,g_HorsesCoatPool[breed][0]));

	new weights[3];
	weights[0] = g_HorsesAgoutiPool[breed][2];
	weights[1] = g_HorsesAgoutiPool[breed][1];
	weights[2] = g_HorsesAgoutiPool[breed][0];
	genes[HORSES_LOCUS_AGOUTI] = Gene_Pair(Gene_Pick(seed,weights,3),Gene_Pick(seed,weights,3));

	genes[HORSES_LOCUS_GREY] = Gene_Pair(Gene_PickDominant(seed,g_HorsesCoatPool[breed][1]),0);
	genes[HORSES_LOCUS_ROAN] = Gene_Pair(Gene_PickDominant(seed,g_HorsesCoatPool[breed][2]),0);
	genes[HORSES_LOCUS_PATT] = Gene_Pair(Gene_PickDominant(seed,g_HorsesCoatPool[breed][3]),0);
	genes[HORSES_LOCUS_DUN] = Gene_Pair(Gene_PickDominant(seed,g_HorsesCoatPool[breed][4]),0);
}

stock Gene_CapFine(genes[])
{
	new seen = 0;

	for (new locus = 0;locus < 3;locus++)
	{
		if (Gene_Tier(genes,locus) == 2 && ++seen > 1)
		{
			genes[locus] = Gene_Pair(min(Gene_A1(genes[locus]),1),min(Gene_A2(genes[locus]),1));
		}
	}
}

stock Gene_Tier(const genes[],locus)
{
	return max(Gene_A1(genes[locus]),Gene_A2(genes[locus]));
}

stock bool:Gene_HasDominant(const genes[],locus)
{
	return Gene_A1(genes[locus]) > 0 || Gene_A2(genes[locus]) > 0;
}

stock bool:Gene_IsCarrier(const genes[],locus)
{
	return Gene_Tier(genes,locus) > 0 && (Gene_A1(genes[locus]) == 0 || Gene_A2(genes[locus]) == 0);
}

stock bool:Gene_Cross(const sire[],const dam[],out[],&seed)
{
	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		new fromSire = Gene_Rand(seed,2) == 0 ? Gene_A1(sire[locus]) : Gene_A2(sire[locus]);
		new fromDam = Gene_Rand(seed,2) == 0 ? Gene_A1(dam[locus]) : Gene_A2(dam[locus]);
		out[locus] = Gene_Pair(fromSire,fromDam);
	}

	if (Gene_Rand(seed,100) >= HORSES_MUTATION_PERCENT)
	{
		return false;
	}

	new locus = Gene_Rand(seed,4), bool:first = Gene_Rand(seed,2) == 0, allele = first ? Gene_A1(out[locus]) : Gene_A2(out[locus]);
	allele = Util_ClampInt(allele + (Gene_Rand(seed,2) == 0 ? -1 : 1),0,2);

	if (allele == (first ? Gene_A1(out[locus]) : Gene_A2(out[locus])))
	{
		allele = allele == 0 ? 1 : allele - 1;
	}

	out[locus] = first ? Gene_Pair(allele,Gene_A2(out[locus])) : Gene_Pair(Gene_A1(out[locus]),allele);
	return true;
}

stock Gene_Coat(const genes[])
{
	new grey = Gene_A1(genes[HORSES_LOCUS_GREY]) + Gene_A2(genes[HORSES_LOCUS_GREY]);
	new bool:black = Gene_HasDominant(genes,HORSES_LOCUS_BASE), agouti = Gene_Tier(genes,HORSES_LOCUS_AGOUTI);

	if (grey >= 2)
	{
		return 9;
	}

	if (grey == 1)
	{
		return 2;
	}

	if (Gene_HasDominant(genes,HORSES_LOCUS_ROAN))
	{
		return black ? 13 : 14;
	}

	if (Gene_HasDominant(genes,HORSES_LOCUS_PATT))
	{
		return black ? 12 : 0;
	}

	if (Gene_HasDominant(genes,HORSES_LOCUS_DUN))
	{
		return black ? 10 : 11;
	}

	if (black)
	{
		if (agouti == 2)
		{
			return Gene_A1(genes[HORSES_LOCUS_AGOUTI]) == 2 && Gene_A2(genes[HORSES_LOCUS_AGOUTI]) == 2 ? 5 : 1;
		}

		return agouti == 1 ? 6 : 8;
	}

	return agouti > 0 ? 7 : 3;
}

stock Gene_Encode(const genes[],dest[],size = sizeof(dest))
{
	new digits[] = "0123456789abcdef", at = 0;

	for (new locus = 0;locus < HORSES_LOCI && at + 2 < size;locus++)
	{
		dest[at++] = digits[(genes[locus] >> 4) & 0xF];
		dest[at++] = digits[genes[locus] & 0xF];
	}

	dest[at] = EOS;
}

stock bool:Gene_Decode(const source[],genes[])
{
	if (strlen(source) < HORSES_LOCI * 2)
	{
		for (new locus = 0;locus < HORSES_LOCI;locus++)
		{
			genes[locus] = Gene_Pair(1,1);
		}

		return false;
	}

	for (new locus = 0;locus < HORSES_LOCI;locus++)
	{
		new value = 0;

		for (new i = 0;i < 2;i++)
		{
			new c = source[locus * 2 + i], digit = 0;

			if (c >= '0' && c <= '9')
			{
				digit = c - '0';
			}
			else if (c >= 'a' && c <= 'f')
			{
				digit = c - 'a' + 10;
			}
			else if (c >= 'A' && c <= 'F')
			{
				digit = c - 'A' + 10;
			}

			value = value * 16 + digit;
		}

		genes[locus] = value;
	}

	return true;
}

stock Gene_CoatName(type,dest[],size = sizeof(dest))
{
	Mount_TypeName(type,dest,size);
}

stock Gene_StatWord(const genes[],locus,bool:inbred,dest[],size = sizeof(dest))
{
	new tier = Gene_Tier(genes,locus);

	if (inbred && locus == _:HORSES_LOCUS_HLT)
	{
		tier = max(tier - 1,0);
	}

	strcopy(dest,g_HorsesStatWords[locus][tier],size);
}
