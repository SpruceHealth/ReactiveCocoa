//
//  RACSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"
#import "EXTScope.h"
#import "RACCompoundDisposable.h"
#import "RACLiveSubscriber.h"

@interface RACSubject ()

// Contains all current subscribers to the receiver.
//
// This should only be used while synchronized on `self`.
@property (nonatomic, strong, readonly) NSMutableArray *subscribers;

// Enumerates over each of the receiver's `subscribers` and invokes `block` for
// each.
- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block;

@end

@implementation RACSubject

#pragma mark Properties

@synthesize disposable = _disposable;

#pragma mark Lifecycle

+ (instancetype)subject {
	return [[self alloc] init];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_disposable = [RACCompoundDisposable compoundDisposable];
	_subscribers = [[NSMutableArray alloc] initWithCapacity:1];
	
	return self;
}

#pragma mark Subscription

- (void)attachSubscriber:(RACLiveSubscriber *)subscriber {
	NSCParameterAssert(subscriber != nil);

	NSMutableArray *subscribers = self.subscribers;
	@synchronized (subscribers) {
		[subscribers addObject:subscriber];
	}
	
	[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
		@synchronized (subscribers) {
			// Since newer subscribers are generally shorter-lived, search
			// starting from the end of the list.
			NSUInteger index = [subscribers indexOfObjectWithOptions:NSEnumerationReverse passingTest:^ BOOL (id<RACSubscriber> obj, NSUInteger index, BOOL *stop) {
				return obj == subscriber;
			}];

			if (index != NSNotFound) [subscribers removeObjectAtIndex:index];
		}
	}]];
}

- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block {
	NSArray *subscribers;
	@synchronized (self.subscribers) {
		subscribers = [self.subscribers copy];
	}

	for (id<RACSubscriber> subscriber in subscribers) {
		block(subscriber);
	}
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self.disposable dispose];
	
	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
	}];
}

- (void)sendCompleted {
	[self.disposable dispose];
	
	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
	}];
}

@end
