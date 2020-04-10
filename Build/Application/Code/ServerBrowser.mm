/*!	\file ServerBrowser.mm
	\brief Cocoa implementation of a panel for finding
	or specifying servers for a variety of protocols.
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

#import "ServerBrowser.h"

// Mac includes
#import <Cocoa/Cocoa.h>
#import <objc/objc-runtime.h>

// Unix includes
extern "C"
{
#	include <netdb.h>
#	include <arpa/inet.h>
#	include <netinet/in.h>
}

// library includes
#import <BoundName.objc++.h>
#import <CocoaBasic.h>
#import <CocoaExtensions.objc++.h>
#import <Console.h>
#import <MemoryBlocks.h>
#import <Popover.objc++.h>
#import <PopoverManager.objc++.h>
#import <SoundSystem.h>

// application includes
#import "AlertMessages.h"
#import "Commands.h"
#import "ConstantsRegistry.h"
#import "DNR.h"
#import "Session.h"



#pragma mark Types

/*!
Manages the Server Browser user interface.
*/
@interface ServerBrowser_Handler : NSObject< NSWindowDelegate, PopoverManager_Delegate,
												ServerBrowser_VCDelegate > //{
{
	ServerBrowser_Ref			_selfRef;					// identical to address of structure, but typed as ref
	ServerBrowser_VC*			_viewMgr;					// loads the server browser interface
	Popover_Window*				_containerWindow;			// holds the main view
	NSView*						_managedView;				// the view that implements the majority of the interface
	NSWindow*					_parentWindow;				// the Cocoa window that the point is relative to
	CGPoint						_parentRelativeArrowTip;	// the point relative to the parent window where the popover arrow appears
	id< ServerBrowser_DataChangeObserver >	_dataObserver;	// object that is notified about key property changes
	Session_Protocol			_initialProtocol;			// used to initialize the view when it loads
	NSString*					_initialHostName;			// used to initialize the view when it loads
	unsigned int				_initialPortNumber;			// used to initialize the view when it loads
	NSString*					_initialUserID;				// used to initialize the view when it loads
	PopoverManager_Ref			_popoverMgr;				// manages common aspects of popover window behavior
}

// class methods
	+ (ServerBrowser_Handler*)
	viewHandlerFromRef:(ServerBrowser_Ref)_;

// initializers
	- (instancetype)
	init DISABLED_SUPERCLASS_DESIGNATED_INITIALIZER;
	- (instancetype)
	initWithPosition:(CGPoint)_
	relativeToParentWindow:(NSWindow*)_
	dataObserver:(id< ServerBrowser_DataChangeObserver >)_ NS_DESIGNATED_INITIALIZER;

// new methods
	- (void)
	configureWithProtocol:(Session_Protocol)_
	hostName:(NSString*)_
	portNumber:(unsigned int)_
	userID:(NSString*)_;
	- (void)
	display;
	- (void)
	remove;

// accessors
	@property (assign, readonly) NSWindow*
	parentCocoaWindow;

// PopoverManager_Delegate
	// (undeclared)

// ServerBrowser_VCDelegate
	// (undeclared)

@end //}


/*!
Implements an object wrapper for NSNetService instances returned
by Bonjour, that allows them to be easily inserted into user
interface elements without losing less user-friendly information
about each service.
*/
@interface ServerBrowser_NetService : NSObject< NSNetServiceDelegate > //{
{
@private
	NSNetService*		_netService;
	unsigned char		_addressFamily; // AF_INET or AF_INET6
	NSString*			_bestResolvedAddress;
	unsigned short		_bestResolvedPort;
}

// initializersbestResolvedPort
	- (instancetype)
	initWithNetService:(NSNetService*)_
	addressFamily:(unsigned char)_;

// accessors; see "Discovered Hosts" array controller in the NIB, for key names
	@property (strong) NSString*
	bestResolvedAddress;
	@property (assign) unsigned short
	bestResolvedPort;
	- (NSString*)
	description;
	@property (strong, readonly) NSNetService*
	netService;

@end //}


/*!
Implements an object wrapper for protocol definitions, that
allows them to be easily inserted into user interface elements
without losing less user-friendly information about each
protocol.
*/
@interface ServerBrowser_Protocol : BoundName_Object //{
{
@private
	Session_Protocol	_protocolID;
	NSString*			_serviceType; // RFC 2782 / Bonjour, e.g. "_xyz._tcp."
	unsigned short		_defaultPort;
}

// accessors; see "Protocol Definitions" array controller in the NIB, for key names
	@property (assign) unsigned short
	defaultPort;
	@property (assign) Session_Protocol
	protocolID;
	@property (copy) NSString*
	serviceType;

// initializers
	- (instancetype)
	initWithID:(Session_Protocol)_
	description:(NSString*)_
	serviceType:(NSString*)_
	defaultPort:(unsigned short)_;

@end //}


/*!
The private class interface.
*/
@interface ServerBrowser_VC (ServerBrowser_VCInternal) //{

	- (void)
	didDoubleClickDiscoveredHostWithSelection:(NSArray*)_;
	- (ServerBrowser_NetService*)
	discoveredHost;
	- (void)
	notifyOfChangeInValueReturnedBy:(SEL)_;
	- (ServerBrowser_Protocol*)
	protocol;
	- (void)
	serverBrowserWindowWillClose:(NSNotification*)_;

@end //}



#pragma mark Public Methods

/*!
Constructs a server browser as a popover that points to the given
location in the parent window.  Use ServerBrowser_Display() to
show the popover.  Use ServerBrowser_Configure() beforehand to set
the various fields in the interface.

Note that the initial position is expressed in window coordinates
(top zero, left zero), not Cartesian (Cocoa) coordinates.

(4.1)
*/
ServerBrowser_Ref
ServerBrowser_New	(NSWindow*									inParentWindow,
					 CGPoint									inParentRelativePoint,
					 id< ServerBrowser_DataChangeObserver >		inDataObserver)
{
	ServerBrowser_Ref	result = nullptr;
	
	
	// WARNING: this interpretation should match "viewHandlerFromRef:"
	result = (ServerBrowser_Ref)[[ServerBrowser_Handler alloc] initWithPosition:inParentRelativePoint
																				relativeToParentWindow:inParentWindow
																				dataObserver:inDataObserver];
	
	return result;
}// New


