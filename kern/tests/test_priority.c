#include <kern/proc/priority_manager.h>
#include <inc/assert.h>
#include <kern/proc/user_environment.h>
#include <kern/cmd/command_prompt.h>
#include <kern/disk/pagefile_manager.h>
#include "../mem/memory_manager.h"

extern int sys_calculate_free_frames();

uint8 firstTime = 1;
void test_priority_normal_and_higher()
{
	panic("Not Implemented");
}

void test_priority_normal_and_lower()
{
	panic("Not Implemented");
}
