#include <stdio.h>
#include "mergesort.h"

void mergesort_sort(int a[], int size)
{
	mergesort_internal_sort(a, 0, size - 1);
}
void mergesort_internal_sort(int a[], int m, int n)
{
	if(m < n)
	{
		int p = (n + m) / 2;
		printf("----average: %d \n",p);
		mergesort_internal_sort(a, m, p);
		mergesort_internal_sort(a, p + 1, n);
		mergesort_merge(a, m, p, n);
	}
}

void mergesort_merge(int a[], int m, int p, int n)
{
	int lenLeft = p - m + 1;
	int lenRight = n - p;
	int l[lenLeft];
	int r[lenRight];
	
	int i;
	printf("left: %d ", lenLeft);
	for(i = 0; i < lenLeft; ++i)
	{	
		
		l[i] = a[m];
		m = m + 1;
		printf(" %d",l[i]);
	}
	printf("\n");
	
	printf("P: %d\n",p);
	p = p + 1;
	printf("P: %d\n", p);
	printf("right: %d ", lenRight);
	for(i = 0; i < lenRight; ++i)
	{
		r[i] = a[p];
		p = p + 1;
		printf(" %d", r[i]);
	}
	printf("\n");
	
	int j, k;
	i = j = k = 0;
	while(j < lenLeft && k < lenRight )
	{
		if(l[j] < r[k])
		{
			a[i] = l[j];
			i = i + 1;
			j = j + 1;
		}
		else
		{
			a[i] = r[k];
			i = i + 1;
			k = k + 1;
		}
	}
	
	while(j < lenLeft)
	{
		a[i] = l[j];
		i = i + 1;
		j = j + 1;
	}
	while(k < lenRight )
	{
		a[i] = r[k];
		i = i + 1;
		k = k + 1;
	}
}

int main(int argc, char** argv)
{
	int a[] = {3,6,2,5};
//	int a[] = {3,6};
	
	int i;
	for(i = 0; i < 4; ++i)
	{
		printf(" %d", a[i]);
	}
	printf("\n");

	mergesort_sort(a, 4);
	
	for(i = 0; i < 4; ++i)
	{
		printf(" %d", a[i]);
	}
	printf("\n");

	return 0;
}
