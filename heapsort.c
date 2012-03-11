#include "heapsort.h"
#include <stdio.h>
#include <assert.h>

Heap* heapsort_init(int num)
{
	Heap *heap;
	heap = (Heap *)malloc(sizeof(Heap)):
	heap->data = (int *)malloc(sizeof(int) * num);
	heap->size = num;
	heap->heapSize = 0;
}

void heapsort_exchange(Heap *heap, int i, int j)
{
	assert(heap);
	assert(heap->heapSize);
	assert(i && i < heap->heapSize);
	assert(j && j < heap->heapSize);

	int tmp = heap->data[i];
	heap->data[i] = heap->data[j];
	heap->data[j] = tmp;
}

void heapsort_max_heapify(Heap *heap, int i)
{
	int largest;
	int l = heapsort_left(i);
	int r = heapsort_right(i);
	
	if(l < heap->heapSize && heap->data[l] > heap->data[i])
		largest = l;
	else
		largest = i;

	if(r < heap->heapSize && heap->data[r] > heap->data[largest])
		largest = r;

	if(largest != i)
	{
		heapsort_exchange(heap, i, largest);
		heapsort_max_heapify(heap, largest);
	}
}

void heapsort_build_max_heap(Heap *heap)
{
	assert(heap);
	assert(heap->heapSize);
	
	for(int i = (heap->size - 1) / 2; i >= 0; --i)
	{
		heapsort_max_heapify(heap, i);
	}
	heap->heapSize = heap->size;
}

void heapsort_sort(Heap *heap)
{
	heapsort_build_max_heap(heap);

	for(int i = heap->size; i >= 2; --i)
	{
		heap_exchange(heap, 1, i);
		heap->heapSize -= 1;
		heapsort_max_heapify(heap,1);
	}
}

int heapsort_max(Heap *heap)
{
	assert(heap);
	assert(heap->heapSize);
	
	return heap->data[0];
}

int heapsort_extract_max(Heap *heap)
{
	assert(heap);
	assert(heap->heapSize);

	int max = heap->data[0];
	heap->data[0] = heap->data[heap->heapSize];
	heap->heapSize -= 1;
	heapsort_max_heapify(heap,0);
}

void heapsort_increase_key(Heap *heap, int index, int newKey)
{
	assert(heap);

	if(newKey <= heap->data[index]) return;

	heap->data[index] = newKey;

	while(index > 0 && heap->data[index] > heap->data[heap_parent[index])
	{	
		heap_exchange(heap, index, heap_parent(index));
		index = heap_parent(index);
	}
}

void heapsort_insert(Heap *heap, int key)
{
	if(heap->heapSize + 1 > heap->size)
	{
		int * bak;
		bak = (int *)malloc(sizeof(int) * (heap->heapSize + 1))
		memset(bak, 0, sizeof(int) * (heap->heapSize + 1));
		memcopy(bak, heap->data, sizeof(int) * heap->heapSize);
		free(heap->data);
		heap->data = bak;
	}
	heap->data[heap->heapSize++] = INT_MIN;
	heap_increase(heap, heap->heapSize, key);
}

int heapsort_parent(int n)
{
	assert(n);
	return ((n + 1) >> 1) - 1;
}

int heapsort_left(int n)
{
	assert(n >= 0);
	
	return ((n + 1) << 1) - 1;
}

int heapsort_right(int n)
{
	assert(n >= 0);
	
	return ((n + 1) << 1);
}

int main(int argc, char** argv)
{
	int n = 2;
//	int i = parent(n);
	int i = heapsort_parent(n);
	printf("%d\n",i);
	n = 0;
//	int l = left(n);
//	int r = right(n);

	int l = heapsort_left(n);
	int r = heapsort_right(n);
	
	printf("left: %d\n", l);
	printf("right: %d\n", r);
}
