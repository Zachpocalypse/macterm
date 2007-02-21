/*!	\file MemoryBlockLocker.template.h
	\brief Provides a locking mechanism for an opaque reference
	that may really point to a relocatable block of memory.
	
	This can be used to implement opaque reference types for
	objects not meant to be accessed directly in C.  The class
	is abstract, as it does not handle any particular kind of
	memory block; create a subclass to do that.
*/
/*###############################################################

	Data Access Library 1.4
	� 1998-2006 by Kevin Grant
	
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

#include "UniversalDefines.h"

#ifndef __MEMORYBLOCKLOCKER__
#define __MEMORYBLOCKLOCKER__

// library includes
#include <CollectionWrap.h>

// Mac includes
#include <CoreServices/CoreServices.h>



#pragma mark Types

/*!
Generic interface defining a locking mechanism for memory blocks.
Whether static or relocatable, these basic functions can be used
to convert from �stable� reference types to potentially mutable
pointer types, invoking all necessary Memory Manager calls.  This
class is a repository containing lock counts for as many references
of the same type as you wish.  To add a reference, simply try to
lock it for the first time with acquireLock().  To remove a
reference, unlock all locks on it.
*/
template < typename structure_reference_type, typename structure_type >
class MemoryBlockLocker
{
public:
	//! exists only because subclasses are expected
	virtual
	~MemoryBlockLocker		();
	
	//! stabilizes the specified reference�s mutable memory block and returns a pointer to its stable location
	//! (or "null", on error)
	virtual structure_type*
	acquireLock				(structure_reference_type			inReference) = 0;
	
	//! clears all locks; USE WITH CARE
	inline void
	clear					();
	
	//! determines if there are any locks on the specified reference�s memory block
	inline bool
	isLocked				(structure_reference_type			inReference) const;
	
	//! nullifies a pointer to a constant memory block; once all locks are cleared, the block can be relocated or purged, etc.
	virtual void
	releaseLock				(structure_reference_type			inReference,
							 structure_type const**				inoutPtrPtr) = 0;
	
	//! nullifies a pointer to a mutable memory block; once all locks are cleared, the block can be relocated or purged, etc.
	virtual void
	releaseLock				(structure_reference_type			inReference,
							 structure_type**					inoutPtrPtr) = 0;
	
	//! the number of locks acquired without being released (should be 0 if a reference is free)
	UInt16
	returnLockCount			(structure_reference_type			inReference) const;

protected:
	//! decreases the number of locks on a reference, returning the new value
	//! (MUST be used by all releaseLock() implementations)
	UInt16
	decrementLockCount		(structure_reference_type			inReference);
	
	//! increases the number of locks on a reference, returning the new value
	//! (MUST be used by all acquireLock() implementations)
	UInt16
	incrementLockCount		(structure_reference_type			inReference);

private:
	enum
	{
		kMyCollectionTagLockCount = FOUR_CHAR_CODE('Lck#')	//!< where lock counts are found in the private
															//!  Collection variable
	};
	
	//! converts a structure reference into a 32-bit unique ID for a collection item
	inline SInt32
	returnReferenceCollectionID		(structure_reference_type	inReference) const;
	
	CollectionWrap		_collectionObject;	//!< repository for reference lock count information
};


/*!
A useful wrapper that you could declare in a block so that
a lock is automatically acquired upon entry and released
upon block exit.
*/
template < typename structure_reference_type, typename structure_type >
class LockAcquireRelease
{
	typedef MemoryBlockLocker< structure_reference_type, structure_type >	LockerType;

public:
	//! acquires a lock
	LockAcquireRelease		(LockerType&				inLocker,
							 structure_reference_type	inReference);
	
	//! releases a lock
	virtual
	~LockAcquireRelease		();
	
	//! refers directly to the internal pointer
	inline operator structure_type*		();
	
	//! dereferences the internal pointer
	inline structure_type&
	operator *				();
	
	//! dereferences the internal pointer
	inline structure_type const&
	operator *				() const;
	
	//! refers directly to the internal pointer
	inline structure_type*
	operator ->				();
	
	//! refers directly to the internal pointer
	inline structure_type const*
	operator ->				() const;
	
	//! returns the class instance managing locks (use with care)
	inline LockerType&
	locker					();

protected:

private:
	LockerType&					_locker;	//!< repository for reference lock count information
	structure_reference_type	_ref;		//!< reference to data
	structure_type*				_ptr;		//!< once locked, a direct pointer to the referenced data
};



#pragma mark Public Methods

template < typename structure_reference_type, typename structure_type >
MemoryBlockLocker< structure_reference_type, structure_type >::
~MemoryBlockLocker ()
{
}// ~MemoryBlockLocker


template < typename structure_reference_type, typename structure_type >
void
MemoryBlockLocker< structure_reference_type, structure_type >::
clear ()
{
	EmptyCollection(_collectionObject.returnCollection());
}// clear


