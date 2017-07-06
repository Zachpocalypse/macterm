/*!	\file PopoverManager.mm
	\brief Provides common support code that is generally
	needed by any window that acts like a popover.
*/
/*###############################################################

	Interface Library
	© 1998-2017 by Kevin Grant
	
	This library is free software; you can redistribute it or
	modify it under the terms of the GNU Lesser Public License
	as published by the Free Software Foundation; either version
	2.1 of the License, or (at your option) any later version.
	
	This library is distributed in the hope that it will be
	useful, but WITHOUT ANY WARRANTY; without even the implied
	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
	PURPOSE.  See the GNU Lesser Public License for details.
	
	You should have received a copy of the GNU Lesser Public
	License along with this library; if not, write to:
	
		Free Software Foundation, Inc.
		59 Temple Place, Suite 330
		Boston, MA  02111-1307
		USA

###############################################################*/

#import "PopoverManager.objc++.h"
#import <UniversalDefines.h>

// Mac includes
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

// library includes
#import <CarbonEventHandlerWrap.template.h>
#import <CocoaAnimation.h>
#import <CocoaBasic.h>
#import <CocoaExtensions.objc++.h>
#import <CocoaFuture.objc++.h>
#import <Console.h>
#import <MemoryBlocks.h>
#import <Popover.objc++.h>



#pragma mark Types

@interface PopoverManager_WC : NSWindowController< Popover_ResizeDelegate > //{
{
@public
	PopoverManager_Ref				selfRef;				// identical to address of structure, but typed as ref
	//__weak id< PopoverManager_Delegate >	delegate;				// used to determine dynamic popover information
	MemoryBlocks_WeakPairWrap
	< PopoverManager_WC*,
		id >*						delegatePtr;			// used to determine dynamic popover information
	Popover_Window*					containerWindow;		// holds the popover itself (note: is an NSWindow subclass)
	NSView*							logicalFirstResponder;	// the view to give initial keyboard focus to, in "display" method
	PopoverManager_AnimationType	animationType;			// specifies how to open and close the popover window
	PopoverManager_BehaviorType		behaviorType;			// specifies how the popover window responds to other events
	BOOL							isAutoPositionQueued;	// used to ensure at most one response to an auto-position request
	BOOL							isHeldOpenBySheet;		// used to prevent some popovers from disappearing while sheets are open
	NSWindow*						dummySheet;				// for convenience in event-handling for dialogs, a dummy sheet
	NSView*							parentView;				// the view the popover is relative to, if Cocoa (and modal to, if dialog behavior)
#if POPOVER_MANAGER_SUPPORTS_CARBON
	HIWindowRef						parentCarbonWindow;		// the window the popover is relative to, if Carbon
	CarbonEventHandlerWrap*			activationHandlerPtr;	// embellishes Carbon Event for activating window
	CarbonEventHandlerWrap*			clickActivationHandlerPtr;	// embellishes Carbon Event for clicking special parts of window
	CarbonEventHandlerWrap*			minimizeHandlerPtr;		// embellishes Carbon Event for minimizing window
	CarbonEventHandlerWrap*			modalityHandlerPtr;		// embellishes Carbon Event for determining whether modal window blocks a click
	CarbonEventHandlerWrap*			resizeHandlerPtr;		// embellishes Carbon Event for resizing window
#endif
}

// class methods
	+ (PopoverManager_WC*)
	popoverWindowControllerFromRef:(PopoverManager_Ref)_;

// initializers
	- (instancetype)
	initForParentCocoaView:(NSView*)_
	orCarbonWindow:(HIWindowRef)_
	popover:(Popover_Window*)_
	firstResponder:(NSView*)_
	animationType:(PopoverManager_AnimationType)_
	behavior:(PopoverManager_BehaviorType)_
	delegate:(id< PopoverManager_Delegate >)_;

// new methods
	- (void)
	display;
	- (NSPoint)
	idealAnchorPointForFrame:(NSRect)_
	parentWindow:(NSWindow*)_;
	- (Popover_Properties)
	idealArrowPositionForFrame:(NSRect)_
	parentWindow:(NSWindow*)_;
	- (void)
	makeKeyAndOrderFront;
	- (void)
	makeKeyAndOrderFrontIfVisible;
	- (void)
	moveToIdealPosition;
	- (void)
	moveToIdealPositionAfterDelay:(float)_;
	- (void)
	orderFrontIfVisible;
	- (void)
	popOverMakeKey:(BOOL)_
	forceVisible:(BOOL)_;
	- (void)
	popUnder;
	- (void)
	removeWindowAfterDelayWithAcceptance:(BOOL)_;
	- (void)
	removeWindowWithAcceptance:(BOOL)_;
	- (void)
	removeWindowWithAcceptance:(BOOL)_
	afterDelay:(float)_;
	- (void)
	setToIdealSize;

// accessors
	- (NSSize)
	idealSize;
	- (BOOL)
	isVisible;
	- (NSWindow*)
	parentCocoaWindow;

@end //}

#pragma mark Internal Method Prototypes
namespace {

#if POPOVER_MANAGER_SUPPORTS_CARBON
OSStatus	receiveWindowActivationChange	(EventHandlerCallRef, EventRef, void*);
OSStatus	receiveWindowCollapse			(EventHandlerCallRef, EventRef, void*);
OSStatus	receiveWindowGetClickActivation	(EventHandlerCallRef, EventRef, void*);
OSStatus	receiveWindowGetClickModality	(EventHandlerCallRef, EventRef, void*);
OSStatus	receiveWindowResize				(EventHandlerCallRef, EventRef, void*);
#endif 

} // anonymous namespace



#pragma mark Public Methods

