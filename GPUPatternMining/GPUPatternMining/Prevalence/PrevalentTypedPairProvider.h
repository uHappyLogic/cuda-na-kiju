#pragma once

#include <map>

#include <thrust/device_vector.h>
#include <thrust/execution_policy.h>
#include <thrust/unique.h>

#include "../HashMap/gpuhashmapper.h"

#include "../Entities/InstanceTable.h"
#include "../Entities/FeatureTypePair.h"
#include "../Entities/FeatureInstance.h"
#include "../Entities/TypeCount.h"
#include "../PlaneSweep/PlaneSweepTableInstanceResult.h"
#include "../InstanceTree/IntanceTablesMapCreator.h"
//------------------------------------------------------------------

class PlaneSweepTableInstanceResult;

namespace Prevalence
{
	namespace UniqueFilter
	{
		typedef GPUHashMapper<unsigned int, Entities::InstanceTable, GPUKeyProcessor<unsigned int>> InstanceTableMap;
		typedef std::shared_ptr<InstanceTableMap> InstanceTableMapPtr;

		typedef GPUHashMapper<unsigned int, unsigned short, GPUKeyProcessor<unsigned int>> CountMap;
		typedef std::shared_ptr<CountMap> CountMapPtr;
		//------------------------------------------------------------------

		struct FeatureInstancesTupleToFeatureTypePair : public thrust::unary_function<FeatureTypePair, thrust::tuple<FeatureInstance, FeatureInstance>>
		{
			__host__ __device__
			FeatureTypePair operator()(thrust::tuple<FeatureInstance, FeatureInstance> ftt)
			{
				FeatureTypePair ftp;

				ftp.combined =
					((ftt.get<0>().fields.featureId << 16) & 0xFFFF0000)
					| ((ftt.get<1>().fields.featureId) & 0x0000FFFF);

				return ftp;
			}
		};

		__global__
		void setPrevalentFlag(
			float minimalPrevalence
			, unsigned int count
			, thrust::device_ptr<float> a
			, thrust::device_ptr<float> b
			, thrust::device_ptr<bool> flag
			, thrust::device_ptr<unsigned int> writePos);
		//------------------------------------------------------------------

		__global__
		void writeThroughtMask(
			unsigned int count
			, thrust::device_ptr<FeatureTypePair> uniques
			, thrust::device_ptr<bool> mask
			, thrust::device_ptr<unsigned int> writePos
			, thrust::device_ptr<FeatureTypePair> prevalentPairs);
		//------------------------------------------------------------------

		struct UniqueTupleCountFunctor
		{
			thrust::device_ptr<FeatureInstance> data;
			thrust::device_ptr<unsigned int> begins;
			thrust::device_ptr<unsigned int> typeCount;
			thrust::device_ptr<unsigned int> count;

			thrust::device_ptr<FeatureInstance> uniquesOutput;

			thrust::device_ptr<float> results;

			__host__ __device__
				void operator()(unsigned int idx)
			{
				auto end = thrust::unique_copy
				(
					thrust::device
					, data + begins[idx]
					, data + begins[idx] + count[idx]
					, uniquesOutput + begins[idx]
				);

				results[idx] = thrust::distance(
					uniquesOutput + begins[idx]
					, end
				) / static_cast<float>(typeCount[idx]);
			}
		};
		// -------------------------------------------------------------------------------------------------

		struct UniqueTupleCountFunctorUnsorted
		{
			thrust::device_ptr<unsigned int> begins;
			thrust::device_ptr<unsigned int> typeCount;
			thrust::device_ptr<unsigned int> count;

			thrust::device_ptr<FeatureInstance> uniquesOutput;

			thrust::device_ptr<float> results;

			__host__ __device__
				void operator()(unsigned int idx)
			{
				thrust::sort
				(
					thrust::device
					, uniquesOutput + begins[idx]
					, uniquesOutput + begins[idx] + count[idx]
				);

				auto end = thrust::unique
				(
					thrust::device
					, uniquesOutput + begins[idx]
					, uniquesOutput + begins[idx] + count[idx]
				);

				results[idx] = thrust::distance(
					uniquesOutput + begins[idx]
					, end
				) / static_cast<float>(typeCount[idx]);
			}
		};
		// -------------------------------------------------------------------------------------------------


		class PrevalentTypedPairProvider
		{
		public:

			PrevalentTypedPairProvider(
				std::vector<TypeCount>& typesCounts
				, IntanceTablesMapCreator::ITMPackPtr itmPack
			);

			~PrevalentTypedPairProvider();

			/*
			@params

			minimalPrevalence	-	minimal required prevalence
			uniques				-	vector that contains type pairs for prevalence check

			*/
			thrust::device_vector<FeatureTypePair> getPrevalentPairConnections(
				float minimalPrevalence
				, PlaneSweepTableInstanceResultPtr planeSweepResult
			);

		private:

			std::map<unsigned int, unsigned short> typeCountMap;
			IntanceTablesMapCreator::ITMPackPtr itmPack;
		};
	}
}