/*!
Releases the server browser and sets your copy of
the reference to nullptr.

(4.0)
*/
void
ServerBrowser_Dispose	(ServerBrowser_Ref*		inoutDialogPtr)
{
	ServerBrowser_Handler*	ptr = [ServerBrowser_Handler viewHandlerFromRef:*inoutDialogPtr];
	
	
	[ptr release];
	*inoutDialogPtr = nullptr;
}// Dispose


/*!
Fills in the fields of the interface with the given values.
This should be done before calling ServerBrowser_Display().
It allows you to reuse a browser for multiple data sources.

(4.0)
*/
void
ServerBrowser_Configure		(ServerBrowser_Ref		inDialog,
							 Session_Protocol		inProtocol,
							 CFStringRef			inHostName,
							 UInt16					inPortNumber,
							 CFStringRef			inUserID)
{
	ServerBrowser_Handler*		ptr = [ServerBrowser_Handler viewHandlerFromRef:inDialog];
	
	
	[ptr configureWithProtocol:inProtocol hostName:(NSString*)inHostName portNumber:inPortNumber
								userID:(NSString*)inUserID];
}// Configure


/*!
Shows the server browser, pointing at the target view
that was given at construction time.

(4.0)
*/
void
ServerBrowser_Display	(ServerBrowser_Ref		inDialog)
{
	ServerBrowser_Handler*		ptr = [ServerBrowser_Handler viewHandlerFromRef:inDialog];
	
	
	if (nullptr == ptr)
	{
		Sound_StandardAlert(); // TEMPORARY (display alert message?)
	}
	else
	{
		// load the view asynchronously and eventually display it in a window
		[ptr display];
	}
}// Display


/*!
Hides the server browser.  It can be redisplayed at any
time by calling ServerBrowser_Display() again.

(4.0)
*/
void
ServerBrowser_Remove	(ServerBrowser_Ref		inDialog)
{
	ServerBrowser_Handler*		ptr = [ServerBrowser_Handler viewHandlerFromRef:inDialog];
	
	
	[ptr remove];
}// Remove


#pragma mark -
@implementation ServerBrowser_Handler


/*!
Converts from the opaque reference type to the internal type.

(4.0)
*/
+ (ServerBrowser_Handler*)
viewHandlerFromRef:(ServerBrowser_Ref)		aRef
{
	return REINTERPRET_CAST(aRef, ServerBrowser_Handler*);
}// viewHandlerFromRef


/*!
Designated initializer from base class.  Do not use;
it is defined only to satisfy the compiler.

(2017.06)
*/
- (instancetype)
init
{
	assert(false && "invalid way to initialize derived class");
	return [self initWithPosition:CGPointZero relativeToParentWindow:nil dataObserver:nil];
}// init


/*!
Designated initializer.

(4.1)
*/
- (instancetype)
initWithPosition:(CGPoint)								aPoint
relativeToParentWindow:(NSWindow*)						aWindow
dataObserver:(id< ServerBrowser_DataChangeObserver >)	anObserver
{
	self = [super init];
	if (nil != self)
	{
		_selfRef = REINTERPRET_CAST(self, ServerBrowser_Ref);
		_viewMgr = nil;
		_containerWindow = nil;
		_managedView = nil;
		_parentWindow = aWindow;
		_parentRelativeArrowTip = aPoint;
		_dataObserver = anObserver;
		_initialProtocol = kSession_ProtocolSSH1;
		_initialHostName = [@"" retain];
		_initialPortNumber = 22;
		_initialUserID = [@"" retain];
		_popoverMgr = nullptr;
	}
	return self;
}// initWithPosition:relativeToParentWindow:dataObserver:


/*!
Destructor.

(4.0)
*/
- (void)
dealloc
{
	Memory_EraseWeakReferences(self);
	[_managedView release];
	[_viewMgr release];
	[_initialHostName release];
	[_initialUserID release];
	if (nullptr != _popoverMgr)
	{
		PopoverManager_Dispose(&_popoverMgr);
	}
	[super dealloc];
}// dealloc


/*!
Specifies the initial values for the user interface.  This is
typically done just before calling "display".

(4.0)
*/
- (void)
configureWithProtocol:(Session_Protocol)	aProtocol
hostName:(NSString*)						aHostName
portNumber:(unsigned int)					aPortNumber
userID:(NSString*)							aUserID
{
	_initialProtocol = aProtocol;
	_initialHostName = [aHostName retain];
	_initialPortNumber = aPortNumber;
	_initialUserID = [aUserID retain];
}// configureWithProtocol:hostName:portNumber:userID:


/*!
Creates the server browser view asynchronously; when the view
is ready, it calls "serverBrowser:didLoadManagedView:".

(4.0)
*/
- (void)
display
{
	if (nil == _viewMgr)
	{
		// no focus is done the first time because this is
		// eventually done in "serverBrowser:didLoadManagedView:"
		_viewMgr = [[ServerBrowser_VC alloc] initWithResponder:self dataObserver:_dataObserver];
	}
	else
	{
		// window is already loaded, just activate it (but also initialize
		// again, to mimic initialization performed in the “create new” case)
		[_viewMgr setProtocolIndexByProtocol:_initialProtocol];
		[_viewMgr setHostName:_initialHostName];
		[_viewMgr setPortNumber:[NSString stringWithFormat:@"%d", _initialPortNumber]];
		[_viewMgr setUserID:_initialUserID];
		PopoverManager_DisplayPopover(_popoverMgr);
	}
}// display


/*!
Hides the popover.  It can be shown again at any time
using the "display" method.

(4.0)
*/
- (void)
remove
{
	if (nil != _popoverMgr)
	{
		PopoverManager_RemovePopover(_popoverMgr, true/* is confirming */);
	}
}// remove


/*!
Returns the Cocoa window that represents the parent
of the target view.

(4.0)
*/
- (NSWindow*)
parentCocoaWindow
{
	NSWindow*	result = self->_parentWindow;
	
	
	return result;
}// parentCocoaWindow


#pragma mark NSWindowDelegate