/*!
Constructs a new popover manager, where the parent view is
Cocoa-based.

(2.7)
*/
PopoverManager_Ref
PopoverManager_New	(Popover_Window*				inPopover,
					 NSView*						inLogicalFirstResponder,
					 id< PopoverManager_Delegate >	inDelegate,
					 PopoverManager_AnimationType	inAnimation,
					 PopoverManager_BehaviorType	inBehavior,
					 NSView*						inParentView)
{
	PopoverManager_Ref	result = REINTERPRET_CAST([[PopoverManager_WC alloc]
													initForParentCocoaView:inParentView
																			orCarbonWindow:nullptr
																			popover:inPopover
																			firstResponder:inLogicalFirstResponder
																			animationType:inAnimation
																			behavior:inBehavior
																			delegate:inDelegate],
													PopoverManager_Ref);
	
	
	return result;
}// New


#if POPOVER_MANAGER_SUPPORTS_CARBON
/*!
Constructs a new popover manager, where the parent window is
Carbon-based.

(2.7)
*/
PopoverManager_Ref
PopoverManager_New	(Popover_Window*				inPopover,
					 NSView*						inLogicalFirstResponder,
					 id< PopoverManager_Delegate >	inDelegate,
					 PopoverManager_AnimationType	inAnimation,
					 PopoverManager_BehaviorType	inBehavior,
					 HIWindowRef					inParentWindow)
{
	PopoverManager_Ref	result = REINTERPRET_CAST([[PopoverManager_WC alloc]
													initForParentCocoaView:nil
																			orCarbonWindow:inParentWindow
																			popover:inPopover
																			firstResponder:inLogicalFirstResponder
																			animationType:inAnimation
																			behavior:inBehavior
																			delegate:inDelegate],
													PopoverManager_Ref);
	
	
	return result;
}// New
#endif


/*!
Destroys a popover manager and sets your copy of the
reference to nullptr.

(2.7)
*/
void
PopoverManager_Dispose	(PopoverManager_Ref*	inoutRefPtr)
{
	PopoverManager_WC*		ptr = [PopoverManager_WC popoverWindowControllerFromRef:*inoutRefPtr];
	
	
	[ptr release];
}// Dispose


/*!
Uses an appropriate animation sequence to display the
popover window associated with this manager, or simply
gives it keyboard focus and puts it in front if it is
already visible.

(2.7)
*/
void
PopoverManager_DisplayPopover	(PopoverManager_Ref		inRef)
{
	PopoverManager_WC*		ptr = [PopoverManager_WC popoverWindowControllerFromRef:inRef];
	
	
	[ptr display];
}// Display


/*!
Hides the popover with an appropriate animation.  It can
be shown again at any time with PopoverManager_Display().
If a delay is specified, the popover does not disappear
right away; this can be useful to avoid clobbering other
animations that may occur at closing time.

(2.7)
*/
void
PopoverManager_RemovePopover	(PopoverManager_Ref		inRef,
								 Boolean				inIsConfirming)
{
	PopoverManager_WC*		ptr = [PopoverManager_WC popoverWindowControllerFromRef:inRef];
	
	
	[ptr removeWindowWithAcceptance:inIsConfirming];
}// Remove


/*!
Changes the type of animation used for the popover.
This is typically only used just prior to closing a
popover, in order to hide it immediately in certain
situations (such as closing its parent window).

(2.8)
*/
void
PopoverManager_SetAnimationType		(PopoverManager_Ref				inRef,
									 PopoverManager_AnimationType	inAnimation)
{
	PopoverManager_WC*		ptr = [PopoverManager_WC popoverWindowControllerFromRef:inRef];
	
	
	ptr->animationType = inAnimation;
}// SetAnimationType


/*!
Changes the way that a popover responds to other events.

(2.8)
*/
void
PopoverManager_SetBehaviorType		(PopoverManager_Ref				inRef,
									 PopoverManager_BehaviorType	inBehavior)
{
	PopoverManager_WC*		ptr = [PopoverManager_WC popoverWindowControllerFromRef:inRef];
	
	
	ptr->behaviorType = inBehavior;
}// SetBehaviorType


/*!
For popovers that use “automatic” placement, recalculates
the best place for the arrow and relocates the popover so
that it is pointing (in a possibly new direction) at its
original ideal point.  If the arrow is on a different side
of the popover as a result, the frame size may change
slightly to accommodate the arrow along the new edge.

This is done automatically as a side effect of displaying
a popover, so you only need this API in special situations;
for example, if you need to resize the popover window then
you may want to correct its position.

(2.7)
*/
void
PopoverManager_UseIdealLocationAfterDelay	(PopoverManager_Ref		inRef,
											 Float32				inDelay)
{
	PopoverManager_WC*		ptr = [PopoverManager_WC popoverWindowControllerFromRef:inRef];
	
	
	[ptr moveToIdealPositionAfterDelay:inDelay];
}// UseIdealLocationAfterDelay


