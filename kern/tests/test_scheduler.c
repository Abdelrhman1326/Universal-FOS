#include <kern/proc/priority_manager.h>
#include <inc/assert.h>
#include <kern/proc/user_environment.h>
#include <kern/cmd/command_prompt.h>
#include <kern/disk/pagefile_manager.h>
#include <kern/cpu/sched.h>
#include "../mem/memory_manager.h"

extern int sys_calculate_free_frames();
extern void sys_env_set_nice(int);

#define INSTANCES_NUMBER 10
#define TOTAL_NICE_VALUES 5
uint8 firstTimeTestBSD = 1;
int prog_orders[TOTAL_NICE_VALUES][INSTANCES_NUMBER];
int nice_count[TOTAL_NICE_VALUES] = {0};

void print_order(int prog_orders[][INSTANCES_NUMBER])
{
	for (int i = 0; i < TOTAL_NICE_VALUES; i++)
	{
		cprintf("\t[%d]: ", i);
		for (int j = 0; j < INSTANCES_NUMBER; j++)
		{
			if (prog_orders[i][j] == 0)
				break;
			cprintf("%d, ", prog_orders[i][j]);
		}
		cprintf("\n");
	}
}

int find_in_range(int env_id, int start, int count)
{
	int ret = -1;
	acquire_spinlock(&ProcessQueues.qlock);
	{
		struct Env *env = NULL;
		int i = 0, end = start + count;

		//REVERSE LOOP ON EXIT LIST (to be the same as the queue order)
		int numOfExitEnvs = LIST_SIZE(&ProcessQueues.env_exit_queue);
		env = LIST_LAST(&ProcessQueues.env_exit_queue);

		cprintf("searching for envID %d starting from %d till %d\n", env_id, start, end);
		for (; i < numOfExitEnvs; env = LIST_PREV(env))
			//LIST_FOREACH_R(env, &env_exit_queue)
		{
			if (i < start)
			{
				i++;
				continue;
			}
			if (i >= end)
				//return -1;
				break;

			if (env_id == env->env_id)
			{
				ret = i;
				break;
			}
			i++;
		}
	}
	release_spinlock(&ProcessQueues.qlock);
	return ret;
}


void test_bsd_nice_0()
{
	panic("Not Implemented");
}


void test_bsd_nice_1()
{
	panic("Not Implemented");
}

void test_bsd_nice_2()
{
	panic("Not Implemented");
}