/*!
Returns the appropriate animation rectangle for the
given sheet.

(4.0)
*/
- (NSRect)
window:(NSWindow*)				window
willPositionSheet:(NSWindow*)	sheet
usingRect:(NSRect)				rect
{
#pragma unused(window, sheet)
	NSRect		result = rect;
	NSRect		someFrame = [_containerWindow frameRectForViewSize:NSZeroSize];
	
	
	// move an arbitrary distance away from the top edge
	result.origin.y -= 1;
	
	// also offset further using the view position as a clue (namely, if the arrow is on top the sheet moves further)
	result.origin.y -= (someFrame.origin.y + someFrame.size.height);
	
	// the meaning of the height is undefined, so make it zero
	result.size.height = 0;
	
	// force the fold-out animation, which seems to look better with popovers
	result.size.width -= 200;
	result.origin.x += 100;
	
	return result;
}// window:willPositionSheet:usingRect:


#pragma mark PopoverManager_Delegate


/*!
Assists the dynamic resize of a popover window by indicating
whether or not there are per-axis constraints on resizing.

(2017.05)
*/
- (void)
popoverManager:(PopoverManager_Ref)		aPopoverManager
getHorizontalResizeAllowed:(BOOL*)		outHorizontalFlagPtr
getVerticalResizeAllowed:(BOOL*)		outVerticalFlagPtr
{
#pragma unused(aPopoverManager)
	*outHorizontalFlagPtr = YES;
	//*outVerticalFlagPtr = NO;
	*outVerticalFlagPtr = YES;
}// popoverManager:getHorizontalResizeAllowed:getVerticalResizeAllowed:


/*!
Returns the initial view size for the popover.

(2017.05)
*/
- (void)
popoverManager:(PopoverManager_Ref)		aPopoverManager
getIdealSize:(NSSize*)					outSizePtr
{
#pragma unused(aPopoverManager)
	*outSizePtr = [_managedView frame].size;
}// popoverManager:getIdealSize:


/*!
Returns the location (relative to the window) where the
popover’s arrow tip should appear.  The location of the
popover itself depends on the arrow placement chosen by
"idealArrowPositionForFrame:parentWindow:".

(4.0)
*/
- (NSPoint)
popoverManager:(PopoverManager_Ref)		aPopoverManager
idealAnchorPointForFrame:(NSRect)		parentFrame
parentWindow:(NSWindow*)				parentWindow
{
#pragma unused(aPopoverManager, parentFrame, parentWindow)
	NSPoint		result = NSMakePoint(_parentRelativeArrowTip.x, _parentRelativeArrowTip.y);
	
	
	return result;
}// popoverManager:idealAnchorPointForFrame:parentWindow:


/*!
Returns arrow placement information for the popover.

(4.0)
*/
- (Popover_Properties)
popoverManager:(PopoverManager_Ref)		aPopoverManager
idealArrowPositionForFrame:(NSRect)		parentFrame
parentWindow:(NSWindow*)				parentWindow
{
#pragma unused(aPopoverManager, parentFrame, parentWindow)
	Popover_Properties	result = kPopover_PropertyArrowMiddle | kPopover_PropertyPlaceFrameBelowArrow;
	
	
	return result;
}// popoverManager:idealArrowPositionForFrame:parentWindow:


#pragma mark ServerBrowser_VCDelegate


/*!
Called when a ServerBrowser_VC has finished loading and
initializing its view; responds by displaying the view
in a window and giving it keyboard focus.

Since this may be invoked multiple times, the window is
only created during the first invocation.

(4.0)
*/
- (void)
serverBrowser:(ServerBrowser_VC*)	aBrowser
didLoadManagedView:(NSView*)		aManagedView
{
	_managedView = aManagedView;
	[_managedView retain];
	
	[aBrowser setProtocolIndexByProtocol:_initialProtocol];
	aBrowser.hostName = _initialHostName;
	aBrowser.portNumber = [NSString stringWithFormat:@"%d", _initialPortNumber];
	aBrowser.userID = _initialUserID;
	
	if (nil == _containerWindow)
	{
		_containerWindow = [[Popover_Window alloc] initWithView:aManagedView
																windowStyle:kPopover_WindowStyleNormal
																arrowStyle:kPopover_ArrowStyleDefaultRegularSize
																attachedToPoint:NSZeroPoint/* see delegate */
																inWindow:[self parentCocoaWindow]];
		[_containerWindow setDelegate:self];
		[_containerWindow setReleasedWhenClosed:NO];
		_popoverMgr = PopoverManager_New(_containerWindow, [aBrowser logicalFirstResponder],
											self/* delegate */, kPopoverManager_AnimationTypeMinimal,
											kPopoverManager_BehaviorTypeStandard,
											self.parentCocoaWindow.contentView);
		PopoverManager_DisplayPopover(_popoverMgr);
	}
}// serverBrowser:didLoadManagedView:


/*!
Responds to a close of the interface by updating
any associated interface elements (such as a button
that opened the popover in the first place).

(4.0)
*/
- (void)
serverBrowser:(ServerBrowser_VC*)		aBrowser
didFinishUsingManagedView:(NSView*)		aManagedView
{
#pragma unused(aBrowser, aManagedView)
	[_dataObserver serverBrowserDidClose:aBrowser];
}// serverBrowser:didFinishUsingManagedView:


/*!
Requests that the containing window be resized to allow the given
view size.  This is only for odd cases like a user interface
element causing part of the display to appear or disappear;
normally the window can just be manipulated directly.

(4.0)
*/
- (void)
serverBrowser:(ServerBrowser_VC*)	aBrowser
setManagedView:(NSView*)			aManagedView
toScreenFrame:(NSRect)				aRect
{
#pragma unused(aBrowser, aManagedView)
	NSRect		windowFrame = [_containerWindow frameRectForViewSize:aRect.size];
	
	
	[_containerWindow setFrame:windowFrame display:YES animate:YES];
	PopoverManager_UseIdealLocationAfterDelay(_popoverMgr, 0.1f/* arbitrary delay */);
}// serverBrowser:setManagedView:toScreenFrame:


@end // ServerBrowser_Handler


#pragma mark -
@implementation ServerBrowser_NetService


@synthesize bestResolvedAddress = _bestResolvedAddress;
@synthesize bestResolvedPort = _bestResolvedPort;
@synthesize netService = _netService;


/*!
Designated initializer.

(4.0)
*/
- (instancetype)
initWithNetService:(NSNetService*)	aNetService
addressFamily:(unsigned char)		aSocketAddrFamily
{
	self = [super init];
	if (nil != self)
	{
		_addressFamily = aSocketAddrFamily;
		_bestResolvedAddress = [[NSString string] retain];
		_bestResolvedPort = 0;
		_netService = [aNetService retain];
		_netService.delegate = self;
		[_netService resolveWithTimeout:5.0];
	}
	return self;
}// initWithNetService:addressFamily:


