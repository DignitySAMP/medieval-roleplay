stock bool:Util_IsValidPlayer(playerid)
{
	if (playerid < 0 || playerid >= MAX_PLAYERS)
	{
		return false;
	}

	return IsPlayerConnected(playerid);
}

stock bool:Util_IsValidVehicle(vehicleid)
{
	if (vehicleid < 1 || vehicleid > MAX_VEHICLES)
	{
		return false;
	}

	return IsValidVehicle(vehicleid);
}

stock bool:Util_StartsWithVowel(const text[])
{
	switch (tolower(text[0]))
	{
		case 'a', 'e', 'i', 'o', 'u': return true;
	}

	return false;
}

stock bool:Util_IsValidActor(actorid)
{
	if (actorid < 0 || actorid >= MAX_ACTORS)
	{
		return false;
	}

	return IsValidActor(actorid);
}

stock Float:Util_GetDistance2D(Float:x1,Float:y1,Float:x2,Float:y2)
{
	return VectorSize(x2 - x1,y2 - y1,0.0);
}

stock Float:Util_GetDistance3D(Float:x1,Float:y1,Float:z1,Float:x2,Float:y2,Float:z2)
{
	return VectorSize(x2 - x1,y2 - y1,z2 - z1);
}

stock Float:Util_NormalizeAngle(Float:angle)
{
	while (angle < 0.0)
	{
		angle += 360.0;
	}

	while (angle >= 360.0)
	{
		angle -= 360.0;
	}

	return angle;
}

stock bool:Util_IsPointInRadius(Float:px,Float:py,Float:cx,Float:cy,Float:radius)
{
	return Util_GetDistance2D(px,py,cx,cy) <= radius;
}

stock bool:Util_IsPointInRect(Float:px,Float:py,Float:minX,Float:minY,Float:maxX,Float:maxY)
{
	return px >= minX && px <= maxX && py >= minY && py <= maxY;
}

stock Util_GetOffsetPoint(Float:originX,Float:originY,Float:angle,Float:distance,&Float:outX,&Float:outY)
{
	new Float:heading = Util_NormalizeAngle(angle);

	outX = originX + distance * floatsin(-heading,degrees);
	outY = originY + distance * floatcos(-heading,degrees);
}

stock Util_GetRightOfPoint(Float:originX,Float:originY,Float:angle,Float:distance,&Float:outX,&Float:outY)
{
	Util_GetOffsetPoint(originX,originY,angle - 90.0,distance,outX,outY);
}

stock Util_GetLeftOfPoint(Float:originX,Float:originY,Float:angle,Float:distance,&Float:outX,&Float:outY)
{
	Util_GetOffsetPoint(originX,originY,angle + 90.0,distance,outX,outY);
}

stock Float:Util_Font1Width(length,Float:letterX)
{
	return 6.0 + (float(length) * letterX * 19.0);
}

stock Float:Util_Clamp(Float:value,Float:minValue,Float:maxValue)
{
	if (value < minValue)
	{
		return minValue;
	}

	if (value > maxValue)
	{
		return maxValue;
	}

	return value;
}

stock Util_ClampInt(value,minValue,maxValue)
{
	return clamp(value,minValue,maxValue);
}

stock Float:Util_Lerp(Float:fromValue,Float:toValue,Float:fraction)
{
	return fromValue + (toValue - fromValue) * fraction;
}

stock Util_TrimString(const source[],dest[],destLength = sizeof(dest))
{
	new start = 0, end = strlen(source);

	while (start < end && (source[start] == ' ' || source[start] == '\t'))
	{
		start++;
	}

	while (end > start && (source[end - 1] == ' ' || source[end - 1] == '\t'))
	{
		end--;
	}

	strmid(dest,source,start,end,destLength);
}

stock Util_SanitizeChatText(const source[],dest[],destLength = sizeof(dest))
{
	new writeIndex = 0;

	for (new i = 0;source[i] != EOS && writeIndex < destLength - 1;i++)
	{
		new character = source[i];

		if (character != '%' && character != '{' && character != '}')
		{
			dest[writeIndex] = character;
			writeIndex++;
		}
	}

	dest[writeIndex] = EOS;
}

