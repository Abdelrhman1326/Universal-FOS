// Simple command-line kernel prompt useful for
// controlling the kernel and exploring the system interactively.

#include <kern/cmd/command_prompt.h>
#include <kern/proc/user_environment.h>
#include <kern/cons/console.h>
#include <kern/cpu/cpu.h>
#include <kern/cpu/sched.h>
#include "commands.h"

extern bool autograde ;
extern void command_prompt_readline(const char *prompt, char* buf);
void run_command_prompt()
{
	if (autograde)
	{
		autograde = 0;
	}
	/*2024*/
	LIST_INIT(&foundCommands);
	//========================

	char command_line[BUFLEN];

	while (1==1)
	{
		//readline("FOS> ", command_line);

		memset(command_line, 0, sizeof(command_line));
		command_prompt_readline("FOS> ", command_line);

		//parse and execute the command
		if (command_line != NULL)
			if (execute_command(command_line) < 0)
				break;
	}
}

/* get into the command prompt - This function does not return.
 * The only way to get into the prompt is via this function to ensure correct re-initializations
 * The following variables are used to clear the entire content of the KERNEL STACK before getting into the prompt
 * They're placed globally (instead of locally) to avoid clearing them while they're in use [el7 :)]
 */
int m;
char *p ;
void get_into_prompt()
{
	while (1)
	{
		//disable interrupt if it's already enabled
		if (read_eflags() & FL_IF)
			cli();

		//Switch to the kernel virtual memory
		switchkvm();

		//Reset current CPU
		struct cpu *c = mycpu();
		c->ncli = 0;
		c->intena = 0;
		c->scheduler = NULL;
		c->scheduler_status = SCH_STOPPED ;
		c->proc = NULL;

		//Read current ESP
		uint32 cur_esp = read_esp();

		//Reset ESP to the beginning of the SCHED KERNEL STACK of this CPU before getting into the cmd prmpt
		uint32 cpuStackTop = (uint32)c->stack + KERNEL_STACK_SIZE;
		uint32 cpuStackBottom = (uint32)c->stack + PAGE_SIZE/*GUARD Page*/;
		write_esp(cpuStackTop);

		//Clear the stack content to avoid any garbage data on it when getting back into prompt
		if (cur_esp < cpuStackTop && cur_esp >= cpuStackBottom)
		{
			//memset((char*)cur_esp, 0, SCHD_KERN_STACK_TOP - cur_esp);
			p = (char*)cur_esp;
			m = cpuStackTop - cur_esp;
			while (--m >= 0)
				*p++ = 0;
		}
		else	//clear the ENTIRE SCHED KERN STACK
		{
			//memset((char*)schd_kern_stack_bottom, 0, SCHD_KERN_STACK_TOP - schd_kern_stack_bottom);
			p = (char*)cpuStackBottom;
			m = cpuStackTop - cpuStackBottom;
			while (--m >= 0)
				*p++ = 0;
		}

		//Reset EBP to ZERO so that when calling the run_command_prompt() it pushes ZERO into the stack
		write_ebp(0);

		//Get into the prompt (should NOT return)
		run_command_prompt(NULL);
	}

}


/***** Kernel command prompt command interpreter *****/

//define the white-space symbols
#define WHITESPACE "\t\r\n "

//Function to parse any command and execute it
//(simply by calling its corresponding function)
int execute_command(char *command_string)
{
	// Split the command string into whitespace-separated arguments
	int number_of_arguments;
	//allocate array of char * of size MAX_ARGUMENTS = 16 found in string.h
	char *arguments[MAX_ARGUMENTS];


	strsplit(command_string, WHITESPACE, arguments, &number_of_arguments) ;
	if (number_of_arguments == 0)
		return 0;

	int ret = process_command(number_of_arguments, arguments);

	if (ret == CMD_INVALID)
	{
		cprintf("Unknown command '%s'\n", arguments[0]);
	}
	else if (ret == CMD_INV_NUM_ARGS)
	{
		int numOfFoundCmds = LIST_SIZE(&foundCommands);
		if (numOfFoundCmds != 1)
		{
			panic("command is found but the list is either empty or contains more than one command!");
		}
		struct Command * cmd = LIST_FIRST(&foundCommands);
		cprintf("%s: invalid number of args.\nDescription: %s\n", cmd->name, cmd->description);
	}
	else if (ret == CMD_MATCHED)
	{
		int i = 1;
		int numOfFoundCmds = LIST_SIZE(&foundCommands);
		if (numOfFoundCmds == 0)
		{
			panic("command is matched but the list is empty!");
		}
		struct Command * cmd = NULL;
		LIST_FOREACH(cmd, &foundCommands)
		{
			cprintf("[%d] %s\n", i++, cmd->name);
		}
		cprintf("Please select the required command [1] to [%d] and press enter? or press any other key to cancel: ", numOfFoundCmds);
		char Chose = getchar();
		cputchar(Chose);
		int selection = 0;
		while (Chose >= '0' && Chose <= '9')
		{
			selection = selection*10 + (Chose - '0') ;
			if (selection < 1 || selection > numOfFoundCmds)
				break;

			Chose = getchar();
			cputchar(Chose);
		}
		cputchar('\n');
		if (selection >= 1 && selection <= numOfFoundCmds)
		{
			int c = 1;
			LIST_FOREACH(cmd, &foundCommands)
			{
				if (c++ == selection)
				{
					if (cmd->num_of_args == 0)
					{
						cprintf("FOS> %s\n", cmd->name);
						return cmd->function_to_execute(number_of_arguments, arguments);
					}
					else
					{
						cprintf("%s: %s\n", cmd->name, cmd->description);
						return 0;
					}
				}
			}
		}
	}
	else
	{
		return commands[ret].function_to_execute(number_of_arguments, arguments);
	}
	return 0;
}


int process_command(int number_of_arguments, char** arguments)
{
	for (int i = 0; i < NUM_OF_COMMANDS; i++)
	{
		if (strcmp(arguments[0], commands[i].name) == 0)
		{
			return i;
		}
	}
	return CMD_INVALID;
}