#pragma mark Internal Methods
namespace {


#if POPOVER_MANAGER_SUPPORTS_CARBON
/*!
Handles "kEventWindowDeactivated" of "kEventClassWindow" for
the parent window of a popover.

Ensures that the popover does not obscure windows other than
its own parent window.

IMPORTANT:	This must be kept in sync with the Cocoa
			equivalents, e.g. "windowDidResignKey:".

(2.7)
*/
OSStatus
receiveWindowActivationChange	(EventHandlerCallRef	UNUSED_ARGUMENT(inHandlerCallRef),
								 EventRef				inEvent,
								 void*					inWindowController)
{
	OSStatus				result = eventNotHandledErr;
	PopoverManager_WC*		windowController = REINTERPRET_CAST(inWindowController, PopoverManager_WC*);
	UInt32 const			kEventClass = GetEventClass(inEvent);
	UInt32 const			kEventKind = GetEventKind(inEvent);
	
	
	assert(kEventClass == kEventClassWindow);
	assert((kEventKind == kEventWindowActivated) || (kEventKind == kEventWindowDeactivated));
	
	if ([windowController isVisible])
	{
		if (kEventKind == kEventWindowDeactivated)
		{
			// when the parent window is active, the popover should remain on top
			if (kPopoverManager_BehaviorTypeDialog == windowController->behaviorType)
			{
				[windowController popUnder];
			}
			else if (kPopoverManager_BehaviorTypeFloating == windowController->behaviorType)
			{
				[windowController orderFrontIfVisible];
			}
		}
		else
		{
			// allow other normal windows to sit above background popovers
			if (kPopoverManager_BehaviorTypeDialog == windowController->behaviorType)
			{
				[windowController makeKeyAndOrderFrontIfVisible];
				HiliteWindow(windowController->parentCarbonWindow, false);
			}
			else if (kPopoverManager_BehaviorTypeFloating == windowController->behaviorType)
			{
				[windowController orderFrontIfVisible];
				HiliteWindow(windowController->parentCarbonWindow, false);
			}
		}
	}
	result = eventNotHandledErr; // not completely handled
	
	return result;
}// receiveWindowActivationChange
#endif


#if POPOVER_MANAGER_SUPPORTS_CARBON
/*!
Handles "kEventWindowCollapse" of "kEventClassWindow" for
the parent window of a popover.

Ensures that the popover disappears before the parent window
is minimized (helps to avoid bugs that are not yet resolved,
such as having the popover remain visible even if the parent
window is minimized).

(2.7)
*/
OSStatus
receiveWindowCollapse	(EventHandlerCallRef	UNUSED_ARGUMENT(inHandlerCallRef),
						 EventRef				inEvent,
						 void*					inWindowController)
{
	OSStatus				result = eventNotHandledErr;
	PopoverManager_WC*		windowController = REINTERPRET_CAST(inWindowController, PopoverManager_WC*);
	UInt32 const			kEventClass = GetEventClass(inEvent);
	UInt32 const			kEventKind = GetEventKind(inEvent);
	
	
	assert(kEventClass == kEventClassWindow);
	assert(kEventKind == kEventWindowCollapse);
	
	if ([windowController isVisible])
	{
		[windowController removeWindowAfterDelayWithAcceptance:NO];
	}
	result = eventNotHandledErr; // not completely handled
	
	return result;
}// receiveWindowCollapse
#endif


#if POPOVER_MANAGER_SUPPORTS_CARBON
/*!
Handles "kEventWindowGetClickActivation" of "kEventClassWindow"
for the parent window of a popover.

Ensures that clicks in special window parts such as the toolbar
will also select a window when it is blocked by a dialog.

(2016.09)
*/
OSStatus
receiveWindowGetClickActivation		(EventHandlerCallRef		inHandlerCallRef,
									 EventRef				inEvent,
									 void*					inWindowController)
{
	OSStatus				result = eventNotHandledErr;
	PopoverManager_WC*		windowController = REINTERPRET_CAST(inWindowController, PopoverManager_WC*);
	UInt32 const			kEventClass = GetEventClass(inEvent);
	UInt32 const			kEventKind = GetEventKind(inEvent);
	
	
	assert(kEventClass == kEventClassWindow);
	assert(kEventKind == kEventWindowGetClickActivation);
	
	if ([windowController isVisible])
	{
		// the popover should remain on top
		if (kPopoverManager_BehaviorTypeDialog == windowController->behaviorType)
		{
			[windowController makeKeyAndOrderFrontIfVisible];
		}
		else if (kPopoverManager_BehaviorTypeFloating == windowController->behaviorType)
		{
			[windowController orderFrontIfVisible];
		}
	}
	
	// defer to default handler
	result = CallNextEventHandler(inHandlerCallRef, inEvent);
	
	return result;
}// receiveWindowGetClickActivation
#endif


#if POPOVER_MANAGER_SUPPORTS_CARBON
/*!
Handles "kEventWindowGetClickModality" of "kEventClassWindow"
for the parent window of a popover.

Ensures that the parent window can be activated by a click
anywhere while a sheet is open.

(2016.09)
*/
OSStatus
receiveWindowGetClickModality	(EventHandlerCallRef		inHandlerCallRef,
								 EventRef				inEvent,
								 void*					inWindowController)
{
	OSStatus				result = eventNotHandledErr;
	PopoverManager_WC*		windowController = REINTERPRET_CAST(inWindowController, PopoverManager_WC*);
	UInt32 const			kEventClass = GetEventClass(inEvent);
	UInt32 const			kEventKind = GetEventKind(inEvent);
	
	
	assert(kEventClass == kEventClassWindow);
	assert(kEventKind == kEventWindowGetClickModality);
	
	if ([windowController isVisible])
	{
		// the popover should remain on top
		if (kPopoverManager_BehaviorTypeDialog == windowController->behaviorType)
		{
			[windowController makeKeyAndOrderFrontIfVisible];
		}
		else if (kPopoverManager_BehaviorTypeFloating == windowController->behaviorType)
		{
			[windowController orderFrontIfVisible];
		}
	}
	
	// defer to default handler
	result = CallNextEventHandler(inHandlerCallRef, inEvent);
	
	return result;
}// receiveWindowGetClickModality
#endif


#if POPOVER_MANAGER_SUPPORTS_CARBON
/*!
Handles "kEventWindowBoundsChanged" of "kEventClassWindow"
for the parent window of a popover.

Ensures that the popover remains in its ideal position.

(2.7)
*/
OSStatus
receiveWindowResize		(EventHandlerCallRef	UNUSED_ARGUMENT(inHandlerCallRef),
						 EventRef				inEvent,
						 void*					inWindowController)
{
	OSStatus				result = eventNotHandledErr;
	PopoverManager_WC*		windowController = REINTERPRET_CAST(inWindowController, PopoverManager_WC*);
	UInt32 const			kEventClass = GetEventClass(inEvent);
	UInt32 const			kEventKind = GetEventKind(inEvent);
	
	
	assert(kEventClass == kEventClassWindow);
	assert(kEventKind == kEventWindowBoundsChanged);
	
	if ([windowController isVisible])
	{
		// IMPORTANT: since this notification occurs constantly during
		// a live move of the parent window, limit number of responses
		[windowController moveToIdealPositionAfterDelay:0.3f/* arbitrary */];
	}
	result = eventNotHandledErr; // not completely handled
	
	return result;
}// receiveWindowResize
#endif


} // anonymous namespace