stock Util_SanitizeDisplayText(const source[],dest[],destLength = sizeof(dest))
{
	new writeIndex = 0;

	for (new i = 0;source[i] != EOS && writeIndex < destLength - 1;i++)
	{
		new character = source[i];

		if (character != '%' && character != '{' && character != '}' && character != '~')
		{
			dest[writeIndex] = character;
			writeIndex++;
		}
	}

	dest[writeIndex] = EOS;
}

stock bool:Util_IsAlphanumeric(const text[])
{
	if (text[0] == EOS)
	{
		return false;
	}

	for (new i = 0;text[i] != EOS;i++)
	{
		new character = text[i];

		if ((character < '0' || character > '9') && (character < 'A' || character > 'Z') && (character < 'a' || character > 'z'))
		{
			return false;
		}
	}

	return true;
}

stock Util_FormatThousands(value,dest[],size = sizeof(dest))
{
	new raw[16];
	format(raw,sizeof(raw),"%d",value < 0 ? -value : value);

	new rawLength = strlen(raw), pos = 0;

	if (value < 0 && pos < size - 1)
	{
		dest[pos++] = '-';
	}

	for (new i = 0;i < rawLength && pos < size - 1;i++)
	{
		if (i > 0 && ((rawLength - i) % 3) == 0)
		{
			dest[pos++] = ',';
		}

		if (pos < size - 1)
		{
			dest[pos++] = raw[i];
		}
	}

	dest[pos] = EOS;
	return pos;
}

stock Util_FormatMoney(amount,dest[],destLength = sizeof(dest))
{
	new digits[24];
	Util_FormatThousands(amount,digits);

	if (amount < 0)
	{
		format(dest,destLength,"-$%s",digits[1]);
	}
	else
	{
		format(dest,destLength,"$%s",digits);
	}
}

stock Util_FormatDuration(seconds,dest[],destLength = sizeof(dest))
{
	if (seconds < 0)
	{
		seconds = 0;
	}

	new hours = seconds / 3600;
	new minutes = (seconds % 3600) / 60;
	new secondsPart = seconds % 60;

	if (hours > 0)
	{
		format(dest,destLength,"%02d:%02d:%02d",hours,minutes,secondsPart);
	}
	else
	{
		format(dest,destLength,"%02d:%02d",minutes,secondsPart);
	}
}

stock Util_GetPlayersInRange(Float:x,Float:y,Float:z,Float:range,results[],maxResults = sizeof(results))
{
	new count = 0;

	foreach(new i : Player)
	{
		if (count >= maxResults)
		{
			break;
		}

		new Float:px,Float:py,Float:pz;
		GetPlayerPos(i,px,py,pz);

		if (Util_GetDistance3D(x,y,z,px,py,pz) <= range)
		{
			results[count] = i;
			count++;
		}
	}

	return count;
}

stock Util_GetPlayerName(playerid)
{
	static name[MAX_PLAYER_NAME + 1];

	name[0] = EOS;
	GetPlayerName(playerid,name,sizeof(name));
	return name;
}

stock Util_GetPlayerIp(playerid)
{
	static ip[16 + 1];

	ip[0] = EOS;
	GetPlayerIp(playerid,ip,sizeof(ip));
	return ip;
}

stock Util_GetPlayerSerial(playerid)
{
	static serial[40 + 1];

	serial[0] = EOS;
	gpci(playerid,serial,sizeof(serial));
	return serial;
}

stock Util_MakeCooldown(seconds)
{
	return gettime() + seconds;
}

stock bool:Util_HasCooldown(expireTime)
{
	return expireTime > gettime();
}

stock Util_CooldownLeft(expireTime)
{
	new left = expireTime - gettime();
	return left > 0 ? left : 0;
}

forward Util_OnTeleporting(playerid,bool:keepMounted);

public Util_OnTeleporting(playerid,bool:keepMounted)
{
    return 1;
}

stock Util_SafeTeleport(playerid,Float:x,Float:y,Float:z,Float:angle,worldid,interiorid,bool:keepMounted = false)
{
    pawn_call_public("Util_OnTeleporting","dd",playerid,keepMounted);

	if (IsPlayerInAnyVehicle(playerid))
	{
		RemovePlayerFromVehicle(playerid);
	}

	SetPlayerVirtualWorld(playerid,worldid);
	SetPlayerInterior(playerid,interiorid);
	SetPlayerPos(playerid,x,y,z);
	SetPlayerFacingAngle(playerid,angle);
	SetCameraBehindPlayer(playerid);
	Util_RefreshTeleport(playerid,x,y,z,worldid,interiorid,1500);
}