/*!
Destructor.

(4.0)
*/
- (void)
dealloc
{
	[_netService release];
	[_bestResolvedAddress release];
	[super dealloc];
}// dealloc


#pragma mark Accessors

/*!
Accessor.

(4.0)
*/
- (NSString*)
description
{
	return [self.netService name];
}


#pragma mark NSNetServiceDelegateMethods


/*!
Called when a discovered host name could not be mapped to
an IP address.

(4.0)
*/
- (void)
netService:(NSNetService*)		aService
didNotResolve:(NSDictionary*)	errorDict
{
	id		errorCode = [errorDict objectForKey:NSNetServicesErrorCode];
	
	
	// TEMPORARY - should a more specific error be displayed somewhere?
	NSLog(@"service %@.%@.%@ could not resolve, error code = %@",
			[aService name], [aService type], [aService domain], errorCode);
}// netService:didNotResolve:


/*!
Called when a discovered host name has been resolved to
one or more IP addresses.

(4.0)
*/
- (void)
netServiceDidResolveAddress:(NSNetService*)		resolvingService
{
	NSString*		resolvedHost = nil;
	unsigned int	resolvedPort = 0;
	
	
	//Console_WriteLine("service did resolve"); // debug
	for (NSData* addressData in [resolvingService addresses])
	{
		struct sockaddr_in*		dataPtr = (struct sockaddr_in*)[addressData bytes];
		
		
		//Console_WriteValue("found address of family", dataPtr->sin_family); // debug
		if (_addressFamily == dataPtr->sin_family)
		{
			switch (_addressFamily)
			{
			case AF_INET:
			case AF_INET6:
				{
					struct sockaddr_in*		inetDataPtr = REINTERPRET_CAST(dataPtr, struct sockaddr_in*);
					char					buffer[512];
					
					
					if (inet_ntop(_addressFamily, &inetDataPtr->sin_addr, buffer, sizeof(buffer)))
					{
						buffer[sizeof(buffer) - 1] = '\0'; // ensure termination in case of overrun
						resolvedHost = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
						resolvedPort = ntohs(inetDataPtr->sin_port);
					}
					else
					{
						Console_Warning(Console_WriteLine, "unable to resolve address data that was apparently the right type");
					}
				}
				break;
			
			default:
				// ???
				Console_Warning(Console_WriteLine, "cannot resolve address because preferred address family is unsupported");
				break;
			}
			
			// found desired type of address, so stop resolving
			[resolvingService stop];
			break;
		}
	}
	if (nil != resolvedHost)
	{
		[self setBestResolvedAddress:resolvedHost];
	}
	if (0 != resolvedPort)
	{
		[self setBestResolvedPort:STATIC_CAST(resolvedPort, UInt16)];
	}
}// netServiceDidResolveAddress:


@end // ServerBrowser_NetService


#pragma mark -
@implementation ServerBrowser_Protocol


@synthesize defaultPort = _defaultPort;
@synthesize protocolID = _protocolID;
@synthesize serviceType = _serviceType;


/*!
Designated initializer.

(4.0)
*/
- (instancetype)
initWithID:(Session_Protocol)	anID
description:(NSString*)			aString
serviceType:(NSString*)			anRFC2782Name
defaultPort:(unsigned short)	aNumber
{
	self = [super initWithBoundName:aString];
	if (nil != self)
	{
		_protocolID = anID;
		_serviceType = [anRFC2782Name copy];
		_defaultPort = aNumber;
	}
	return self;
}// initWithID:description:serviceType:defaultPort:


/*!
Destructor.

(4.1)
*/
- (void)
dealloc
{
	[_serviceType release];
	[super dealloc];
}// dealloc


@end // ServerBrowser_Protocol


#pragma mark -
@implementation ServerBrowser_VC


@synthesize errorMessage = _errorMessage;
@synthesize hidesErrorMessage = _hidesErrorMessage;
@synthesize hidesProgress = _hidesProgress;
@synthesize protocolDefinitions = _protocolDefinitions;


/*!
Designated initializer from base class.  Do not use;
it is defined only to satisfy the compiler.

(2017.06)
*/
- (instancetype)
initWithCoder:(NSCoder*)	aCoder
{
#pragma unused(aCoder)
	assert(false && "invalid way to initialize derived class");
	return [self initWithResponder:nil dataObserver:nil];
}// initWithCoder:


/*!
Designated initializer from base class.  Do not use;
it is defined only to satisfy the compiler.

(2017.06)
*/
- (instancetype)
initWithNibName:(NSString*)		aNibName
bundle:(NSBundle*)				aBundle
{
#pragma unused(aNibName, aBundle)
	assert(false && "invalid way to initialize derived class");
	return [self initWithResponder:nil dataObserver:nil];
}// initWithNibName:bundle:


/*!
Designated initializer.

(4.0)
*/
- (instancetype)
initWithResponder:(id< ServerBrowser_VCDelegate >)		aResponder
dataObserver:(id< ServerBrowser_DataChangeObserver >)	aDataObserver
{
	self = [super initWithNibName:@"ServerBrowserCocoa" bundle:nil];
	if (nil != self)
	{
		discoveredHostsContainer = nil;
		discoveredHostsTableView = nil;
		nextResponderWhenHidingDiscoveredHosts = nil;
		
		_responder = aResponder;
		_dataObserver = aDataObserver;
		_browser = [[NSNetServiceBrowser alloc] init];
		[_browser setDelegate:self];
		_discoveredHostIndexes = [[NSIndexSet alloc] init];
		_protocolIndexes = [[NSIndexSet alloc] init];
		_discoveredHosts = [[NSMutableArray alloc] init];
		_recentHosts = [[NSMutableArray alloc] init];
		// TEMPORARY - it should be possible to externally define these (probably via Python)
		_protocolDefinitions = [[NSArray alloc] initWithObjects:
								[[[ServerBrowser_Protocol alloc] initWithID:kSession_ProtocolSSH1
									description:NSLocalizedStringFromTable(@"SSH Version 1", @"ServerBrowser"/* table */, @"ssh-1")
									serviceType:@"_ssh._tcp."
									defaultPort:22] autorelease],
								[[[ServerBrowser_Protocol alloc] initWithID:kSession_ProtocolSSH2
									description:NSLocalizedStringFromTable(@"SSH Version 2", @"ServerBrowser"/* table */, @"ssh-2")
									serviceType:@"_ssh._tcp."
									defaultPort:22] autorelease],
								[[[ServerBrowser_Protocol alloc] initWithID:kSession_ProtocolSFTP
									description:NSLocalizedStringFromTable(@"SFTP", @"ServerBrowser"/* table */, @"sftp")
									serviceType:@"_ssh._tcp."
									defaultPort:22] autorelease],
								nil];
		_errorMessage = [[NSString string] retain];
		_hostName = [[[NSString alloc] initWithString:@""] autorelease];
		_portNumber = [[[NSString alloc] initWithString:@""] autorelease];
		_userID = [[[NSString alloc] initWithString:@""] autorelease];
		_hidesDiscoveredHosts = YES;
		_hidesErrorMessage = YES;
		_hidesPortNumberError = YES;
		_hidesProgress = YES;
		_hidesUserIDError = YES;
		
		// NSViewController implicitly loads the NIB when the "view"
		// property is accessed; force that here
		[self view];
	}
	return self;
}// initWithResponder:dataObserver:


