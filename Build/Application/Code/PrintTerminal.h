/*!	\file PrintTerminal.h
	\brief The new Mac OS X native printing mechanism for
	terminal views in MacTerm.
*/
/*###############################################################

	MacTerm
		© 1998-2021 by Kevin Grant.
		© 2001-2003 by Ian Anderson.
		© 1986-1994 University of Illinois Board of Trustees
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

#include <UniversalDefines.h>

#pragma once

// Mac includes
#ifdef __OBJC__
@class NSWindow;
#else
class NSWindow;
#endif
#include <CoreServices/CoreServices.h>

// application includes
#include "TerminalScreenRef.typedef.h"
#include "TerminalViewRef.typedef.h"



#pragma mark Constants

/*!
Possible return values from certain APIs in this module.
*/
enum PrintTerminal_Result
{
	kPrintTerminal_ResultOK = 0,				//!< no error
	kPrintTerminal_ResultInvalidID = -1,		//!< a given "PrintTerminal_JobRef" does not correspond to any known object
	kPrintTerminal_ResultParameterError = -2,	//!< invalid input (e.g. a null pointer)
};

#pragma mark Types

typedef struct PrintTerminal_OpaqueJob*		PrintTerminal_JobRef;



#pragma mark Public Methods

//!\name Creating and Destroying Objects
//@{

PrintTerminal_JobRef
	PrintTerminal_NewJobFromFile			(CFURLRef					inFile,
											 TerminalViewRef			inView,
											 CFStringRef				inJobName,
											 Boolean					inDefaultToLandscape = false);

PrintTerminal_JobRef
	PrintTerminal_NewJobFromSelectedText	(TerminalViewRef			inView,
											 CFStringRef				inJobName,
											 Boolean					inDefaultToLandscape = false);

PrintTerminal_JobRef
	PrintTerminal_NewJobFromVisibleScreen	(TerminalViewRef			inView,
											 TerminalScreenRef			inViewBuffer,
											 CFStringRef				inJobName);

void
	PrintTerminal_ReleaseJob				(PrintTerminal_JobRef*		inoutJobPtr);

//@}

//!\name Printing
//@{

PrintTerminal_Result
	PrintTerminal_JobSendToPrinter			(PrintTerminal_JobRef		inJob,
											 NSWindow*					inParentWindowOrNil);

//@}

// BELOW IS REQUIRED NEWLINE TO END FILE