stock Util_RandomRange(minValue,maxValue)
{
	if (maxValue <= minValue)
	{
		return minValue;
	}

	return minValue + random(maxValue - minValue + 1);
}

stock bool:Util_Chance(Float:percentChance)
{
	if (percentChance <= 0.0)
	{
		return false;
	}

	if (percentChance >= 100.0)
	{
		return true;
	}

	return (float(random(10000)) / 100.0) < percentChance;
}

stock Util_WeightedRandom(const weights[],count)
{
	if (count <= 0)
	{
		return -1;
	}

	new total = 0;
	for (new i = 0;i < count;i++)
	{
		if (weights[i] > 0)
		{
			total += weights[i];
		}
	}

	if (total <= 0)
	{
		return -1;
	}

	new roll = random(total), cumulative = 0;

	for (new i = 0;i < count;i++)
	{
		if (weights[i] <= 0)
		{
			continue;
		}

		cumulative += weights[i];

		if (roll < cumulative)
		{
			return i;
		}
	}

	return -1;
}

stock Util_ShuffleArray(items[],count)
{
	for (new i = count - 1;i > 0;i--)
	{
		new j = random(i + 1), swap = items[i];

		items[i] = items[j];
		items[j] = swap;
	}
}

stock Util_OrdinalSuffix(value)
{
	static const suffixes[4][3] = {"th","st","nd","rd"};

	new tens = (value / 10) % 10, units = value % 10;

	if (tens == 1 || units > 3)
	{
		return suffixes[0];
	}

	return suffixes[units];
}

stock Util_WrapText(const text[],dest[],size,width,const newline[])
{
	new column = 0, out = 0, i = 0, newlineLength = strlen(newline);

	while (text[i] != EOS && out < size - newlineLength - 2)
	{
		while (text[i] == ' ')
		{
			i++;
		}

		if (text[i] == EOS)
		{
			break;
		}

		new wordEnd = i;

		while (text[wordEnd] != EOS && text[wordEnd] != ' ')
		{
			wordEnd++;
		}

		new wordLength = wordEnd - i;

		if (column > 0 && column + 1 + wordLength > width)
		{
			for (new n = 0;n < newlineLength;n++)
			{
				dest[out++] = newline[n];
			}

			column = 0;
		}
		else if (column > 0)
		{
			dest[out++] = ' ';
			column++;
		}

		while (i < wordEnd && out < size - newlineLength - 2)
		{
			dest[out++] = text[i++];
			column++;
		}

		i = wordEnd;
	}

	dest[out] = EOS;
}

stock Float:Util_GetAngleToPoint(Float:fromX,Float:fromY,Float:toX,Float:toY)
{
	return Util_NormalizeAngle(atan2(toY - fromY,toX - fromX) - 90.0);
}

stock Util_FacePoint(playerid,Float:x,Float:y,Float:offset = 0.0)
{
	new Float:px, Float:py, Float:pz;

	GetPlayerPos(playerid,px,py,pz);
	SetPlayerFacingAngle(playerid,Util_NormalizeAngle(Util_GetAngleToPoint(px,py,x,y) + offset));
}

stock Util_GetClosestPlayer(playerid,Float:maxRange = 10000.0,&Float:distance = 0.0)
{
	new closest = INVALID_PLAYER_ID;
	new Float:px, Float:py, Float:pz;

	GetPlayerPos(playerid,px,py,pz);
	distance = maxRange;

	foreach (new i : Player)
	{
		if (i == playerid || IsPlayerNPC(i) || GetPlayerVirtualWorld(i) != GetPlayerVirtualWorld(playerid))
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(i,x,y,z);

		new Float:current = Util_GetDistance3D(px,py,pz,x,y,z);

		if (current < distance)
		{
			distance = current;
			closest = i;
		}
	}

	return closest;
}

stock Util_PlaySoundNear(sound,Float:x,Float:y,Float:z,Float:range = -1.0)
{
	foreach (new i : Player)
	{
		if (IsPlayerNPC(i))
		{
			continue;
		}

		if (range > 0.0)
		{
			new Float:px, Float:py, Float:pz;
			GetPlayerPos(i,px,py,pz);

			if (Util_GetDistance3D(x,y,z,px,py,pz) > range)
			{
				continue;
			}
		}

		PlayerPlaySound(i,sound,x,y,z);
	}
}
