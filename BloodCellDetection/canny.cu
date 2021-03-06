#include "canny.cuh"
#include "pixel.cuh"
#include <stdio.h>
#include <cstdlib>
#define BLOCK_SIZE 32
using namespace std;

/**
=========================================== Kernel Convolution =========================================================

This function performs the convolution step on the given image array using the mask array that has been passed.
The output of this step is stored in the output array.

========================================================================================================================
**/
__global__ void convolution_kernel(const uint8_t* image, float* output, const float* mask,
	int imageRows, int imageCols, int outputRows, int outputCols,
	int maskDimension) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	const int TILE_SIZE = (BLOCK_SIZE - maskDimension + 1);

	int col = blockIdx.x * TILE_SIZE + tx;
	int row = blockIdx.y * TILE_SIZE + ty;

	int row_i = row - maskDimension / 2;
	int col_i = col - maskDimension / 2;

	float tmp = 0;

	__shared__ float sharedMem[BLOCK_SIZE][BLOCK_SIZE];

	if (row_i < imageRows && row_i >= 0 && col_i < imageCols && col_i >= 0) {
		sharedMem[ty][tx] = (float)image[row_i * imageCols + col_i];
	}
	else {
		sharedMem[ty][tx] = 0;
	}

	__syncthreads();

	if (ty < TILE_SIZE && tx < TILE_SIZE) {
		for (int i = 0; i < maskDimension; i++) {
			for (int j = 0; j < maskDimension; j++) {
				tmp += mask[i * maskDimension + j] * sharedMem[ty + i][tx + j];
			}
		}
		__syncthreads();
		if (row < outputRows && col < outputCols) {
			output[row * outputCols + col] = tmp;
		}
	}
}

__global__ void magnitude_matrix_kernel(float* mag, const float* x, const float* y, const int height, const int width) {
	int index = blockDim.x * blockIdx.x + threadIdx.x;
	int array_upper_bound = width * height;

	if (index < array_upper_bound) {
		float mags = sqrt(x[index] * x[index] + y[index] * y[index]);
		mag[index] = mags;
	}
}