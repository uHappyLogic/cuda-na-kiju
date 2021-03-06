#pragma once

#include <memory>
#include <host_defines.h>

/*
@members

count			- count of elements pointed by listStart
startIdx	- start index in main pairs list ti start of the neigbours list
*/
struct NeighboursListInfoHolder
{
	unsigned int count;
	unsigned int startIdx;

	__host__ __device__ NeighboursListInfoHolder()
		: count(0), startIdx(0xffffffff)
	{
	}
	__host__ __device__ NeighboursListInfoHolder
	(unsigned int count, unsigned int index)
		: count(count), startIdx(index)
	{
	}
};
// --------------------------------------------------------------------------------------------------------------------------------------

__device__ __host__
inline bool operator==(const NeighboursListInfoHolder& a, const NeighboursListInfoHolder& b)
{
	return a.count == b.count && a.startIdx == b.startIdx;
}
//------------------------------------------------------------------------------

__device__ __host__
inline bool operator!=(const NeighboursListInfoHolder& a, const NeighboursListInfoHolder& b)
{
	return a.count != b.count || a.startIdx != b.startIdx;
}
//------------------------------------------------------------------------------
