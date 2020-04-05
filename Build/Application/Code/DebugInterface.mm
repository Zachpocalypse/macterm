/*!	\file DebugInterface.mm
	\brief Cocoa implementation of the Debugging panel.
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

#import "DebugInterface.h"

// Mac includes
#import <Cocoa/Cocoa.h>

// library includes
#import <Console.h>
#import <SoundSystem.h>
#import <XPCCallPythonClient.objc++.h>

// application includes
#import "Session.h"
#import "SessionFactory.h"
#import "Terminal.h"



#pragma mark Variables

Boolean		gDebugInterface_LogsDeviceState = false;
Boolean		gDebugInterface_LogsSixelDecoderState = false;
Boolean		gDebugInterface_LogsTerminalInputChar = false;
Boolean		gDebugInterface_LogsTerminalEcho = false;
Boolean		gDebugInterface_LogsTerminalState = false;



#pragma mark Public Methods

/*!
Shows the Debugging panel.

(4.0)
*/
void
DebugInterface_Display ()
{
@autoreleasepool {
	[[DebugInterface_PanelController sharedDebugInterfacePanelController] showWindow:NSApp];
}// @autoreleasepool
}// Display


#pragma mark Internal Methods

#pragma mark -
@implementation DebugInterface_PanelController


static DebugInterface_PanelController*	gDebugInterface_PanelController = nil;
static TerminalToolbar_Window*			gDebugInterface_ToolbarWindow = nil;
static NSWindowController*				gDebugInterface_ToolbarWindowController = nil;


/*!
Returns the singleton.

(4.0)
*/
+ (id)
sharedDebugInterfacePanelController
{
	static dispatch_once_t		onceToken;
	
	
	dispatch_once(&onceToken,
	^{
		gDebugInterface_PanelController = [[self.class allocWithZone:NULL] init];
	});
	return gDebugInterface_PanelController;
}// sharedDebugInterfacePanelController


/*!
Designated initializer.

(4.0)
*/
- (instancetype)
init
{
	self = [super initWithWindowNibName:@"DebugInterfaceCocoa"];
	return self;
}// init


/*!
Prints information to the console on the current state of
the active terminal; for example, whether it is in insert
or replace mode.

(4.0)
*/
- (IBAction)
dumpStateOfActiveTerminal:(id)	sender
{
#pragma unused(sender)
	SessionRef			activeSession = nullptr;
	TerminalWindowRef	activeTerminalWindow = nullptr;
	TerminalScreenRef	activeScreen = nullptr;
	
	
	Console_WriteLine("");
	Console_WriteHorizontalRule();
	Console_WriteLine("Report on active window:");
	{
		Console_BlockIndent		_;
		
		
		Console_WriteLine("Session");
		{
			Console_BlockIndent		_2;
			
			
			activeSession = SessionFactory_ReturnUserRecentSession();
			
			if (nullptr == activeSession)
			{
				Sound_StandardAlert();
				Console_WriteLine("There is no active session.");
			}
			else
			{
				Console_WriteLine("No debugging information has been defined.");
			}
		}
		Console_WriteLine("Terminal Window");
		{
			Console_BlockIndent		_2;
			
			
			if (nullptr != activeSession)
			{
				activeTerminalWindow = Session_ReturnActiveTerminalWindow(activeSession);
			}
			
			if (nullptr == activeTerminalWindow)
			{
				Sound_StandardAlert();
				Console_WriteLine("The active session has no terminal window.");
			}
			else
			{
				Console_WriteValue("Is hidden (obscured)", TerminalWindow_IsObscured(activeTerminalWindow));
				Console_WriteValue("Is tabbed", TerminalWindow_IsTab(activeTerminalWindow));
			}
		}
		Console_WriteLine("Terminal Screen Buffer");
		{
			Console_BlockIndent		_2;
			
			
			if (nullptr != activeTerminalWindow)
			{
				activeScreen = TerminalWindow_ReturnScreenWithFocus(activeTerminalWindow);
			}
			
			if (nullptr == activeScreen)
			{
				Sound_StandardAlert();
				Console_WriteLine("The active session has no focused terminal screen.");
			}
			else
			{
				Terminal_DebugDumpDetailedSnapshot(activeScreen);
			}
		}
	}
	Console_WriteLine("End of active terminal report.");
	Console_WriteHorizontalRule();
}// dumpStateOfActiveTerminal:


/*!
Spawns a new instance of the subprocess that wraps calls to
external Python callbacks.

(4.1)
*/
- (void)
launchNewCallPythonClient:(id)	sender
{
#pragma unused(sender)
	NSXPCConnection*	connectionObject = [[NSXPCConnection alloc] initWithServiceName:@"net.macterm.helpers.CallPythonClient"];
	NSXPCInterface*		interfaceObject = [NSXPCInterface interfaceWithProtocol:@protocol(XPCCallPythonClient_RemoteObjectInterface)];
	
	
	connectionObject.interruptionHandler = ^{ NSLog(@"call-Python client connection interrupted"); };
	connectionObject.invalidationHandler = ^{ NSLog(@"call-Python client connection invalidated"); };
	connectionObject.remoteObjectInterface = interfaceObject;
	[connectionObject resume];
	
	NSLog(@"created call-Python client object: %@", connectionObject);
	
	id		remoteProxy = [connectionObject remoteObjectProxyWithErrorHandler:^(NSError* error){
												NSLog(@"remote object proxy error: %@", [error localizedDescription]);
											}];
	
	
	if (nil != remoteProxy)
	{
		id< XPCCallPythonClient_RemoteObjectInterface >		asInterface = remoteProxy;
		
		
		[asInterface xpcServiceSendMessage:@"hello!" withReply:^(NSString* aReplyString){
			NSLog(@"MacTerm received response from Python client: %@", aReplyString);
		}];
	}
	// TEMPORARY (INCOMPLETE)
}// launchNewCallPythonClient:


