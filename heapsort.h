#ifndef HEAPSORT_H
#define HEAPSORT_H

#define INT_MIN (-2147483647 -1)

#define INT_MAX (2147483647)

#define LENGTH 20;

#define parent(n) (((n + 1) >> 1) - 1)

#define left(n) (((n + 1) << 1) - 1)

#define right(n) ((n + 1) << 1)

typedef struct _heap Heap;

struct _heap
{
	int *data;
	int size;
	int heapSize;
};

Heap* heapsort_init(int num);

void heapsort_exchange(Heap *heap, int i, int j);

void heapsort_max_heapify(Heap *heap, int i);

void heapsort_build_max_heap(Heap *heap);

int heapsort_max(Heap *heap);

int heapsort_extract_max(Heap *heap);

void heapsort_increase_key(Heap *heap, int index, int newKey);

void heapsort_insert(Heap *heap, int key);

void heapsort_sort(Heap *heap);

int heapsort_parent(int n);

int heapsort_left(int n);

int heapsort_right(int n);

#endif