/*!
Destructor.

(4.0)
*/
- (void)
dealloc
{
	// See the initializer and "awakeFromNib" for initializations to clean up here.
	[self ignoreWhenObjectsPostNotes];
	
	[_userID release];
	[_portNumber release];
	[_hostName release];
	[_errorMessage release];
	[_protocolDefinitions release];
	[_recentHosts release];
	[_discoveredHosts release];
	[_protocolIndexes release];
	[_discoveredHostIndexes release];
	[_browser release];
	
	[super dealloc];
}// dealloc


#pragma mark New Methods


/*!
Returns the view that a window ought to focus first
using NSWindow’s "makeFirstResponder:".

(4.0)
*/
- (NSView*)
logicalFirstResponder
{
	return self->logicalFirstResponder;
}// logicalFirstResponder


/*!
Looks up the host name currently displayed in the host name
field, and replaces it with an IP address.

(4.0)
*/
- (void)
lookUpHostName:(id)		sender
{
#pragma unused(sender)
	if ([self.hostName length] <= 0)
	{
		// there has to be some text entered there; let the user
		// know that a blank is unacceptable
		Sound_StandardAlert();
	}
	else
	{
		char	hostNameBuffer[256];
		
		
		// begin lookup of the domain name
		self.hidesProgress = NO;
		if (CFStringGetCString(BRIDGE_CAST(self.hostName, CFStringRef), hostNameBuffer, sizeof(hostNameBuffer), kCFStringEncodingASCII))
		{
			DNR_Result		lookupAttemptResult = kDNR_ResultOK;
			
			
			lookupAttemptResult = DNR_New(hostNameBuffer, false/* use IP version 4 addresses (defaults to IPv6) */,
			^(struct hostent* inLookupDataPtr)
			{
				if (nullptr == inLookupDataPtr)
				{
					// lookup failed (TEMPORARY; add error message to user interface?)
					Sound_StandardAlert();
				}
				else
				{
					// NOTE: The lookup data could be a linked list of many matches.
					// The first is used arbitrarily.
					if ((nullptr != inLookupDataPtr->h_addr_list) && (nullptr != inLookupDataPtr->h_addr_list[0]))
					{
						CFStringRef		addressCFString = DNR_CopyResolvedHostAsCFString(inLookupDataPtr, 0/* which address */);
						
						
						if (nullptr != addressCFString)
						{
							self.hostName = BRIDGE_CAST(addressCFString, NSString*);
							CFRelease(addressCFString), addressCFString = nullptr;
						}
					}
					DNR_Dispose(&inLookupDataPtr);
				}
				
				// hide progress indicator
				self.hidesProgress = YES;
			});
			
			if (false == lookupAttemptResult.ok())
			{
				// could not even initiate, so restore UI
				self.hidesProgress = YES;
			}
		}
	}
}// lookUpHostName:


/*!
Initiates a search for nearby services (via Bonjour) that
match the currently selected protocol’s service type.

(4.0)
*/
- (void)
rediscoverServices
{
	ServerBrowser_Protocol*		theProtocol = [self protocol];
	
	
	// first destroy the old list
	int		loopGuard = 0;
	while (([_discoveredHosts count] > 0) && (loopGuard < 50/* arbitrary */))
	{
		[self removeObjectFromDiscoveredHostsAtIndex:0];
		++loopGuard;
	}
	
	// now search for new services, which will eventually repopulate the list;
	// only do this when the drawer is visible, though
	if (NO == self.hidesDiscoveredHosts)
	{
		if (nil == theProtocol)
		{
			Console_Warning(Console_WriteLine, "cannot rediscover services because no protocol is yet defined");
		}
		else
		{
			//Console_WriteValueCFString("initiated search for services of type", BRIDGE_CAST([theProtocol serviceType], CFStringRef)); // debug
			[_browser stop];
			// TEMPORARY - determine if one needs to wait for the browser to stop, before starting a new search...
			[_browser searchForServicesOfType:[theProtocol serviceType] inDomain:@""/* empty string implies local search */];
		}
	}
}// rediscoverServices


#pragma mark Accessors: Array Values


/*!
Accessor.

(4.0)
*/
- (void)
insertObject:(ServerBrowser_NetService*)	service
inDiscoveredHostsAtIndex:(unsigned long)	index
{
	[_discoveredHosts insertObject:service atIndex:index];
}
- (void)
removeObjectFromDiscoveredHostsAtIndex:(unsigned long)		index
{
	[_discoveredHosts removeObjectAtIndex:index];
}// removeObjectFromDiscoveredHostsAtIndex:


/*!
Accessor.

(4.0)
*/
- (NSIndexSet*)
discoveredHostIndexes
{
	return [[_discoveredHostIndexes retain] autorelease];
}
- (void)
setDiscoveredHostIndexes:(NSIndexSet*)		indexes
{
	ServerBrowser_NetService*		theDiscoveredHost = nil;
	
	
	[_discoveredHostIndexes release];
	_discoveredHostIndexes = [indexes retain];
	
	theDiscoveredHost = [self discoveredHost];
	if (nil != theDiscoveredHost)
	{
		// auto-set the host and port to match this service
		self.hostName = theDiscoveredHost.bestResolvedAddress;
		self.portNumber = [[NSNumber numberWithUnsignedShort:theDiscoveredHost.bestResolvedPort] stringValue];
	}
}// setDiscoveredHostIndexes:


/*!
Accessor.

(4.0)
*/
- (NSIndexSet*)
protocolIndexes
{
	return [[_protocolIndexes retain] autorelease];
}
- (void)
setProtocolIndexByProtocol:(Session_Protocol)	aProtocol
{
	unsigned int	i = 0;
	
	
	for (ServerBrowser_Protocol* thisProtocol in self.protocolDefinitions)
	{
		if (aProtocol == [thisProtocol protocolID])
		{
			self.protocolIndexes = [NSIndexSet indexSetWithIndex:i];
			break;
		}
		++i;
	}
}
+ (BOOL)
automaticallyNotifiesObserversOfProtocolIndexes
{
	return NO;
}
- (void)
setProtocolIndexes:(NSIndexSet*)	indexes
{
	if (indexes != _protocolIndexes)
	{
		[self willChangeValueForKey:@"protocolIndexes"];
		
		[_protocolIndexes release];
		_protocolIndexes = [indexes retain];
		
		[self didChangeValueForKey:@"protocolIndexes"];
		[self notifyOfChangeInValueReturnedBy:@selector(protocolIndexes)];
		
		ServerBrowser_Protocol*		theProtocol = [self protocol];
		if (nil != theProtocol)
		{
			// auto-set the port number to match the default for this protocol
			self.portNumber = [[NSNumber numberWithUnsignedShort:[theProtocol defaultPort]] stringValue];
			// rediscover services appropriate for this selection
			[self rediscoverServices];
		}
	}
}// setProtocolIndexes:


/*!
Accessor.

(4.0)
*/
- (void)
insertObject:(NSString*)				name
inRecentHostsAtIndex:(unsigned long)	index
{
	[_recentHosts insertObject:name atIndex:index];
}
- (void)
removeObjectFromRecentHostsAtIndex:(unsigned long)		index
{
	[_recentHosts removeObjectAtIndex:index];
}// removeObjectFromRecentHostsAtIndex:


#pragma mark Accessors: General

/*!
Accessor.

(4.0)
*/
- (Session_Protocol)
currentProtocolID
{
	ServerBrowser_Protocol*		protocolObject = [self protocol];
	assert(nil != protocolObject);
	Session_Protocol			result = [protocolObject protocolID];
	
	
	return result;
}// currentProtocolID


/*!
Accessor.

(4.0)
*/
- (NSString*)
hostName
{
	return [[_hostName copy] autorelease];
}
+ (BOOL)
automaticallyNotifiesObserversOfHostName
{
	return NO;
}
- (void)
setHostName:(NSString*)		aString
{
	if (aString != _hostName)
	{
		[self willChangeValueForKey:@"hostName"];
		
		if (nil == aString)
		{
			_hostName = [@"" retain];
		}
		else
		{
			[_hostName autorelease];
			_hostName = [aString copy];
		}
		
		[self didChangeValueForKey:@"hostName"];
		[self notifyOfChangeInValueReturnedBy:@selector(hostName)];
	}
}// setHostName:


/*!
Accessor.

(4.0)
*/
- (NSString*)
portNumber
{
	return [[_portNumber copy] autorelease];
}
+ (BOOL)
automaticallyNotifiesObserversOfPortNumber
{
	return NO;
}
- (void)
setPortNumber:(NSString*)	aString
{
	if (aString != _portNumber)
	{
		[self willChangeValueForKey:@"portNumber"];
		
		if (nil == aString)
		{
			_portNumber = [@"" retain];
		}
		else
		{
			[_portNumber autorelease];
			_portNumber = [aString copy];
		}
		self.hidesPortNumberError = YES;
		
		[self didChangeValueForKey:@"portNumber"];
		[self notifyOfChangeInValueReturnedBy:@selector(portNumber)];
	}
}// setPortNumber:


/*!
Accessor.

(4.0)
*/
- (id)
target
{
	return _target;
}
+ (BOOL)
automaticallyNotifiesObserversOfTarget
{
	return NO;
}
- (void)
setTarget:(id)		anObject
{
	if (anObject != _target)
	{
		[self willChangeValueForKey:@"target"];
		
		[_target release];
		_target = [anObject retain];
		
		[self didChangeValueForKey:@"target"];
	}
}// setTarget:


/*!
Accessor.

(4.0)
*/
- (NSString*)
userID
{
	return [[_userID copy] autorelease];
}
+ (BOOL)
automaticallyNotifiesObserversOfUserID
{
	return NO;
}
- (void)
setUserID:(NSString*)	aString
{
	if (aString != _userID)
	{
		[self willChangeValueForKey:@"userID"];
		
		if (nil == aString)
		{
			_userID = [@"" retain];
		}
		else
		{
			[_userID autorelease];
			_userID = [aString copy];
		}
		self.hidesUserIDError = YES;
		
		[self didChangeValueForKey:@"userID"];
		[self notifyOfChangeInValueReturnedBy:@selector(userID)];
	}
}// setUserID:


#pragma mark Accessors: Low-Level User Interface State


