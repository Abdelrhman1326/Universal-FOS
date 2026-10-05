#include <kern/tests/test_kheap.h>

#include <inc/memlayout.h>
#include <inc/queue.h>
#include <inc/dynamic_allocator.h>
#include <kern/cpu/sched.h>
#include <kern/disk/pagefile_manager.h>
#include "../mem/kheap.h"
#include "../mem/memory_manager.h"


#define Mega  (1024*1024)
#define kilo (1024)

int test_kmalloc()
{
	panic("Not Implemented");
}


int test_kmalloc_firstfit1()
{
	panic("Not Implemented");
}

int test_kmalloc_firstfit2()
{
	panic("Not Implemented");
}

int test_fastfirstfit()
{
	panic("Not Implemented");
}


int test_kfree_bestfirstfit()
{
	panic("Not Implemented");
}

int test_kheap_phys_addr()
{
	panic("Not Implemented");
}

int test_kheap_virt_addr()
{
	panic("Not Implemented");
}

// 2024
int test_ksbrk()
{
	panic("Not Implemented");
}


//==============================================================================================//
//==============================================================================================//
//==============================================================================================//
//==============================================================================================//

int test_kmalloc_nextfit()
{
	panic("not implemented");
}

int test_kmalloc_bestfit1()
{
	panic("not implemented");
}

int test_kmalloc_bestfit2()
{
	panic("not implemented");
}

int test_kmalloc_worstfit()
{
	panic("not implemented");
}

int test_kfree()
{
	panic("not implemented");
}

int test_three_creation_functions()
{
	panic("Not Implemented");
}

extern void kfreeall() ;

int test_kfreeall()
{
	panic("not implemented");
}


extern void kexpand(uint32 newSize) ;

int test_kexpand()
{
	panic("not implemented");
}

extern void kshrink(uint32 newSize) ;

int test_kshrink()
{
	panic("not implemented");

}


int test_kfreelast()
{
	panic("not implemented");

}

int test_krealloc() {
	panic("not implemented");
}


int test_krealloc_BF() {
	panic("not implemented");

}

int test_krealloc_FF1()
{
	panic("not implemented");

}
int test_krealloc_FF2()
{
	panic("not implemented");

}

int test_krealloc_FF3()
{
	panic("not implemented");

}


