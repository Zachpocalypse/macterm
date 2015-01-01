/*!	\file EventLoop.h
	\brief Interface to input device and application events.
	
	The majority of this module is now deprecated, as the code
	base no longer directly supports anything but Mac OS X.  The
	previous capabilities can be implemented directly with
	Carbon and Cocoa.
*/
/*###############################################################

	MacTerm
		© 1998-2015 by Kevin Grant.
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

#ifndef __EVENTLOOP__
#define __EVENTLOOP__

// Mac includes
#include <Carbon/Carbon.h>

// library includes
#include <ListenerModel.h>

// application includes
#include "ConstantsRegistry.h"



#pragma mark Constants

/*!
Possible return values from Event Loop module routines.
*/
typedef OSStatus EventLoop_Result;
enum
{
	kEventLoop_ResultOK							= 0,	//!< no error
	kEventLoop_ResultBooleanListenerRequired	= 1		//!< ListenerModel_NewBooleanListener() was not used to create the
														//!  ListenerModel_ListenerRef for a callback
};

/*!
Events that MacTerm allows other modules to “listen” for, via EventLoop_StartMonitoring().
*/
typedef FourCharCode EventLoop_GlobalEvent;
enum
{
	kEventLoop_GlobalEventSuspendResume					= 'Swch',	//!< the current process is either about to become the active
																	//!  process, or about to become inactive (context: nullptr)
	kEventLoop_GlobalEventFullScreenDidBegin			= 'FSDB',	//!< a terminal has entered Full Screen (context: TerminalWindowRef)
	kEventLoop_GlobalEventFullScreenWillEnd				= 'FSWE'	//!< a terminal is about to exit Full Screen (context: TerminalWindowRef)
};



#pragma mark Public Methods

//!\name Initialization
//@{

EventLoop_Result
	EventLoop_Init								();

void
	EventLoop_Done								();

//@}

//!\name Running the Event Loop
//@{

void
	EventLoop_Run								();

//@}

//!\name Manual Handling of Events
//@{

// DEPRECATED
EventLoop_Result
	EventLoop_StartMonitoring					(EventLoop_GlobalEvent				inForWhatEvent,
												 ListenerModel_ListenerRef			inListener);

// DEPRECATED
EventLoop_Result
	EventLoop_StopMonitoring					(EventLoop_GlobalEvent				inForWhatEvent,
												 ListenerModel_ListenerRef			inListener);

void
	EventLoop_SendFullScreenWindowEvent			(EventLoop_GlobalEvent				inEvent,
												 void*								inEventContext);

//@}

//!\name Responding to Events
//@{

// DEPRECATED
Boolean
	EventLoop_HandleColorPickerUpdate			(EventRecord*						inoutEventPtr);

// DEPRECATED
void
	EventLoop_HandleNavigationUpdate			(NavEventCallbackMessage			inMessage,
												 NavCBRecPtr						inParameters,
												 NavCallBackUserData				inUserData);

//@}

//!\name Announcing Event Occurrences from External Sources
//@{

// DEPRECATED
void
	EventLoop_HandleZoomEvent					(WindowRef							inWindow);

// DEPRECATED
void
	EventLoop_SelectBehindDialogWindows			(WindowRef							inWindowToSelect);

// DEPRECATED
void
	EventLoop_SelectOverRealFrontWindow			(WindowRef							inWindowToSelect);

//@}

//!\name Scanning the Queue for Still-Unhandled Events
//@{

// DEPRECATED
Boolean
	EventLoop_IsNextDoubleClick					(HIWindowRef						inEventWindow,
												 Point&								outGlobalMouseLocation);

//@}

//!\name Keyboard State Information
//@{

Boolean
	EventLoop_IsCapsLockKeyDown					();

Boolean
	EventLoop_IsCommandKeyDown					();

Boolean
	EventLoop_IsControlKeyDown					();

Boolean
	EventLoop_IsOptionKeyDown					();

Boolean
	EventLoop_IsShiftKeyDown					();

Boolean
	EventLoop_KeyIsActivatingCancelButton		(EventRef	inEvent);

Boolean
	EventLoop_KeyIsActivatingDefaultButton		(EventRef	inEvent);

// FAVOR EVENT-SPECIFIC KEY STATE INFORMATION IF IT IS AVAILABLE
EventModifiers
	EventLoop_ReturnCurrentModifiers			();

//@}

//!\name Miscellaneous
//@{

// DEPRECATED
WindowRef
	EventLoop_ReturnRealFrontWindow				();

//@}

#endif

// BELOW IS REQUIRED NEWLINE TO END FILE
