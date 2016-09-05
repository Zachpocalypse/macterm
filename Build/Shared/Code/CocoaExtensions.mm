/*!	\file CocoaExtensions.mm
	\brief Methods added to standard classes.
*/
/*###############################################################

	Simple Cocoa Wrappers Library
	© 2008-2016 by Kevin Grant
	
	This library is free software; you can redistribute it or
	modify it under the terms of the GNU Lesser Public License
	as published by the Free Software Foundation; either version
	2.1 of the License, or (at your option) any later version.
	
	This program is distributed in the hope that it will be
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

#import <CocoaExtensions.objc++.h>

// Mac includes
#import <Cocoa/Cocoa.h>

// library includes
#import <CocoaFuture.objc++.h>
#import <ColorUtilities.h>



#pragma mark Public Methods


/*!
Calls CocoaExtensions_RunLaterInQueue() using the main queue.

(2016.05)
*/
void
CocoaExtensions_RunLater	(Float64	inDelayAsFractionOfSeconds,
							 void		(^inBlock)())
{
	CocoaExtensions_RunLaterInQueue(dispatch_get_main_queue(), inDelayAsFractionOfSeconds, inBlock);
}// RunLater


/*!
Replaces "performSelector:withObject:afterDelay:" by calling
dispatch_after() with a block.

(2016.05)
*/
void
CocoaExtensions_RunLaterInQueue		(dispatch_queue_t const&	inQueue,
									 Float64					inDelayAsFractionOfSeconds,
									 void						(^inBlock)())
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, STATIC_CAST(inDelayAsFractionOfSeconds * NSEC_PER_SEC, int64_t)),
					inQueue, inBlock);
}// RunLaterInQueue


#pragma mark -
@implementation NSColor (CocoaExtensions_NSColor)


#pragma mark Class Methods


