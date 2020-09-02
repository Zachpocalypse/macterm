/*!	\file DebugInterface.h
	\brief Implements a utility window for enabling certain
	debugging features.
*/
/*###############################################################

	MacTerm
		© 1998-2020 by Kevin Grant.
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



#pragma mark Public Methods

void
	DebugInterface_Display					();

Boolean
	DebugInterface_LogsSixelDecoderState	();

Boolean
	DebugInterface_LogsSixelInput			();

Boolean
	DebugInterface_LogsTerminalInputChar	();

Boolean
	DebugInterface_LogsTeletypewriterState	();

Boolean
	DebugInterface_LogsTerminalEcho			();

Boolean
	DebugInterface_LogsTerminalState		();

// BELOW IS REQUIRED NEWLINE TO END FILE
