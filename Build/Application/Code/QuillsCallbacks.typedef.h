/*!	\file QuillsCallbacks.typedef.h
	\brief Useful type definitions used by anything that
	supports Python callbacks.
*/
/*###############################################################

	MacTelnet
		� 1998-2008 by Kevin Grant.
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

#ifndef __QUILLSCALLBACKS_TYPEDEF__
#define __QUILLSCALLBACKS_TYPEDEF__

// standard-C++ includes
#include <string>



#pragma mark Types
namespace Quills {

// for callbacks, the first "void*" argument is required for
// storing an object and is irrelevant from a Python signature
// point of view (i.e. a single "void*" argument is like taking
// no Python arguments at all)
typedef std::string (*FunctionReturnStringArg1VoidPtrArg2CharPtr) (void*, char*);
typedef void (*FunctionReturnVoidArg1VoidPtrArg2CharPtr) (void*, char*);
typedef void (*FunctionReturnVoidArg1VoidPtr) (void*);

} // namespace Quills

#endif

// BELOW IS REQUIRED NEWLINE TO END FILE