/*!
Accessor.

(4.0)
*/
- (BOOL)
hidesDiscoveredHosts
{
	return _hidesDiscoveredHosts;
}
- (void)
setHidesDiscoveredHosts:(BOOL)		flag
{
	NSRect const	kOldFrame = self.view.frame;
	NSRect			newFrame = self.view.frame;
	NSRect			convertedFrame = self.view.frame;
	
	
	_hidesDiscoveredHosts = flag;
	if (flag)
	{
		Float32 const	kPersistentHeight = 250; // IMPORTANT: must agree with NIB layout!!!
		Float32			deltaHeight = (kPersistentHeight - kOldFrame.size.height);
		
		
		[_browser stop];
		
		newFrame.size.height += deltaHeight;
		convertedFrame.size.height += deltaHeight;
		convertedFrame.origin.y -= deltaHeight;
		
		// fix the current keyboard focus, if necessary
		{
			NSWindow*		popoverWindow = self.view.window;
			NSResponder*	firstResponder = [popoverWindow firstResponder];
			
			
			if ((nil != firstResponder) && [firstResponder isKindOfClass:[NSView class]])
			{
				NSView*		asView = (NSView*)firstResponder;
				NSRect		windowRelativeFrame = [[asView superview] convertRect:[asView frame]
																					toView:[popoverWindow contentView]];
				
				
				// NOTE: this calculation assumes the persistent part is always at the top window edge
				if (windowRelativeFrame.origin.y < (kOldFrame.size.height - kPersistentHeight))
				{
					// current keyboard focus is in the region that is being hidden;
					// force the keyboard focus to change to something that is visible
					[self.view.window makeFirstResponder:self->nextResponderWhenHidingDiscoveredHosts];
				}
			}
		}
	}
	else
	{
		Float32		deltaHeight = (450/* IMPORTANT: must agree with NIB layout!!! */ - kOldFrame.size.height);
		
		
		newFrame.size.height += deltaHeight;
		convertedFrame.size.height += deltaHeight;
		convertedFrame.origin.y -= deltaHeight;
		[self rediscoverServices];
	}
	convertedFrame.origin = [self.view.window convertBaseToScreen:convertedFrame.origin];
	
	if (flag)
	{
		[_responder serverBrowser:self setManagedView:self.view toScreenFrame:convertedFrame];
		[self.view setFrame:newFrame];
		[self->discoveredHostsContainer setHidden:flag];
	}
	else
	{
		[self->discoveredHostsContainer setHidden:flag];
		[_responder serverBrowser:self setManagedView:self.view toScreenFrame:convertedFrame];
		[self.view setFrame:newFrame];
	}
}// setHidesDiscoveredHosts:


/*!
Accessor.

(4.0)
*/
- (BOOL)
hidesPortNumberError
{
	return _hidesPortNumberError;
}
- (void)
setHidesPortNumberError:(BOOL)		flag
{
	_hidesPortNumberError = flag;
	self.hidesErrorMessage = flag;
}// setHidesPortNumberError:


/*!
Accessor.

(4.0)
*/
- (BOOL)
hidesUserIDError
{
	return _hidesUserIDError;
}
- (void)
setHidesUserIDError:(BOOL)		flag
{
	_hidesUserIDError = flag;
	self.hidesErrorMessage = flag;
}// setHidesUserIDError:


#pragma mark Validators


/*!
Validates a port number entered by the user, returning an
appropriate error (and a NO result) if the number is incorrect.

(4.0)
*/
- (BOOL)
validatePortNumber:(id*/* NSString* */)	ioValue
error:(NSError**)						outError
{
	BOOL	result = NO;
	
	
	if (nil == *ioValue)
	{
		result = YES;
	}
	else
	{
		// first strip whitespace
		*ioValue = [[*ioValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] retain];
		
		// while an NSNumberFormatter is more typical for validation,
		// the requirements for port numbers are quite simple
		NSScanner*	scanner = [NSScanner scannerWithString:*ioValue];
		int			value = 0;
		
		
		if ([scanner scanInt:&value] && [scanner isAtEnd] && (value >= 0) && (value <= 65535/* given in TCP/IP spec. */))
		{
			result = YES;
		}
		else
		{
			if (nil != outError) result = NO;
			else result = YES; // cannot return NO when the error instance is undefined
		}
		
		if (NO == result)
		{
			*outError = [NSError errorWithDomain:(NSString*)kConstantsRegistry_NSErrorDomainAppDefault
							code:kConstantsRegistry_NSErrorBadUserID
							userInfo:@{
											NSLocalizedDescriptionKey: NSLocalizedStringFromTable
																		(@"The port must be a number from 0 to 65535.",
																			@"ServerBrowser"/* table */,
																			@"message displayed for bad port numbers"),
										}];
			self.errorMessage = [[*outError userInfo] objectForKey:NSLocalizedDescriptionKey];
			self.hidesPortNumberError = NO;
		}
	}
	return result;
}// validatePortNumber:error:


/*!
Validates a user ID entered by the user, returning an
appropriate error (and a NO result) if the ID is incorrect.

(4.0)
*/
- (BOOL)
validateUserID:(id*/* NSString* */)	ioValue
error:(NSError**)					outError
{
	BOOL	result = NO;
	
	
	if (nil == *ioValue)
	{
		result = YES;
	}
	else
	{
		// first strip whitespace
		*ioValue = [[*ioValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] retain];
		
		NSScanner*				scanner = [NSScanner scannerWithString:*ioValue];
		NSMutableCharacterSet*	validCharacters = [[[NSCharacterSet alphanumericCharacterSet] mutableCopy] autorelease];
		NSString*				value = nil;
		
		
		// periods, underscores and hyphens are also valid in Unix user names
		[validCharacters addCharactersInString:@".-_"];
		
		if ([scanner scanCharactersFromSet:validCharacters intoString:&value] && [scanner isAtEnd])
		{
			result = YES;
		}
		else
		{
			if (nil != outError) result = NO;
			else result = YES; // cannot return NO when the error instance is undefined
		}
		
		if (NO == result)
		{
			*outError = [NSError errorWithDomain:(NSString*)kConstantsRegistry_NSErrorDomainAppDefault
							code:kConstantsRegistry_NSErrorBadPortNumber
							userInfo:@{
											NSLocalizedDescriptionKey: NSLocalizedStringFromTable
																		(@"The user ID must only use letters, numbers, dashes, underscores, and periods.",
																			@"ServerBrowser"/* table */,
																			@"message displayed for bad user IDs"),
										}];
			self.errorMessage = [[*outError userInfo] objectForKey:NSLocalizedDescriptionKey];
			self.hidesUserIDError = NO;
		}
	}
	return result;
}// validateUserID:error:


#pragma mark NSNetServiceBrowserDelegateMethods


/*!
Called as new services are discovered.

(4.0)
*/
- (void)
netServiceBrowser:(NSNetServiceBrowser*)	aNetServiceBrowser
didFindService:(NSNetService*)				aNetService
moreComing:(BOOL)							moreComing
{
#pragma unused(aNetServiceBrowser)
#pragma unused(moreComing)
	[self insertObject:[[[ServerBrowser_NetService alloc] initWithNetService:aNetService addressFamily:AF_INET] autorelease]
			inDiscoveredHostsAtIndex:[_discoveredHosts count]];
	//NSLog(@"%@", [self mutableArrayValueForKey:@"discoveredHosts"]); // debug
}// netServiceBrowser:didFindService:moreComing:


