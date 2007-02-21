/*!	\file Local.h
	\brief UNIX-based routines for running local command-line
	programs on Mac OS X only, routing the data through some
	MacTelnet terminal window.
*/
/*###############################################################

	MacTelnet
		� 1998-2006 by Kevin Grant.
		� 2001-2003 by Ian Anderson.
		� 1986-1994 University of Illinois Board of Trustees
		(see About box for full list of U of I contributors).
	
	This program is free software; you can redistribute it or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version
	2 of the License, or (at your option) any later version.
	
	This program is distributed in the hope that it will be
	useful, but WITHOUT ANY WARRANTY; without even the implied
	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
	PURPOSE.  See the GNU General Public License for more
	details.
	
	You should have received a copy of the GNU General Public
	License along with this program; if not, write to:
	
		Free Software Foundation, Inc.
		59 Temple Place, Suite 330
		Boston, MA  02111-1307
		USA

###############################################################*/

#include "UniversalDefines.h"

#ifndef __LOCAL__
#define __LOCAL__

// this is only possible on Mac OS X!!!
#if TARGET_API_MAC_CARBON

// UNIX includes
extern "C"
{
#	include <sys/types.h>
}

// MacTelnet includes
#include "SessionRef.typedef.h"
#include "TerminalScreenRef.typedef.h"



#pragma mark Constants

/*!
Possible return values from Local module routines.
*/
typedef long LocalResultCode;
enum
{
	kLocalResultCodeSuccess					= 0,	//!< no error
	kLocalResultCodeParameterError			= 1,	//!< invalid input (e.g. null pointer provided)
	kLocalResultCodeForkError				= 2,	//!< fork() failed
	kLocalResultCodeThreadError				= 3,	//!< unable to create a thread
	kLocalResultCodeIOControlError			= 4,	//!< ioctl() failed
	kLocalResultCodeTermCapError			= 5,	//!< terminal capabilities interface routine failed
	kLocalResultCodeSocketError				= 6,	//!< if a socket could not be created
	kLocalResultCodeNoRouteToHost			= 7,	//!< if a physical connection could not be made
	kLocalResultCodeConnectionRefused		= 8,	//!< if a connection was not allowed by the server
	kLocalResultCodeCannotResolveAtAll		= 9,	//!< if a host name was given whose address cannot be found
	kLocalResultCodeCannotResolveForNow		= 10,	//!< if an address cannot be found, but a retry might find it
	kLocalResultInsufficientBufferSpace		= 11	//!< out of memory; free more memory and try again
};

/*!
TTY-related routines may return this invalid ID to
indicate an error.
*/
enum
{
	kInvalidPseudoTeletypewriterID		= -1
};

#pragma mark Types

typedef int/* file descriptor */		PseudoTeletypewriterID;



#pragma mark Public Methods

LocalResultCode
	Local_InstallCrashCatcher				();

//!\name Creating Pseudo-Terminals
//@{

LocalResultCode
	Local_GetDefaultShell					(char**						outStringPtr);

int
	Local_GetTerminalFlowStartCharacter		(PseudoTeletypewriterID		inPseudoTerminalID);

int
	Local_GetTerminalFlowStopCharacter		(PseudoTeletypewriterID		inPseudoTerminalID);

int
	Local_GetTerminalInterruptCharacter		(PseudoTeletypewriterID		inPseudoTerminalID);

void
	Local_KillProcess						(pid_t						inUnixProcessID);

LocalResultCode
	Local_SpawnDefaultShell					(SessionRef					inUninitializedSession,
											 TerminalScreenRef			inContainer,
											 pid_t*						outProcessIDPtr,
											 char*						outSlaveName);

LocalResultCode
	Local_SpawnLoginShell					(SessionRef					inUninitializedSession,
											 TerminalScreenRef			inContainer,
											 pid_t*						outProcessIDPtr,
											 char*						outSlaveName);

LocalResultCode
	Local_SpawnProcess						(SessionRef					inUninitializedSession,
											 TerminalScreenRef			inContainer,
											 char const* const			argv[],
											 pid_t*						outProcessIDPtr,
											 char*						outSlaveName);

LocalResultCode
	Local_SpawnProcessAndWaitForTermination	(char const*				inCommand);

Boolean
	Local_StandardInputIsATerminal			();

//@}

//!\name Manipulating Pseudo-Terminals
//@{

int
	Local_DisableTerminalLocalEcho			(PseudoTeletypewriterID		inPseudoTerminalID);

LocalResultCode
	Local_SendTerminalResizeMessage			(PseudoTeletypewriterID		inPseudoTerminalID,
											 UInt16						inNewColumnCount,
											 UInt16						inNewRowCount,
											 UInt16						inNewColumnWidthInPixels,
											 UInt16						inNewRowHeightInPixels);

extern "C"
{
ssize_t
	Local_WriteBytes						(PseudoTeletypewriterID		inFileDescriptor,
											 void const*				inBufferPtr,
											 size_t						inByteCount);
}

//@}

#endif

#endif

// BELOW IS REQUIRED NEWLINE TO END FILE
