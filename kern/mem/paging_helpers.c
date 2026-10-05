/*
 * paging_helpers.c
 *
 *  Created on: Sep 30, 2022
 *      Author: HP
 */
#include "memory_manager.h"
#include "kheap.h"

/**************************************/
/*[1] PAGE TABLE ENTRIES MANIPULATION */
/**************************************/
//===============================
//1) UPDATE PAGE PERMISSIONS
//===============================
//Should update the page permissions of the given VA as follows:
//	1. Set to 1 all "permissions_to_set"
//	2. Set to 0 all "permissions_to_reset"
//It's expected that the page table already exist. If not, the function should panic
//REMEMBER: to invalidate the TLB cache
inline void pt_set_page_permissions(uint32* directory, uint32 virtual_address, uint32 permissions_to_set, uint32 permissions_to_clear)
{
	//[1] Get the table
	uint32* ptr_page_table ;
	int ret = get_page_table(directory, virtual_address, &ptr_page_table);

	//[2] If exists, update permissions
	if (ptr_page_table != NULL)
	{
		ptr_page_table[PTX(virtual_address)] |= (permissions_to_set);
		ptr_page_table[PTX(virtual_address)] &= (~permissions_to_clear);

	}
	//[3] Else, should "panic" since the table should be exist
	else
	{
		cprintf("va=%x not exist and has no page table\n", virtual_address);
		//cprintf("[%s] va = %x\n", ptr_env->prog_name, virtual_address) ;
		panic("function pt_set_page_permissions() called with invalid virtual address. The corresponding page table doesn't exist\n") ;
	}

	//[4] Invalidate the cache memory (TLB) [call tlb_invalidate(..)]
	//tlb_invalidate(NULL, (void *)virtual_address);
	tlb_invalidate(directory, (void *)virtual_address);
}

//===============================
//2) GET PAGE PERMISSIONS
//===============================
//Should get ALL page permissions of the given VA
//If the page table not exist, return -1
inline int pt_get_page_permissions(uint32* directory, uint32 virtual_address )
{
	//TODO: PRACTICE: fill this function.
	//Comment the following line
	panic("Function is not implemented yet!");
}

//===============================
//3) CLEAR PAGE TABLE ENTRY
//===============================
//Should clear the entire entry of the page table for the given VA
//If the page table not exist, return -1
//It's expected that the page table already exist. If not, the function should panic
//REMEMBER: to invalidate the TLB cache
inline void pt_clear_page_table_entry(uint32* directory, uint32 virtual_address)
{
	//TODO: PRACTICE: fill this function.
	//Comment the following line
	panic("Function is not implemented yet!");
}

/***********************************************************************************************/
/***********************************************************************************************/

/*********************/
/*[2] PAGING HELPERS */
/*********************/
//===============================
//1) ADDRESS CONVERTION (VA->PA)
//===============================
//return the physical address corresponding to given virtual_address
//If the page or the page table is not present, return -1
inline uint32 virtual_to_physical(uint32* directory, uint32 virtual_address)
{
	//TODO: PRACTICE: fill this function.
	//Comment the following line
	panic("Function is not implemented yet!");
}

//===============================
//2) ADDRESS CONVERTION (PA->VA)
//===============================
//return the VIRTUAL address corresponding to given physical address
//If multiple VA's, return the first occurrence
//If not found, return 0xFFFFFFFF
inline uint32 physical_to_virtual(uint32* directory, uint32 physical_address)
{
	//TODO: PRACTICE: fill this function.
	//Comment the following line
	panic("Function is not implemented yet!");
}

//===============================
//3) NUMBER OF REFERENCES
//===============================
//return the number of page references on the frame at the given physical address
inline uint32 num_of_references(uint32 physical_address)
{
	//TODO: LAB4 Example#1: fill this function.
	//Comment the following line
	panic("Function is not implemented yet!");
}

