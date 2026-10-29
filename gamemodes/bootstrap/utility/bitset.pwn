#define BIT(%0) (1 << (%0))
#define BITSET_CELLS(%0) (((%0) + 31) / 32)

stock bool:Bit_IsSet(value,index)
{
	return (value & (1 << (index & 31))) != 0;
}

stock bool:Bit_HasAll(value,mask)
{
	return (value & mask) == mask;
}

stock bool:Bit_HasAny(value,mask)
{
	return (value & mask) != 0;
}

stock Bit_Set(&value,index)
{
	value |= (1 << (index & 31));
}

stock Bit_Clear(&value,index)
{
	value &= ~(1 << (index & 31));
}

stock Bit_Toggle(&value,index)
{
	value ^= (1 << (index & 31));
}

stock bool:Bitset_IsSet(const bits[],index)
{
	return (bits[index >>> 5] & (1 << (index & 31))) != 0;
}

stock Bitset_Set(bits[],index)
{
	bits[index >>> 5] |= (1 << (index & 31));
}

stock Bitset_Clear(bits[],index)
{
	bits[index >>> 5] &= ~(1 << (index & 31));
}

stock Bitset_Toggle(bits[],index)
{
	bits[index >>> 5] ^= (1 << (index & 31));
}

stock Bitset_Reset(bits[],size = sizeof(bits))
{
	for (new i = 0;i < size;i++)
	{
		bits[i] = 0;
	}
}
