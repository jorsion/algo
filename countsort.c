#include <stdlib.h>
#include "countsort.h"

void countsort_sort(int a[], int b[], int size, int max)
{
	int *c;
	c = malloc(sizeof(int) * max);
	int i;
	for(i = 0; i < max; i++)
	{
		c[i] = 0;
	}

	for(i = 0; i < size; i++)
	{
		c[a[i]] += 1;
	}
	
	for(i = 1; i < max; i++)
	{
		c[i] += c[i - 1];
	}

	for(i = size -1; i >= 0; i--)
	{
		b[c[a[i]]] = a[i];
		c[a[i]] -= 1;
	}
	free(c);
}

int main(int argc, char** argv)
{
	return 0;
}