/*!
Displays a Cocoa-based terminal toolbar window.

(4.0)
*/
- (IBAction)
showTestTerminalToolbar:(id)	sender
{
	if (nil == gDebugInterface_ToolbarWindow)
	{
		NSRect		newRect = NSMakeRect(0, 0, [[NSScreen mainScreen] visibleFrame].size.width, 0);
		
		
		gDebugInterface_ToolbarWindow = [[TerminalToolbar_Window alloc]
											initWithContentRect:newRect
																styleMask:(NSTitledWindowMask | NSUtilityWindowMask | NSClosableWindowMask |
																			NSMiniaturizableWindowMask)
																backing:NSBackingStoreBuffered
																defer:YES];
	}
	if (nil == gDebugInterface_ToolbarWindowController)
	{
		gDebugInterface_ToolbarWindowController = [[NSWindowController alloc] initWithWindow:gDebugInterface_ToolbarWindow];
	}
	[gDebugInterface_ToolbarWindow makeKeyAndOrderFront:sender];
}// showTestTerminalToolbar:


#pragma mark Accessors


/*!
Accessor.

(2017.12)
*/
- (BOOL)
logsSixelDecoderState
{
	return gDebugInterface_LogsSixelDecoderState;
}
- (void)
setLogsSixelDecoderState:(BOOL)		aFlag
{
	if (aFlag != gDebugInterface_LogsSixelDecoderState)
	{
		if (aFlag)
		{
			Console_WriteLine("started logging of SIXEL decoder state");
		}
		else
		{
			Console_WriteLine("stopped logging of SIXEL decoder state");
		}
		
		gDebugInterface_LogsSixelDecoderState = aFlag;
	}
}// setLogsSixelDecoderState:


/*!
Accessor.

(4.0)
*/
- (BOOL)
logsTerminalInputChar
{
	return gDebugInterface_LogsTerminalInputChar;
}
- (void)
setLogsTerminalInputChar:(BOOL)		aFlag
{
	if (aFlag != gDebugInterface_LogsTerminalInputChar)
	{
		if (aFlag)
		{
			Console_WriteLine("started logging of terminal input characters");
		}
		else
		{
			Console_WriteLine("stopped logging of terminal input characters");
		}
		
		gDebugInterface_LogsTerminalInputChar = aFlag;
	}
}// setLogsTerminalInputChar:


/*!
Accessor.

(4.0)
*/
- (BOOL)
logsTeletypewriterState
{
	return gDebugInterface_LogsDeviceState;
}
- (void)
setLogsTeletypewriterState:(BOOL)	aFlag
{
	if (aFlag != gDebugInterface_LogsDeviceState)
	{
		if (aFlag)
		{
			Console_WriteLine("started logging of pseudo-terminal device configurations");
		}
		else
		{
			Console_WriteLine("stopped logging of pseudo-terminal device configurations");
		}
		
		gDebugInterface_LogsDeviceState = aFlag;
	}
}// setLogsTeletypewriterState:


/*!
Accessor.

(2016.12)
*/
- (BOOL)
logsTerminalEcho
{
	return gDebugInterface_LogsTerminalEcho;
}
- (void)
setLogsTerminalEcho:(BOOL)		aFlag
{
	if (aFlag != gDebugInterface_LogsTerminalEcho)
	{
		if (aFlag)
		{
			Console_WriteLine("started logging of terminal state (echo)");
		}
		else
		{
			Console_WriteLine("stopped logging of terminal state (echo)");
		}
		
		gDebugInterface_LogsTerminalEcho = aFlag;
	}
}// setLogsTerminalEcho:


/*!
Accessor.

(4.0)
*/
- (BOOL)
logsTerminalState
{
	return gDebugInterface_LogsTerminalState;
}
- (void)
setLogsTerminalState:(BOOL)		aFlag
{
	if (aFlag != gDebugInterface_LogsTerminalState)
	{
		if (aFlag)
		{
			Console_WriteLine("started logging of terminal state (except echo)");
		}
		else
		{
			Console_WriteLine("stopped logging of terminal state (except echo)");
		}
		
		gDebugInterface_LogsTerminalState = aFlag;
	}
}// setLogsTerminalState:


#pragma mark NSWindowController


/*!
Affects the preferences key under which window position
and size information are automatically saved and
restored.

(4.0)
*/
- (NSString*)
windowFrameAutosaveName
{
	// NOTE: do not ever change this, it would only cause existing
	// user settings to be forgotten
	return @"Debugging";
}// windowFrameAutosaveName


@end // DebugInterface_PanelController

// BELOW IS REQUIRED NEWLINE TO END FILE