/*!
Provides “highlighted for search results” versions of the given
foreground and background colors, overwriting the colors pointed to
by each argument.  Returns true unless there was a problem changing
one or both colors.

(1.10)
*/
+ (BOOL)
searchResultColorsForForeground:(NSColor**)		inoutForegroundColor
background:(NSColor**)							inoutBackgroundColor
{
	BOOL	result = YES;
	
	
	if ((nullptr == inoutForegroundColor) || (nullptr == inoutBackgroundColor))
	{
		result = NO;
	}
	else
	{
		Float32 const	kTolerance = 0.5; // color intensities can vary by this much and still be considered black or white
		NSColor*		foregroundRGB = [*inoutForegroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		NSColor*		backgroundRGB = [*inoutBackgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		
		
		if ((nil != foregroundRGB) && (nil != backgroundRGB))
		{
			//NSColor*	searchHighlightColor = [NSColor yellowColor];
			NSColor*	searchHighlightColor = [NSColor colorWithCalibratedRed:0.92f green:1.0f blue:0.0f alpha:1.0f];
			
			
			if (([foregroundRGB brightnessComponent] < kTolerance) &&
				([backgroundRGB brightnessComponent] > (1.0 - kTolerance)))
			{
				// approximately monochromatic; in this case it’s safe to pick a
				// target color because the appearance against black/white is known
				*inoutForegroundColor = [NSColor blackColor];
				*inoutBackgroundColor = searchHighlightColor;
			}
			else if ([backgroundRGB brightnessComponent] < kTolerance)
			{
				// very dark background; therefore, darkening the background will
				// not make it clear where the result is; brighten it instead
				*inoutForegroundColor = [foregroundRGB blendedColorWithFraction:0.9f/* arbitrary */ ofColor:[NSColor whiteColor]];
				*inoutBackgroundColor = [backgroundRGB blendedColorWithFraction:0.3f/* arbitrary */ ofColor:[NSColor blackColor]];
			}
			else
			{
				// typical case; some combination of colors, just find darker
				// colors to show results in this case
				*inoutForegroundColor = [foregroundRGB blendedColorWithFraction:0.8f/* arbitrary */ ofColor:[NSColor blackColor]];
				*inoutBackgroundColor = [backgroundRGB blendedColorWithFraction:0.8f/* arbitrary */ ofColor:searchHighlightColor];
			}
		}
		else
		{
			// error; leave unchanged
			result = NO;
		}
	}
	
	return result;
}// searchResultColorsForForeground:background:


/*!
Provides “selected” versions of the given foreground and background
colors, overwriting the colors pointed to by each argument.  Returns
true unless there was a problem changing one or both colors.

Since traditional selection schemes assume that white is the
background color, this routine examines the background color and
will only use the system-wide highlight color if the background is
approximately white.  Otherwise, the actual colors are used to find
an appropriate selection color (which will usually be slightly
“darker” than the given colors, unless the colors are close to
black).

(1.10)
*/
+ (BOOL)
selectionColorsForForeground:(NSColor**)	inoutForegroundColor
background:(NSColor**)						inoutBackgroundColor
{
	BOOL	result = YES;
	
	
	if ((nullptr == inoutForegroundColor) || (nullptr == inoutBackgroundColor))
	{
		result = NO;
	}
	else
	{
		Float32 const	kTolerance = 0.5; // color intensities can vary by this much and still be considered black or white
		NSColor*		foregroundRGB = [*inoutForegroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		NSColor*		backgroundRGB = [*inoutBackgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		
		
		if ((nil != foregroundRGB) && (nil != backgroundRGB))
		{
			if (([foregroundRGB brightnessComponent] < kTolerance) &&
				([backgroundRGB brightnessComponent] > (1.0 - kTolerance)))
			{
				// approximately monochromatic; this is what the highlight color
				// is “traditionally” intended for, so it should look okay; use it
				*inoutForegroundColor = foregroundRGB;
				*inoutBackgroundColor = [NSColor selectedTextBackgroundColor];
			}
			else if ([backgroundRGB brightnessComponent] < kTolerance)
			{
				// very dark background; therefore, darkening the background will
				// not make it clear where the selection is; brighten it instead
				*inoutForegroundColor = [foregroundRGB blendedColorWithFraction:0.2f/* arbitrary */ ofColor:[NSColor whiteColor]];
				*inoutBackgroundColor = [backgroundRGB blendedColorWithFraction:0.33f/* arbitrary */ ofColor:[NSColor whiteColor]];
			}
			else
			{
				// typical case; some combination of colors, just find darker
				// colors to show highlighted text in this case
				*inoutForegroundColor = [foregroundRGB blendedColorWithFraction:0.2f/* arbitrary */ ofColor:[NSColor blackColor]];
				*inoutBackgroundColor = [backgroundRGB blendedColorWithFraction:0.33f/* arbitrary */ ofColor:[NSColor blackColor]];
			}
		}
		else
		{
			// error; leave unchanged
			result = NO;
		}
	}
	
	return result;
}// selectionColorsForForeground:background:


#pragma mark New Methods: Constructing Color Variations


/*!
Returns a color that is similar to the current color but
with an arbitrarily-darker shade.

(1.10)
*/
- (NSColor*)
colorCloserToBlack
{
	NSColor*	result = [self blendedColorWithFraction:0.5/* arbitrary */ ofColor:[NSColor blackColor]];
	
	
	if (nil == result)
	{
		result = [[self retain] autorelease];
	}
	return result;
}// colorCloserToBlack


/*!
Returns a color that is similar to the current color but
with an arbitrarily-lighter shade.

(1.10)
*/
- (NSColor*)
colorCloserToWhite
{
	NSColor*	result = [self blendedColorWithFraction:0.5/* arbitrary */ ofColor:[NSColor whiteColor]];
	
	
	if (nil == result)
	{
		result = [[self retain] autorelease];
	}
	return result;
}// colorCloserToWhite


/*!
Returns a color that is a noticeably different shade; if the
color is very dark, this will be like "colorCloserToWhite";
otherwise it will be like "colorCloserToBlack".

(1.10)
*/
- (NSColor*)
colorWithShading
{
	NSColor*	asRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor*	result = asRGB;
	
	
	if (nil != asRGB)
	{
		Float32 const	kTolerance = 0.5; // color intensities can vary by this much and still be considered black or white
		
		
		if ([asRGB brightnessComponent] < kTolerance)
		{
			// dark; make whiter
			result = [self colorCloserToWhite];
		}
		else
		{
			// light; make blacker
			result = [self colorCloserToBlack];
		}
	}
	
	if (nil == result)
	{
		result = [[self retain] autorelease];
	}
	
	return result;
}// colorWithShading


#pragma mark New Methods: Setting Color in Graphics Context


/*!
Sets this NSColor value as the background RGB color
of the specified Core Graphics context.

(4.1)
*/
- (void)
setAsBackgroundInCGContext:(CGContextRef)	aDrawingContext
{
	NSColor*		asRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	
	CGContextSetRGBFillColor(aDrawingContext, [asRGB redComponent], [asRGB greenComponent],
								[asRGB blueComponent], [asRGB alphaComponent]);
}// setAsBackgroundInCGContext:


/*!
TEMPORARY.  FOR TRANSITIONAL CODE ONLY.  DEPRECATED.

Sets this NSColor value as the background RGB color
of the current QuickDraw graphics port.

(4.1)
*/
- (void)
setAsBackgroundInQDCurrentPort
{
	CGDeviceColor	asDeviceColor; // not really a device color, just convenient for RGB floats
	RGBColor		asQuickDrawRGB;
	NSColor*		asRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	
	asDeviceColor.red = [asRGB redComponent];
	asDeviceColor.green = [asRGB greenComponent];
	asDeviceColor.blue = [asRGB blueComponent];
	asQuickDrawRGB = ColorUtilities_QuickDrawColorMake(asDeviceColor);
	RGBBackColor(&asQuickDrawRGB);
}// setAsBackgroundInQDCurrentPort


/*!
Sets this NSColor value as the foreground RGB color
of the specified Core Graphics context.

(4.1)
*/
- (void)
setAsForegroundInCGContext:(CGContextRef)	aDrawingContext
{
	NSColor*		asRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	
	CGContextSetRGBStrokeColor(aDrawingContext, [asRGB redComponent], [asRGB greenComponent],
								[asRGB blueComponent], [asRGB alphaComponent]);
}// setAsForegroundInCGContext:


/*!
TEMPORARY.  FOR TRANSITIONAL CODE ONLY.  DEPRECATED.

Sets this NSColor value as the foreground RGB color
of the current QuickDraw graphics port.

(4.1)
*/
- (void)
setAsForegroundInQDCurrentPort
{
	CGDeviceColor	asDeviceColor; // not really a device color, just convenient for RGB floats
	RGBColor		asQuickDrawRGB;
	NSColor*		asRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	
	asDeviceColor.red = [asRGB redComponent];
	asDeviceColor.green = [asRGB greenComponent];
	asDeviceColor.blue = [asRGB blueComponent];
	asQuickDrawRGB = ColorUtilities_QuickDrawColorMake(asDeviceColor);
	RGBForeColor(&asQuickDrawRGB);
}// setAsForegroundInQDCurrentPort


@end // NSColor (CocoaExtensions_NSColor)


#pragma mark -
@implementation CocoaExtensions_ObserverSpec //@{


@synthesize context = _context;
@synthesize keyPath = _keyPath;


@end //}


#pragma mark -
@implementation NSInvocation (CocoaExtensions_NSInvocation)


#pragma mark Class Methods


/*!
Creates an NSInvocation object using the usual autorelease
class method, but automatically pulls the method signature
from the target object and automatically calls "setTarget:"
and "setSelector:" accordingly.

You must still call setArgument:atIndex: for any other
arguments that the selector requires.

(1.9)
*/
+ (NSInvocation*)
invocationWithSelector:(SEL)	aSelector
target:(id)						aTarget
{
	NSInvocation*	result = [NSInvocation invocationWithMethodSignature:
											[aTarget methodSignatureForSelector:aSelector]];
	
	
	[result setTarget:aTarget]; // index 0 implicitly
	[result setSelector:aSelector]; // index 1 implicitly
	
	return result;
}// invocationWithSelector:target:


@end // NSInvocation (CocoaExtensions_NSInvocation)


#pragma mark -
@implementation NSObject (CocoaExtensions_NSObject)


#pragma mark New Methods: Simpler Notifications


/*!
Calls "postNotificationName:object:" on the default
NSNotificationCenter, with the object "self".

This utility is meant to shorten code that is required
very frequently, and to encourage clearer terminology.

(1.11)
*/
- (void)
postNote:(NSString*)	aNotificationName
{
	[[NSNotificationCenter defaultCenter] postNotificationName:aNotificationName object:self];
}// postNote:


/*!
Calls "postNote:queued:coalescing:" with a default coalescing
value of "NSNotificationNoCoalescing".

(2016.04)
*/
- (void)
postNote:(NSString*)		aNotificationName
queued:(NSPostingStyle)		aPostingStyle
{
	[self postNote:aNotificationName queued:aPostingStyle coalescing:NSNotificationNoCoalescing];
}// postNote:queued:


/*!
Calls "enqueueNotification:postingStyle:coalesceMask:forModes:"
on the default NSNotificationQueue, using an NSNotification
object on the object "self".

(2016.04)
*/
- (void)
postNote:(NSString*)					aNotificationName
queued:(NSPostingStyle)					aPostingStyle
coalescing:(NSNotificationCoalescing)	aCoalescingMask
{
	NSNotification*		notificationObject = [NSNotification
												notificationWithName:aNotificationName
																		object:self];
	
	
	[[NSNotificationQueue defaultQueue]
		enqueueNotification:notificationObject postingStyle:aPostingStyle
							coalesceMask:aCoalescingMask forModes:nil];
}// postNote:queued:coalescing:


/*!
Calls "addObserver:selector:name:object:" on the default
NSNotificationCenter, setting the observer to "self" and
the other parameters as indicated.  (Therefore, you must
remove it later; see "ignoreWhenObjectsPostNotes" and
"ignoreWhenObject:postsNote:".)

This utility is meant to shorten code that is required
very frequently, and to encourage clearer terminology.

(1.11)
*/
- (void)
whenObject:(id)			anObservedObject
postsNote:(NSString*)	aNotificationName
performSelector:(SEL)	aSelector
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:aSelector
														name:aNotificationName
														object:anObservedObject];
}// whenObject:postsNote:performSelector:


/*!
Removes the specified notification’s handler from the
default NSNotificationCenter.

(1.11)
*/
- (void)
ignoreWhenObject:(id)	anObservedObject
postsNote:(NSString*)	aNotificationName
{
	[[NSNotificationCenter defaultCenter]
		removeObserver:self name:aNotificationName object:anObservedObject];
}// ignoreWhenObject:postsNote:


/*!
Removes all of the current object’s observers from the
default NSNotificationCenter.

(1.11)
*/
- (void)
ignoreWhenObjectsPostNotes
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}// ignoreWhenObjectsPostNotes


#pragma mark New Methods: Simpler Observers with Easier Cleanup


/*!
Calls "addObserver:forKeyPath:options:context:" but
returns an object capturing the key state of this
call so that you can correctly remove the observer
later (see "removeObserverSpecifiedWith:").

(2016.04)
*/
- (CocoaExtensions_ObserverSpec*)
observePropertyFromKeyPath:(NSString*)	aKeyPath
ofObject:(id)							anObject
options:(NSKeyValueObservingOptions)	anOptionSet
context:(void*)							aContext
{
	CocoaExtensions_ObserverSpec*	result = [[CocoaExtensions_ObserverSpec alloc] init];
	
	
	// capture all information necessary to correctly
	// remove this observer at a later time
	result.keyPath = aKeyPath;
	result.context = aContext;
	
	// install the observer
	[anObject addObserver:self forKeyPath:aKeyPath options:anOptionSet context:aContext];
	
	return result;
}// observePropertyFromKeyPath:fromSelector:options:context:


/*!
Simplified version that assumes the target and observer are
both the current object, with no special options or context.
Calls "observePropertyOfObject:fromSelector:options:context:".

(2016.04)
*/
- (CocoaExtensions_ObserverSpec*)
observePropertyFromSelector:(SEL)		aSelectorForKeyPath
{
	CocoaExtensions_ObserverSpec*	result = nil;
	
	
	result = [self observePropertyFromSelector:aSelectorForKeyPath
												ofObject:self
												options:0
												context:nullptr];
	return result;
}// observePropertyFromSelector:


/*!
Calls "observePropertyFromKeyPath:fromSelector:options:context:"
with the constraint that the target key path MUST be expressed
as a real selector (the property method).

It is highly recommended that key paths be expressed in terms of
valid selectors wherever possible, to gain compile-time
protection against typos that do not correspond to any known
method name.  While this is still not foolproof, it is likely to
catch a lot of common mistakes.

(2016.04)
*/
- (CocoaExtensions_ObserverSpec*)
observePropertyFromSelector:(SEL)		aSelectorForKeyPath
ofObject:(id)							anObject
options:(NSKeyValueObservingOptions)	anOptionSet
context:(void*)							aContext
{
	CocoaExtensions_ObserverSpec*	result = nil;
	
	
	result = [self observePropertyFromKeyPath:NSStringFromSelector(aSelectorForKeyPath)
												ofObject:anObject
												options:anOptionSet
												context:aContext];
	return result;
}// observePropertyFromSelector:ofObject:options:context:


/*!
Calls "removeObserver:forKeyPath:context:" using the
properties of the given object.

(2016.04)
*/
- (void)
removeObserverSpecifiedWith:(CocoaExtensions_ObserverSpec*)		aSpec
{
	[self removeObserver:self forKeyPath:aSpec.keyPath context:aSpec.context];
}// removeObserverSpecifiedWith:


/*!
For an array of "CocoaExtensions_ObserverSpec*" values,
calls "removeObserverSpecifiedWith:" on each.

It is highly recommended that classes allocate a single
array field to hold observer data as observers are
registered so that their "dealloc" teardown code can
simply call this helper function to safely remove all
of the observers.

(2016.04)
*/
- (void)
removeObserversSpecifiedInArray:(NSArray*)	aSpecArray
{
	for (id object in aSpecArray)
	{
		assert([object isKindOfClass:CocoaExtensions_ObserverSpec.class]);
		CocoaExtensions_ObserverSpec*	asSpec = STATIC_CAST(object, CocoaExtensions_ObserverSpec*);
		
		
		[self removeObserverSpecifiedWith:asSpec];
	}
}// removeObserversSpecifiedInArray:


@end // NSObject (CocoaExtensions_NSObject)


#pragma mark -
@implementation NSValue (CocoaExtensions_NSValue)


#pragma mark Class Methods: Core Graphics Data


/*!
Returns an NSValue* from CGPoint data, much like its version
on iOS (and similar to the Mac OS X "valueWithPoint:" that
accepts an NSPoint).

(1.11)
*/
+ (NSValue*)
valueWithCGPoint:(CGPoint)	aPoint
{
	return [NSValue valueWithPoint:NSPointFromCGPoint(aPoint)];
}// valueWithCGPoint:


/*!
Returns an NSValue* from CGRect data, much like its version
on iOS (and similar to the Mac OS X "valueWithRect:" that
accepts an NSRect).

(1.11)
*/
+ (NSValue*)
valueWithCGRect:(CGRect)	aRect
{
	return [NSValue valueWithRect:NSRectFromCGRect(aRect)];
}// valueWithCGRect:


/*!
Returns an NSValue* from CGRect data, much like its version
on iOS (and similar to the Mac OS X "valueWithRect:" that
accepts an NSRect).

(1.11)
*/
+ (NSValue*)
valueWithCGSize:(CGSize)	aSize
{
	return [NSValue valueWithSize:NSSizeFromCGSize(aSize)];
}// valueWithCGSize:


@end // NSValue (CocoaExtensions_NSValue)


#pragma mark -
@implementation NSWindow (CocoaExtensions_NSWindow)


#pragma mark New Methods: Coordinate Translation


/*!
Translates coordinates from the local coordinate system of
the window into the screen coordinate system, while “flipping”
to make the coordinates relative to the top of the screen.

This is not recommended.  It is useful when translating code
that is still based in the QuickDraw and Carbon environments.

(1.9)
*/
- (NSPoint)
localToGlobalRelativeToTopForPoint:(NSPoint)	aLocalPoint
{
	NSPoint		result = aLocalPoint;
	NSPoint		windowGlobalPosition = [self frame].origin;
	
	
	// flip local Y
	result.y = (self.frame.size.height - result.y);
	
	// flip global Y
	windowGlobalPosition.y = ([self screen].frame.size.height - self.frame.origin.y - self.frame.size.height);
	
	// offset final coordinates based on flipped global
	result.x += windowGlobalPosition.x;
	result.y += windowGlobalPosition.y;
	
	return result;
}// localToGlobalRelativeToTopForPoint


@end // NSWindow (CocoaExtensions_NSWindow)

// BELOW IS REQUIRED NEWLINE TO END FILE