/*!
Called when a search fails.

(4.0)
*/
- (void)
netServiceBrowser:(NSNetServiceBrowser*)	aNetServiceBrowser
didNotSearch:(NSDictionary*)				errorInfo
{
#pragma unused(aNetServiceBrowser)
	Console_Warning(Console_WriteValue, "search for services failed with error",
					[[errorInfo objectForKey:NSNetServicesErrorCode] intValue]);
}// netServiceBrowser:didNotSearch:


/*!
Called when a search has stopped.

(4.0)
*/
- (void)
netServiceBrowserDidStopSearch:(NSNetServiceBrowser*)	aNetServiceBrowser
{
#pragma unused(aNetServiceBrowser)
	//Console_WriteLine("search for services has stopped"); // debug
}// netServiceBrowserDidStopSearch:


/*!
Called when a search is about to begin.

(4.0)
*/
- (void)
netServiceBrowserWillSearch:(NSNetServiceBrowser*)	aNetServiceBrowser
{
#pragma unused(aNetServiceBrowser)
	//Console_WriteLine("search for services has begun"); // debug
}// netServiceBrowserWillSearch:


#pragma mark NSViewController


/*!
Invoked by NSViewController once the "self.view" property is set,
after the NIB file is loaded.  This essentially guarantees that
all file-defined user interface elements are now instantiated and
other settings that depend on valid UI objects can now be made.

NOTE:	As future SDKs are adopted, it makes more sense to only
		implement "viewDidLoad" (which was only recently added
		to NSViewController and is not otherwise available).
		This implementation can essentially move to "viewDidLoad".

(4.1)
*/
- (void)
loadView
{
	[super loadView];
	
	assert(nil != discoveredHostsContainer);
	assert(nil != discoveredHostsTableView);
	assert(nil != nextResponderWhenHidingDiscoveredHosts);
	
	self.hidesDiscoveredHosts = YES;
	[_responder serverBrowser:self didLoadManagedView:self.view];
	
	// find out when the window will close, so that the button that opened the window can return to normal
	[self whenObject:self.view.window postsNote:NSWindowWillCloseNotification
						performSelector:@selector(serverBrowserWindowWillClose:)];
	
	// since double-click bindings require 10.4 or later, do this manually now
	[discoveredHostsTableView setIgnoresMultiClick:NO];
	[discoveredHostsTableView setTarget:self];
	[discoveredHostsTableView setDoubleAction:@selector(didDoubleClickDiscoveredHostWithSelection:)];
}// loadView


@end // ServerBrowser_VC


#pragma mark -
@implementation ServerBrowser_VC (ServerBrowser_VCInternal)


/*!
Responds to a double-click of a discovered host by
automatically closing the drawer.

Note that there is already a single-click action (handled
via selection bindings) for actually using the selected
service’s host and port, so double-clicks do not need to
do further processing.

(4.0)
*/
- (void)
didDoubleClickDiscoveredHostWithSelection:(NSArray*)	objects
{
#pragma unused(objects)
	self.hidesDiscoveredHosts = YES;
}// didDoubleClickDiscoveredHostWithSelection:


/*!
Accessor.

(4.0)
*/
- (ServerBrowser_NetService*)
discoveredHost
{
	ServerBrowser_NetService*	result = nil;
	NSUInteger					selectedIndex = [self.discoveredHostIndexes firstIndex];
	
	
	if (NSNotFound != selectedIndex)
	{
		result = [_discoveredHosts objectAtIndex:selectedIndex];
	}
	return result;
}// discoveredHost


/*!
If an observer object has been specified by ServerBrowser_New(),
sends a message to the observer to notify it of panel changes.

Call this whenever the user makes a change to a core setting in
the panel.

Only specific selectors are allowed:
	hostName
	portNumber
	protocolIndexes
	userID
These methods are called when given, and their current return
values are translated into appropriate parameters to pass to
the observer.

(4.0)
*/
- (void)
notifyOfChangeInValueReturnedBy:(SEL)	valueGetter
{
	if (nil != _dataObserver)
	{
		if (valueGetter == @selector(protocolIndexes))
		{
			[_dataObserver serverBrowser:self didSetProtocol:[self currentProtocolID]];
		}
		else if (valueGetter == @selector(hostName))
		{
			[_dataObserver serverBrowser:self didSetHostName:self.hostName];
		}
		else if (valueGetter == @selector(portNumber))
		{
			NSString*		portNumberString = self.portNumber;
			NSUInteger		portNumberForEvent = [portNumberString integerValue];
			
			
			[_dataObserver serverBrowser:self didSetPortNumber:portNumberForEvent];
		}
		else if (valueGetter == @selector(userID))
		{
			[_dataObserver serverBrowser:self didSetUserID:self.userID];
		}
		else
		{
			Console_Warning(Console_WriteLine, "invalid selector passed to notifyOfChangeInValueReturnedBy:");
		}
	}
}// notifyOfChangeInValueReturnedBy:


/*!
Accessor.

(4.0)
*/
- (ServerBrowser_Protocol*)
protocol
{
	ServerBrowser_Protocol*		result = nil;
	NSUInteger					selectedIndex = [self.protocolIndexes firstIndex];
	
	
	if (NSNotFound != selectedIndex)
	{
		result = [self.protocolDefinitions objectAtIndex:selectedIndex];
	}
	return result;
}// protocol


/*!
Responds to the panel closing by removing any ties to an
event target, but notifying that target first.  This would
have the effect, for instance, of associated windows
removing highlighting from interface elements to show that
they are no longer using this panel.

Also interrupts any Bonjour scans that may be in progress.

(4.0)
*/
- (void)
serverBrowserWindowWillClose:(NSNotification*)	notification
{
#pragma unused(notification)
	// interrupt any Bonjour scans in progress
	[_browser stop];
	
	// remember the selected host as a recent item
	[self insertObject:[[_hostName copy] autorelease] inRecentHostsAtIndex:0];
	if ([_recentHosts count] > 4/* arbitrary */)
	{
		[self removeObjectFromRecentHostsAtIndex:([_recentHosts count] - 1)];
	}
	
	// notify the handler
	[_responder serverBrowser:self didFinishUsingManagedView:self.view];
}// serverBrowserWindowWillClose:


@end

// BELOW IS REQUIRED NEWLINE TO END FILE
