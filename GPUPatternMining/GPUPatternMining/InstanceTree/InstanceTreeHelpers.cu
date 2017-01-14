#include "InstanceTreeHelpers.h"

namespace InstanceTreeHelpers
{

	__global__
	void fillFirstPairCountFromMap(
		HashMapperBean<unsigned int, Entities::InstanceTable, GPUUIntKeyProcessor> bean
		, thrust::device_ptr<const unsigned short>* cliquesCandidates
		, unsigned int count
		, thrust::device_ptr<unsigned int> result
	)
	{
		unsigned int tid = computeLinearAddressFrom2D();

		if (tid < count)
		{
			unsigned int key = static_cast<unsigned int>(cliquesCandidates[tid][0]) << 16 | cliquesCandidates[tid][1];
			Entities::InstanceTable localRes;
			GPUHashMapperProcedures::getValue(bean, key, localRes);

			__syncthreads();

			result[tid] = localRes.count;
		}
	}
	// ------------------------------------------------------------------------------

	__global__ void scatterOnesAndPositions(unsigned int nGroups, unsigned int nThreads, unsigned int* groupSizes, unsigned int* scannedGroupSizes, unsigned int *ones, unsigned int *positions)
	{
		unsigned int tid = computeLinearAddressFrom2D();

		if (tid<nGroups)
		{
			if (scannedGroupSizes[tid]<nThreads)
			{
				atomicAdd(ones + scannedGroupSizes[tid], 1);
				if (groupSizes[tid] != 0)
				{
					positions[scannedGroupSizes[tid]] = scannedGroupSizes[tid];
				}
			}
		}
	}
	// -----------------------------------------------------------------------------

	dim3 computeGrid(unsigned int n, unsigned int bs)
	{
		dim3 res;
		findSmallest2D(n, bs, res.x, res.y);
		return res;
	}
	// -----------------------------------------------------------------------------
	
	__global__ void substractTid(unsigned int nThreads, unsigned int *positions)
	{
		unsigned int tid = computeLinearAddressFrom2D();

		if (tid < nThreads)
		{
			positions[tid] = tid - positions[tid];
		}
	}
	// -----------------------------------------------------------------------------

	struct decrease : public thrust::unary_function<unsigned int, unsigned int>
	{
		__host__ __device__ unsigned int operator()(const unsigned int &x) const
		{
			return x - 1;
		}
	};
	// -----------------------------------------------------------------------------

	ForGroupsResultPtr forGroups(
		thrust::device_vector<unsigned int>& groupSizes,
		unsigned int bs)
	{

		unsigned int nGroups = groupSizes.size();

		thrust::device_vector<unsigned int> scannedGroupSizes = thrust::device_vector<unsigned int>(nGroups);//temp

		unsigned int nThreads = groupSizes[nGroups - 1];
		thrust::exclusive_scan(groupSizes.begin(), groupSizes.end(), scannedGroupSizes.begin());
		nThreads += scannedGroupSizes[nGroups - 1];

		ForGroupsResultPtr res = std::make_shared<ForGroupsResult>();

		if (nThreads>0)
		{
			res->groupNumbers = thrust::device_vector<unsigned int>(nThreads);
			res->itemNumbers = thrust::device_vector<unsigned int>(nThreads);

			thrust::fill(res->groupNumbers.begin(), res->groupNumbers.end(), 0);
			thrust::fill(res->itemNumbers.begin(), res->itemNumbers.end(), 0);


			scatterOnesAndPositions << < computeGrid(nGroups, bs), bs >> >(nGroups, nThreads,
				groupSizes.data().get(),
				scannedGroupSizes.data().get(),
				res->groupNumbers.data().get(),
				res->itemNumbers.data().get());


			thrust::inclusive_scan(res->groupNumbers.begin(), res->groupNumbers.end(), res->groupNumbers.begin());
			thrust::inclusive_scan(res->itemNumbers.begin(), res->itemNumbers.end(), res->itemNumbers.begin(), thrust::maximum<unsigned int>());

			thrust::transform(res->groupNumbers.begin(), res->groupNumbers.end(), res->groupNumbers.begin(), decrease());

			substractTid << <computeGrid(nThreads, bs), bs >> >(nThreads, res->itemNumbers.data().get());
		}

		res->threadCount = nThreads;

		return res;
	}
	// -----------------------------------------------------------------------------

}