#pragma mark -
@implementation PopoverManager_WC


/*!
Converts from the opaque reference type to the internal type.

(2.7)
*/
+ (PopoverManager_WC*)
popoverWindowControllerFromRef:(PopoverManager_Ref)		aRef
{
	return (PopoverManager_WC*)aRef;
}// popoverWindowControllerFromRef


/*!
Designated initializer.

The delegate object should conform to the protocol
"PopoverManager_Delegate".  This is not enforced
for simplicity in the C-style header file.

(2.7)
*/
- (instancetype)
initForParentCocoaView:(NSView*)				aCocoaViewOrNil
orCarbonWindow:(HIWindowRef)					aCarbonWindow
popover:(Popover_Window*)						aPopover
firstResponder:(NSView*)						aView
animationType:(PopoverManager_AnimationType)	animationSpec
behavior:(PopoverManager_BehaviorType)			behaviorSpec
delegate:(id< PopoverManager_Delegate >)		anObject
{
#if ! POPOVER_MANAGER_SUPPORTS_CARBON
#pragma unused(aCarbonWindow)
#endif
	self = [super initWithWindow:aPopover];
	if (nil != self)
	{
	#if POPOVER_MANAGER_SUPPORTS_CARBON
		HIWindowRef		windowWatchedForMinimize = nullptr;
	#endif
		
		
	#if POPOVER_MANAGER_SUPPORTS_CARBON
		if (nullptr != aCarbonWindow)
		{
			// if the parent of the popover is a sheet, install the
			// minimization handler on its parent instead
			if (noErr != GetSheetWindowParent(aCarbonWindow, &windowWatchedForMinimize))
			{
				windowWatchedForMinimize = aCarbonWindow;
			}
		}
	#endif
		
		self->selfRef = STATIC_CAST(self, PopoverManager_Ref);
		self->delegatePtr = new MemoryBlocks_WeakPairWrap< PopoverManager_WC*, id >(self);
		self->delegatePtr->assign(anObject);
		self->containerWindow = aPopover;
		[self->containerWindow retain];
		self->containerWindow.resizeDelegate = self;
		self->logicalFirstResponder = aView;
		self->animationType = animationSpec;
		self->behaviorType = behaviorSpec;
		self->isAutoPositionQueued = NO;
		self->isHeldOpenBySheet = NO;
		self->dummySheet = nil; // created as needed
		self->parentView = aCocoaViewOrNil;
	#if POPOVER_MANAGER_SUPPORTS_CARBON
		self->parentCarbonWindow = aCarbonWindow;
		if (nullptr != aCarbonWindow)
		{
			// unfortunately Cocoa window notifications do not seem to work for
			// Carbon-based Cocoa windows on all Mac OS X versions, so for now
			// use Carbon Events to detect important changes
			self->activationHandlerPtr = new CarbonEventHandlerWrap
												(GetWindowEventTarget(aCarbonWindow), receiveWindowActivationChange,
													CarbonEventSetInClass(CarbonEventClass(kEventClassWindow),
																			kEventWindowActivated,
																			kEventWindowDeactivated), self/* handler data */);
			self->clickActivationHandlerPtr = new CarbonEventHandlerWrap
													(GetWindowEventTarget(aCarbonWindow), receiveWindowGetClickActivation,
														CarbonEventSetInClass(CarbonEventClass(kEventClassWindow),
																				kEventWindowGetClickActivation), self/* handler data */);
			self->minimizeHandlerPtr = new CarbonEventHandlerWrap
											(GetWindowEventTarget(windowWatchedForMinimize), receiveWindowCollapse,
												CarbonEventSetInClass(CarbonEventClass(kEventClassWindow),
																		kEventWindowCollapse), self/* handler data */);
			self->modalityHandlerPtr = new CarbonEventHandlerWrap
											(GetWindowEventTarget(aCarbonWindow), receiveWindowGetClickModality,
												CarbonEventSetInClass(CarbonEventClass(kEventClassWindow),
																		kEventWindowGetClickModality), self/* handler data */);
			self->resizeHandlerPtr = new CarbonEventHandlerWrap
											(GetWindowEventTarget(aCarbonWindow), receiveWindowResize,
												CarbonEventSetInClass(CarbonEventClass(kEventClassWindow),
																		kEventWindowBoundsChanged), self/* handler data */);
		}
		else
	#endif
		{
			// there may be no parent window if it is being used to
			// implement an application-modal dialog; otherwise,
			// install handlers...
			if (nil != [self parentCocoaWindow])
			{
				// install handlers to detect important changes to the parent;
				// NOTE: by default, Cocoa does “the right thing” for a minimized
				// parent window so (unlike with Carbon) no special handler is
				// installed for minimization of Cocoa windows
				[self whenObject:[self parentCocoaWindow] postsNote:NSWindowDidBecomeKeyNotification
									performSelector:@selector(parentWindowDidBecomeKey:)];
				[self whenObject:[self parentCocoaWindow] postsNote:NSWindowDidResignKeyNotification
									performSelector:@selector(parentWindowDidResignKey:)];
				// INCOMPLETE; perhaps this should instead monitor for size
				// changes in the parent view, not the window (and position
				// the popover relative to the view)
				[self whenObject:[self parentCocoaWindow] postsNote:NSWindowDidMoveNotification
									performSelector:@selector(parentWindowDidMove:)];
				[self whenObject:[self parentCocoaWindow] postsNote:NSWindowDidResizeNotification
									performSelector:@selector(parentWindowDidResize:)];
			}
		}
		
		// also monitor the popover itself to know when to auto-hide
		[self whenObject:self->containerWindow postsNote:NSWindowDidEndSheetNotification
							performSelector:@selector(windowDidEndSheet:)];
		[self whenObject:self->containerWindow postsNote:NSWindowWillBeginSheetNotification
							performSelector:@selector(windowWillBeginSheet:)];
		[self whenObject:self->containerWindow postsNote:NSWindowDidResignKeyNotification
							performSelector:@selector(windowDidResignKey:)];
		
		// install handlers to correct the window level when the
		// application is switched out
		[self whenObject:NSApp postsNote:NSApplicationDidBecomeActiveNotification
							performSelector:@selector(applicationDidBecomeActive:)];
		[self whenObject:NSApp postsNote:NSApplicationDidResignActiveNotification
							performSelector:@selector(applicationDidResignActive:)];
	}
	return self;
}// initForParentCocoaView:orCarbonWindow:popover:firstResponder:animationType:behavior:delegate:


/*!
Destructor.

(2.7)
*/
- (void)
dealloc
{
	delete self->delegatePtr, self->delegatePtr = nullptr;
	[self removeWindowWithAcceptance:NO];
	[self.class cancelPreviousPerformRequestsWithTarget:self];
	[self ignoreWhenObjectsPostNotes];
#if POPOVER_MANAGER_SUPPORTS_CARBON
	delete self->activationHandlerPtr, activationHandlerPtr = nullptr;
	delete self->clickActivationHandlerPtr, clickActivationHandlerPtr = nullptr;
	delete self->minimizeHandlerPtr, minimizeHandlerPtr = nullptr;
	delete self->modalityHandlerPtr, modalityHandlerPtr = nullptr;
	delete self->resizeHandlerPtr, resizeHandlerPtr = nullptr;
#endif
	[containerWindow release];
	[super dealloc];
}// dealloc


/*!
Shows the popover view with appropriate animation if it is
invisible, puts it in front and gives it keyboard focus.

(2.7)
*/
- (void)
display
{
	[self setToIdealSize];
	[self moveToIdealPosition];
	switch (self->animationType)
	{
	case kPopoverManager_AnimationTypeNone:
		if ([NSWindow instancesRespondToSelector:@selector(setAnimationBehavior:)])
		{
			// remove window animations
			[self->containerWindow setAnimationBehavior:FUTURE_SYMBOL(2, NSWindowAnimationBehaviorNone)];
		}
		break;
	
	case kPopoverManager_AnimationTypeMinimal:
		if ([NSWindow instancesRespondToSelector:@selector(setAnimationBehavior:)])
		{
			// create fade-in effect; admittedly a bit of a hack...
			[self->containerWindow setAnimationBehavior:FUTURE_SYMBOL(4, NSWindowAnimationBehaviorUtilityWindow)];
		}
		break;
	
	case kPopoverManager_AnimationTypeStandard:
	default:
		if (kPopoverManager_BehaviorTypeDialog == self->behaviorType)
		{
			// display the actual dialog; the window-modal state is
			// achieved by the dummy sheet however
			CocoaAnimation_TransitionWindowForSheetOpen(self->containerWindow, [self parentCocoaWindow]);
			
			// the goal is to bypass any normal sheet display/animation
			// but the convenience of automatic window-modal event handling
			// is still useful; an empty-frame window is created as a real
			// sheet for event blocking, and then covered by the popover
			if ((nil != self->parentView)
			#if POPOVER_MANAGER_SUPPORTS_CARBON
				|| (nullptr != self->parentCarbonWindow)
			#endif
				)
			{
				self->dummySheet = [[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask
																			backing:NSBackingStoreBuffered defer:YES];
				[self->dummySheet setPreventsApplicationTerminationWhenModal:NO];
			#if MAC_OS_X_VERSION_MIN_REQUIRED < 101000 /* MAC_OS_X_VERSION_10_10 */
				// old method
				[NSApp beginSheet:self->dummySheet modalForWindow:[self parentCocoaWindow] modalDelegate:nil
									didEndSelector:nil contextInfo:self];
			#else
				// new method
				[[self parentCocoaWindow] beginSheet:self->dummySheet
														completionHandler:^(NSModalResponse aResponse)
														{
														#pragma unused(aResponse)
														}];
			#endif
			}
		}
		else
		{
			if ([NSWindow instancesRespondToSelector:@selector(setAnimationBehavior:)])
			{
				// create bubble effect; admittedly a bit of a hack...
				[self->containerWindow setAnimationBehavior:FUTURE_SYMBOL(5, NSWindowAnimationBehaviorAlertPanel)];
			}
		}
		break;
	}
	[[self parentCocoaWindow] addChildWindow:self->containerWindow ordered:NSWindowAbove];
	[self makeKeyAndOrderFront];
}// display


/*!
Returns the location (relative to the window) where the
popover’s arrow tip should appear.  The location of the
popover itself depends on the arrow placement chosen by
"idealArrowPositionForFrame:parentWindow:".

IMPORTANT:	This must be implemented by the delegate.

See also "moveToIdealPosition".

(2.7)
*/
- (NSPoint)
idealAnchorPointForFrame:(NSRect)	parentFrame
parentWindow:(NSWindow*)			parentWindow
{
#pragma unused(parentWindow)
	NSPoint		result = [self->delegatePtr->returnTargetRef()
							popoverManager:self->selfRef idealAnchorPointForFrame:parentFrame parentWindow:parentWindow];
	
	
	return result;
}// idealAnchorPointForFrame:parentWindow:


/*!
Returns arrow placement information for the popover.

IMPORTANT:	This must be implemented by the delegate.

(2.7)
*/
- (Popover_Properties)
idealArrowPositionForFrame:(NSRect)		parentFrame
parentWindow:(NSWindow*)				parentWindow
{
	Popover_Properties	result = [self->delegatePtr->returnTargetRef()
									popoverManager:self->selfRef idealArrowPositionForFrame:parentFrame parentWindow:parentWindow];
	
	
	return result;
}// idealArrowPositionForFrame:parentWindow:


/*!
Returns the dimensions that the popover should initially have.

IMPORTANT:	This must be implemented by the delegate.

See also "setToIdealSize".

(2.7)
*/
- (NSSize)
idealSize
{
	NSSize		result = NSMakeSize(100, 100); // arbitrary (delegate must override)
	
	
	[self->delegatePtr->returnTargetRef() popoverManager:self->selfRef getIdealSize:&result];
	
	return result;
}// idealSize


/*!
Returns YES only if the popover is currently displayed.

(2.7)
*/
- (BOOL)
isVisible
{
	return [self->containerWindow isVisible];
}// isVisible


/*!
Moves the popover window to the appropriate window level,
orders it in front and gives it keyboard focus.

See also "makeKeyAndOrderFrontIfVisible".

(2017.06)
*/
- (void)
makeKeyAndOrderFront
{
	[self popOverMakeKey:YES forceVisible:YES];
}// makeKeyAndOrderFront


/*!
If the popover is visible, moves it to the appropriate window
level, orders it in front and gives it keyboard focus;
otherwise, does nothing.

See also "orderFrontIfVisible".

(2017.06)
*/
- (void)
makeKeyAndOrderFrontIfVisible
{
	[self popOverMakeKey:YES forceVisible:NO];
}// makeKeyAndOrderFrontIfVisible


/*!
Moves the popover to its correct position relative to
its parent window.

See also "idealAnchorPointForFrame:parentWindow:".

(2.7)
*/
- (void)
moveToIdealPosition
{
	NSWindow*			parentWindow = [self parentCocoaWindow];
	NSRect				parentFrame = [parentWindow frame];
	NSPoint				popoverLocation = [self idealAnchorPointForFrame:parentFrame parentWindow:parentWindow];
	Popover_Properties	arrowType = [self idealArrowPositionForFrame:parentFrame parentWindow:parentWindow];
	
	
	[self->containerWindow setPointWithAutomaticPositioning:popoverLocation preferredSide:arrowType];
	
	// clear the flag that is used to track delayed
	// invocations of this request
	self->isAutoPositionQueued = NO;
}// moveToIdealPosition


/*!
Arranges to call "moveToIdealPosition" after the
specified delay, and sets a flag to guard against
further requests until this one is fulfilled.

(2016.05)
*/
- (void)
moveToIdealPositionAfterDelay:(float)	aDelayInSeconds
{
	if (NO == self->isAutoPositionQueued)
	{
		//__weak typeof(self)	weakSelf = self; // future
		PopoverManager_WC*		strongSelf = self;
		
		
		[strongSelf retain];
		CocoaExtensions_RunLater(aDelayInSeconds,
									^{
										[strongSelf moveToIdealPosition];
										[strongSelf release]; // TEMPORARY
									});
		self->isAutoPositionQueued = YES;
	}
}// moveToIdealPositionAfterDelay


/*!
If the popover is visible, moves it to the appropriate window
level and orders it in front; otherwise, does nothing.

(2017.06)
*/
- (void)
orderFrontIfVisible
{
	[self popOverMakeKey:NO forceVisible:NO];
}// orderFrontIfVisible


/*!
Returns the Cocoa window that represents the parent
window, even if that is a Carbon window.

(2.7)
*/
- (NSWindow*)
parentCocoaWindow
{
	NSWindow*	result = [self->parentView window];
	
	
#if POPOVER_MANAGER_SUPPORTS_CARBON
	if ((nil == result) && (nullptr != self->parentCarbonWindow))
	{
		result = CocoaBasic_ReturnNewOrExistingCocoaCarbonWindow(self->parentCarbonWindow);
	}
#endif
	
	return result;
}// parentCocoaWindow


/*!
If the popover is visible or "aForceVisibleFlag" is YES,
moves the popover window to the appropriate window level
and orders it in front.  Also sets the keyboard focus if
requested.

Although you can call this directly in special cases, it
is probably more convenient to use the methods that
delegate to this one, like "makeKeyAndOrderFrontIfVisible".

(2017.06)
*/
- (void)
popOverMakeKey:(BOOL)	aBecomeKeyFlag
forceVisible:(BOOL)		aForceVisibleFlag
{
	if ([self isVisible] || (aForceVisibleFlag))
	{
	#if POPOVER_MANAGER_SUPPORTS_CARBON
		// TEMPORARY; in Carbon-Cocoa hybrid environments popovers do not necessarily
		// handle the parent window correctly in all situations, so the simplest
		// solution is just to force the parent window to deactivate (in the future
		// when all windows are pure Cocoa, it should be very easy to support cases
		// where popovers do not dim their parent windows at any time)
		if (nil != self->parentCarbonWindow)
		{
			UNUSED_RETURN(OSStatus)ActivateWindow(self->parentCarbonWindow, false/* activate */);
		}
	#endif
		
		[self->containerWindow setLevel:([[self parentCocoaWindow] level] + 1)];
		if (aBecomeKeyFlag)
		{
			[self->containerWindow makeFirstResponder:self->logicalFirstResponder];
			[self->containerWindow makeKeyAndOrderFront:nil];
		}
		else
		{
			[self->containerWindow orderFront:nil];
		}
	}
}// popOverMakeKey:forceVisible:


/*!
Moves the popover window to another window level that
will allow normal windows to overlap it.  This should be
done when the parent window of the popover is deactivated.

(2.7)
*/
- (void)
popUnder
{
	[self->containerWindow setLevel:[[self parentCocoaWindow] level]];
}// popUnder


/*!
Invokes "removeWindowWithAcceptance:afterDelay:" with a short
delay.  Useful when hiding amidst other animations that should
not be interrupted by closing animations.

(2.7)
*/
- (void)
removeWindowAfterDelayWithAcceptance:(BOOL)		isAccepted
{
	[self removeWindowWithAcceptance:isAccepted afterDelay:0.03f];
}// removeWindowAfterDelayWithAcceptance:


/*!
Invokes "removeWindowWithAcceptance:afterDelay:" with no delay.
This is the normal case.

(2.7)
*/
- (void)
removeWindowWithAcceptance:(BOOL)	isAccepted
{
	[self removeWindowWithAcceptance:isAccepted afterDelay:0];
}// removeWindowWithAcceptance:


/*!
Hides the popover window, removing it as a child of its
parent window.

The "isAccepted" flag may cause the animation to vary to
show the user that the window’s changes are being accepted
(as opposed to being discarded entirely).

If a delay is specified then the window is only hidden
after that time period.

The "close" method is invoked so you can detect this
event through NSWindowWillCloseNotification.

See also "display".

(2.7)
*/
- (void)
removeWindowWithAcceptance:(BOOL)	isAccepted
afterDelay:(float)					aDelay
{
	float const		kDelayZeroEpsilon = 0.001f; // arbitrary; less than this is treated as immediate
	
	
	if (self->isHeldOpenBySheet)
	{
		return;
	}
	
	// if a dummy sheet was opened to absorb parent-window events, end it
	if (nil != self->dummySheet)
	{
		[NSApp endSheet:self->dummySheet];
		[self->dummySheet orderOut:NSApp];
		[self->dummySheet release], self->dummySheet = nil;
	}
	
	// hide the popover; remove the parent window association first to keep
	// the parent window from disappearing on some versions of Mac OS X!
	if ([self->containerWindow parentWindow] == [self parentCocoaWindow])
	{
		[[self parentCocoaWindow] removeChildWindow:self->containerWindow];
	}
	switch (self->animationType)
	{
	case kPopoverManager_AnimationTypeNone:
		{
			if ([NSWindow instancesRespondToSelector:@selector(setAnimationBehavior:)])
			{
				// remove window animations
				[self->containerWindow setAnimationBehavior:FUTURE_SYMBOL(2, NSWindowAnimationBehaviorNone)];
			}
			
			if (aDelay < kDelayZeroEpsilon)
			{
				[self->containerWindow close];
			}
			else
			{
				NSWindow*	window = self->containerWindow;
				
				
				[window retain];
				CocoaExtensions_RunLater(aDelay,
											^{
												[window close];
												[window release];
											});
			}
		}
		break;
	
	default:
		if (kPopoverManager_BehaviorTypeDialog == self->behaviorType)
		{
			if ([NSWindow instancesRespondToSelector:@selector(setAnimationBehavior:)])
			{
				// remove system-provided window animations because this
				// has a custom close animation style
				[self->containerWindow setAnimationBehavior:FUTURE_SYMBOL(2, NSWindowAnimationBehaviorNone)];
			}
			
			CocoaAnimation_TransitionWindowForRemove(self->containerWindow, isAccepted);
		}
		else
		{
			// currently, all other closing animations are the same
			if ([self->containerWindow respondsToSelector:@selector(setAnimationBehavior:)])
			{
				// create fade-out effect; admittedly a bit of a hack...
				[self->containerWindow setAnimationBehavior:FUTURE_SYMBOL(4, NSWindowAnimationBehaviorUtilityWindow)];
			}
			
			if (aDelay < kDelayZeroEpsilon)
			{
				[self->containerWindow close];
			}
			else
			{
				NSWindow*	window = self->containerWindow;
				
				
				[window retain];
				CocoaExtensions_RunLater(aDelay,
											^{
												[window close];
												[window release];
											});
			}
		}
		break;
	}
}// removeWindowWithAcceptance:afterDelay:


/*!
Resizes the popover to be large enough for the minimum
size of its content view.

(2.7)
*/
- (void)
setToIdealSize
{
	NSRect		parentFrame = [self->containerWindow frameRectForViewSize:[self idealSize]];
	
	
	[self->containerWindow setFrame:parentFrame display:NO];
	self->containerWindow.minSize = parentFrame.size;
}// setToIdealSize


#pragma mark NSColorPanel


/*!
Forwards this message to the main view manager if the
panel implements a "changeColor:" method.

NOTE:	It is possible that one day panels will be set up
		as responders themselves and placed directly in
		the responder chain.  For now this is sufficient.

(4.1)
*/
- (void)
changeColor:(id)	sender
{
	NSObject*	asNSObject = STATIC_CAST(self->delegatePtr->returnTargetRef(), NSObject*);
	
	
	if ([asNSObject respondsToSelector:@selector(changeColor:)])
	{
		[asNSObject changeColor:sender];
	}
}// changeColor:


#pragma mark NSFontPanel


/*!
Forwards this message to the main view manager if the
panel implements a "changeFont:" method.

NOTE:	It is possible that one day panels will be set up
		as responders themselves and placed directly in
		the responder chain.  For now this is sufficient.

(4.1)
*/
- (void)
changeFont:(id)		sender
{
	NSObject*	asNSObject = STATIC_CAST(self->delegatePtr->returnTargetRef(), NSObject*);
	
	
	if ([asNSObject respondsToSelector:@selector(changeFont:)])
	{
		[asNSObject changeFont:sender];
	}
}// changeFont:


#pragma mark Popover_ResizeDelegate


/*!
Assists the dynamic resize of a popover window by indicating
whether or not there are per-axis constraints on resizing.

This is implemented by using the similar method from
PopoverManager_Delegate.

(2017.05)
*/
- (void)
popover:(Popover_Window*)			aPopover
getHorizontalResizeAllowed:(BOOL*)	outHorizontalFlagPtr
getVerticalResizeAllowed:(BOOL*)	outVerticalFlagPtr
{
#pragma unused(aPopover)
	id		delegate = self->delegatePtr->returnTargetRef();
	
	
	if ([delegate respondsToSelector:@selector(popoverManager:getHorizontalResizeAllowed:getVerticalResizeAllowed:)])
	{
		[delegate popoverManager:self->selfRef
									getHorizontalResizeAllowed:outHorizontalFlagPtr
									getVerticalResizeAllowed:outVerticalFlagPtr];
	}
}// popover:getHorizontalResizeAllowed:getVerticalResizeAllowed:


#pragma mark Notifications


/*!
Ensures that the popover does not obscure windows in
other applications.

(2.8)
*/
- (void)
applicationDidBecomeActive:(NSNotification*)	aNotification
{
#pragma unused(aNotification)
	if ([self->containerWindow isKeyWindow])
	{
		[self makeKeyAndOrderFrontIfVisible];
	}
}// applicationDidBecomeActive:


/*!
Ensures that the popover does not obscure windows in
other applications.

(2.8)
*/
- (void)
applicationDidResignActive:(NSNotification*)	aNotification
{
#pragma unused(aNotification)
	if ([self isVisible])
	{
		[self popUnder];
	}
}// applicationDidResignActive:


/*!
Ensures that the popover does not obscure windows other than
its own parent window.

(2.8)
*/
- (void)
parentWindowDidBecomeKey:(NSNotification*)		aNotification
{
	NSWindow*	newKeyWindow = (NSWindow*)[aNotification object];
	
	
	if (newKeyWindow == [self parentCocoaWindow])
	{
		if (kPopoverManager_BehaviorTypeDialog == self->behaviorType)
		{
			// allow other normal windows to sit above background popovers
			[self makeKeyAndOrderFrontIfVisible];
			// UNIMPLEMENTED: determine how to deactivate window frame in Cocoa
		}
		else if (kPopoverManager_BehaviorTypeFloating == self->behaviorType)
		{
			// allow other normal windows to sit above background popovers
			[self makeKeyAndOrderFrontIfVisible];
			// UNIMPLEMENTED: determine how to deactivate window frame in Cocoa
		}
	}
}// parentWindowDidBecomeKey:


/*!
Adjusts the location of the popover if the parent window
is moved (as it might have moved slightly offscreen).

(2016.05)
*/
- (void)
parentWindowDidMove:(NSNotification*)		aNotification
{
	NSWindow*	resizedWindow = (NSWindow*)[aNotification object];
	
	
	if (resizedWindow == [self parentCocoaWindow])
	{
		if ([self isVisible])
		{
			// IMPORTANT: since this notification occurs constantly during
			// a live move of the parent window, limit number of responses
			[self moveToIdealPositionAfterDelay:0.3f/* arbitrary */];
		}
	}
}// parentWindowDidMove:


/*!
Ensures that the popover does not obscure windows other than
its own parent window.

(2.8)
*/
- (void)
parentWindowDidResignKey:(NSNotification*)		aNotification
{
	NSWindow*	formerKeyWindow = (NSWindow*)[aNotification object];
	
	
	if (formerKeyWindow == [self parentCocoaWindow])
	{
		if (kPopoverManager_BehaviorTypeDialog == self->behaviorType)
		{
			// when the parent window is active, the popover should remain on top
			if ([self isVisible])
			{
				[self popUnder];
			}
		}
	}
}// parentWindowDidResignKey:


/*!
Adjusts the location of the popover if the parent window
is resized.

(2.8)
*/
- (void)
parentWindowDidResize:(NSNotification*)		aNotification
{
	NSWindow*	resizedWindow = (NSWindow*)[aNotification object];
	
	
	if (resizedWindow == [self parentCocoaWindow])
	{
		if ([self isVisible])
		{
			// IMPORTANT: since this notification occurs constantly during
			// a live move of the parent window, limit number of responses
			[self moveToIdealPositionAfterDelay:0.3f/* arbitrary */];
		}
	}
}// parentWindowDidResize:


/*!
Responds when the dummy sheet is closed, allowing the
popover to be released.  (See "windowWillBeginSheet:".)

(2016.05)
*/
- (void)
windowDidEndSheet:(NSNotification*)		aNotification
{
#pragma unused(aNotification)
	//NSWindow*	sheetParentWindow = (NSWindow*)[aNotification object];
	
	
	self->isHeldOpenBySheet = NO;
	[self release];
}// windowDidEndSheet:


/*!
Dismisses the popover when the user goes somewhere else,
unless the reason for that focus change was to display
a sheet on top or activate a floating panel.

(2.7)
*/
- (void)
windowDidResignKey:(NSNotification*)		aNotification
{
	NSWindow*	formerKeyWindow = (NSWindow*)[aNotification object];
	
	
	if (formerKeyWindow == self->containerWindow)
	{
		BOOL	removePopover = YES;
		
		
		if (kPopoverManager_BehaviorTypeDialog == self->behaviorType)
		{
			// dialogs try to retain keyboard focus, expecting to be
			// dismissed in an explicit way (e.g. via buttons)
			removePopover = NO;
			if ([self isVisible])
			{
				[self popUnder];
			#if 0
				if (nullptr == self->parentCarbonWindow)
				{
					if ([NSApp keyWindow] == [self parentCocoaWindow])
					{
						// force clicks in the parent to be ignored
						[self->containerWindow makeKeyWindow];
					}
				}
			#endif
			}
		}
		else if (kPopoverManager_BehaviorTypeFloating == self->behaviorType)
		{
			// floating windows stay on top but relinquish focus
			removePopover = NO;
			if ([self isVisible])
			{
				[self orderFrontIfVisible];
			}
		}
		
		if (removePopover)
		{
			if ([self isVisible])
			{
				if ((nil == [formerKeyWindow attachedSheet]) &&
					(NO == [[NSApp keyWindow] isKindOfClass:NSPanel.class]))
				{
					[self removeWindowWithAcceptance:NO];
				}
			}
		}
	}
}// windowDidResignKey:


/*!
Responds when the popover displays a sheet.  This temporarily
prevents the popover from disappearing.

(2016.05)
*/
- (void)
windowWillBeginSheet:(NSNotification*)		aNotification
{
#pragma unused(aNotification)
	//NSWindow*	sheetParentWindow = (NSWindow*)[aNotification object];
	
	
	[self retain];
	self->isHeldOpenBySheet = YES;
}// windowWillBeginSheet:


@end // PopoverManager_WC

// BELOW IS REQUIRED NEWLINE TO END FILE