template < typename structure_reference_type, typename structure_type >
UInt16
MemoryBlockLocker< structure_reference_type, structure_type >::
decrementLockCount	(structure_reference_type	inReference)
{
	UInt16		result = 0;
	UInt16		oldLockCount = returnLockCount(inReference);
	
	
	assert(oldLockCount > 0);
	{
		// decrement existing count
		UInt16 const	newLockCount = oldLockCount - 1;
		OSStatus		error = noErr;
		Collection		collection = _collectionObject.returnCollection(); // for convenience only
		
		
		// if the same tag and ID of an existing item is used, the following �add� call
		// will implicitly *replace* the previous item, effectively updating its value
		error = AddCollectionItem(collection, kMyCollectionTagLockCount, returnReferenceCollectionID(inReference),
									sizeof(newLockCount), &newLockCount);
		
		// delete the lock if the count reaches zero
		if ((error == noErr) && (newLockCount == 0))
		{
			// the only error currently defined for the following is "collectionItemNotFoundErr",
			// which indicates invalid input; there isn�t really anything that can be done about that
			error = RemoveCollectionItem(collection, kMyCollectionTagLockCount, returnReferenceCollectionID(inReference));
		}
		
		// underscore failure by returning an unchanged number of locks
		assert(error == noErr);
		if (error != noErr) result = oldLockCount;
		else result = newLockCount;
	}
	return result;
}// decrementLockCount


template < typename structure_reference_type, typename structure_type >
UInt16
MemoryBlockLocker< structure_reference_type, structure_type >::
incrementLockCount	(structure_reference_type	inReference)
{
	UInt16		result = 0;
	UInt16		oldLockCount = returnLockCount(inReference);
	
	
	{
		// increment existing count
		UInt16 const	newLockCount = oldLockCount + 1;
		OSStatus		error = noErr;
		Collection		collection = _collectionObject.returnCollection(); // for convenience only
		
		
		// if the same tag and ID of an existing item is used, the following �add� call
		// will implicitly *replace* the previous item, effectively updating its value
		error = AddCollectionItem(collection, kMyCollectionTagLockCount, returnReferenceCollectionID(inReference),
									sizeof(newLockCount), &newLockCount);
		
		// underscore failure by returning an unchanged number of locks
		assert(error == noErr);
		if (error != noErr) result = oldLockCount;
		else result = newLockCount;
	}
	return result;
}// incrementLockCount


template < typename structure_reference_type, typename structure_type >
bool
MemoryBlockLocker< structure_reference_type, structure_type >::
isLocked	(structure_reference_type	inReference)
const
{
	// if any lock count is currently stored in the collection for
	// the given reference, then that reference is considered locked
	return (GetCollectionItemInfo(_collectionObject.returnCollection(), kMyCollectionTagLockCount,
									returnReferenceCollectionID(inReference),
									REINTERPRET_CAST(kCollectionDontWantIndex, SInt32*),
									REINTERPRET_CAST(kCollectionDontWantSize, SInt32*),
									REINTERPRET_CAST(kCollectionDontWantAttributes, SInt32*)) == noErr);
}// isLocked


template < typename structure_reference_type, typename structure_type >
UInt16
MemoryBlockLocker< structure_reference_type, structure_type >::
returnLockCount		(structure_reference_type	inReference)
const
{
	UInt16		result = 0;
	OSStatus	error = GetCollectionItem(_collectionObject.returnCollection(), kMyCollectionTagLockCount,
											returnReferenceCollectionID(inReference),
											REINTERPRET_CAST(kCollectionDontWantSize, SInt32*), &result);
	
	
	if (error == collectionItemNotFoundErr)
	{
		// if the item isn�t found, that�s okay...after all,
		// this may be the first time the reference has been
		// used with this locker - technically it has 0 locks
		result = 0;
		error = noErr;
	}
	assert(error == noErr);
	return result;
}// returnLockCount


template < typename structure_reference_type, typename structure_type >
SInt32
MemoryBlockLocker< structure_reference_type, structure_type >::
returnReferenceCollectionID		(structure_reference_type	inReference)
const
{
	return REINTERPRET_CAST(inReference, SInt32);
}// returnReferenceCollectionID


template < typename structure_reference_type, typename structure_type >
LockAcquireRelease< structure_reference_type, structure_type >::
LockAcquireRelease	(LockAcquireRelease< structure_reference_type, structure_type >::LockerType&	inLocker,
					 structure_reference_type														inReference)
:
_locker(inLocker),
_ref(inReference),
_ptr(inLocker.acquireLock(inReference))
{
}// LockAcquireRelease


template < typename structure_reference_type, typename structure_type >
LockAcquireRelease< structure_reference_type, structure_type >::
~LockAcquireRelease ()
{
	_locker.releaseLock(_ref, &_ptr);
}// ~LockAcquireRelease


template < typename structure_reference_type, typename structure_type >
typename LockAcquireRelease< structure_reference_type, structure_type >::LockerType&
LockAcquireRelease< structure_reference_type, structure_type >::
locker ()
{
	return _locker;
}// locker


template < typename structure_reference_type, typename structure_type >
LockAcquireRelease< structure_reference_type, structure_type >::
operator structure_type* ()
{
	return &(this->operator *());
}// operator structure_type*


template < typename structure_reference_type, typename structure_type >
structure_type&
LockAcquireRelease< structure_reference_type, structure_type >::
operator * ()
{
	return *_ptr;
}// operator *


template < typename structure_reference_type, typename structure_type >
structure_type const&
LockAcquireRelease< structure_reference_type, structure_type >::
operator * ()
const
{
	return *_ptr;
}// operator * const


template < typename structure_reference_type, typename structure_type >
structure_type*
LockAcquireRelease< structure_reference_type, structure_type >::
operator -> ()
{
	return &(this->operator *());
}// operator ->


template < typename structure_reference_type, typename structure_type >
structure_type const*
LockAcquireRelease< structure_reference_type, structure_type >::
operator -> ()
const
{
	return &(this->operator *());
}// operator -> const

#endif

// BELOW IS REQUIRED NEWLINE TO END FILE