//===============================
//4) ALLOCATE PAGE
//===============================
//If the given user virtual address is mapped, do nothing.
//Else:
//	allocate a single frame and map it to a given virtual address with the given perms.
//	if set_to_zero, initialize it by ZEROs
//Return
//	0 on success,
//	1 if already mapped
//  E_NO_MEM if no memory
//HINT: remember to free the allocated frame if there is no space for the necessary page table
inline int alloc_page(uint32* directory, uint32 va, uint32 perms, bool set_to_zero)
{
	//TODO: LAB4 Example#2: fill this function.
	//Comment the following line
	//panic("Function is not implemented yet!");
	uint32* ptr_table ;
	struct FrameInfo* ptr_fi = get_frame_info(directory, va, &ptr_table);
	if (ptr_fi != NULL) {
		return 1;
	}
	else {
		int ret = allocate_frame(&ptr_fi);
		if (ret == E_NO_MEM) {
			return E_NO_MEM;
		}
		ret = map_frame(directory, ptr_fi, va, perms);
		if (ret == E_NO_MEM) {
			free_frame(ptr_fi);
			return E_NO_MEM;
		}
		if (set_to_zero) {
			memset((void*)va, 0, PAGE_SIZE);
		}
		return 0;
	}
}

//===============================
//5) ALLOCATE SHARED PAGE
//===============================
//	allocate a single frame and SHARE it on the two address spaces
//	at the given virtual addresses with the given perms
//Return
//	0 on success,
//  E_NO_MEM if no memory
//HINT: remember to free the allocated frame if there is no space for the necessary page table
inline int alloc_shared_page(uint32* page_dir1, uint32 va1,uint32* page_dir2, uint32 va2, uint32 perms)
{
	//TODO: PRACTICE: fill this function.
	//Comment the following line
	panic("Function is not implemented yet!");
}

//===============================
//6) DELETE PAGE TABLE
//===============================
//	Free (delete) the page table that corresponds to the given virtual address, simply by:
//	1. removing the link between the directory and the table and
//	2. adding the frame of the table to the free frame list.

//REMEMBER: to invalidate the TLB cache
inline void del_page_table(uint32* page_dir, uint32 va)
{
	//TODO: LAB6 Example: fill this function.
	//Comment the following line
	//panic("Function is not implemented yet!");

	// get the page table of the given virtual address
	uint32 * ptr_page_table ;
	get_page_table(page_dir, va, &ptr_page_table);

	if (ptr_page_table == NULL)
		return ;

#if USE_KHEAP
	// directly remove the page table from the kernel heap
	kfree(ptr_page_table);
#else
	// get the physical address and Frame_Info of the page table
	uint32 table_pa = STATIC_KERNEL_PHYSICAL_ADDRESS(ptr_page_table);
	struct FrameInfo *table_frame_info = to_frame_info(table_pa);

	// set references of the table frame to 0 then free it by adding
	// to the free frame list
	table_frame_info->references = 0;
	free_frame(table_frame_info);
#endif

	// set the corresponding entry in the directory to 0
	uint32 dir_index = PDX(va);
	page_dir[dir_index] = 0;

	//clear the TLB cache
	tlbflush();
}


/***********************************************************************************************/
/***********************************************************************************************/
/***********************************************************************************************/
/***********************************************************************************************/
/***********************************************************************************************/

///============================================================================================
/// Dealing with page directory entry flags

inline uint32 pd_is_table_used(uint32* directory, uint32 virtual_address)
{
	return ( (directory[PDX(virtual_address)] & PERM_USED) == PERM_USED ? 1 : 0);
}

inline void pd_set_table_unused(uint32* directory, uint32 virtual_address)
{
	directory[PDX(virtual_address)] &= (~PERM_USED);
	tlb_invalidate((void *)NULL, (void *)virtual_address);
}

inline void pd_clear_page_dir_entry(uint32* directory, uint32 virtual_address)
{
	directory[PDX(virtual_address)] = 0 ;
	tlbflush();
}
