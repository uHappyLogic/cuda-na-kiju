﻿#include <stdio.h>
//--------------------------------------------------------------------------------


int main()
{
	char msg[] =
	{ 
		0x00000049,0x0000006D,0x00000070,0x0000006C,0x00000065, 
		0x0000006D,0x00000065,0x0000006E,0x00000074,0x00000061,
		0x00000063,0x0000006A,0x00000061,0x00000020,0x00000061,
		0x0000006C,0x00000067,0x0000006F,0x00000072,0x00000079,
		0x00000074,0x0000006D,0x00000075,0x00000020,0x00000065,
		0x0000006B,0x00000073,0x00000070,0x0000006C,0x0000006F,
		0x00000072,0x00000061,0x00000063,0x0000006A,0x00000069,
		0x00000020,0x00000064,0x00000061,0x0000006E,0x00000079,
		0x00000063,0x00000068,0x00000020,0x0000007A,0x00000020,
		0x00000075,0x0000003F,0x00000079,0x00000063,0x00000069,
		0x00000065,0x0000006D,0x00000020,0x00000043,0x00000055,
		0x00000044,0x00000041,0x00000020,0x00000041,0x00000050,
		0x00000049,0x0000000A,0x00000000,0x00000000,0x00000000
	};

	char format[] =
	{
		0x00000025,0x00000073,0x00000000,0x00000000,0x00000000
	};

	__asm
	{
		lea eax, msg
		push eax
		lea eax, format
		push eax

		call DWORD ptr printf

		pop ebx
		pop ebx

		mov eax, 0x00000000
	}
}