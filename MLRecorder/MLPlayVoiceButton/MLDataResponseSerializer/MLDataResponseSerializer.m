//
//  MLDataResponseSerializer.m
//  CustomerPo
//
//  Created by molon on 8/15/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "MLDataResponseSerializer.h"

@implementation MLDataResponseSerializer

+ (NSOperationQueue *)sharedDataRequestOperationQueue {
    static NSOperationQueue *_sharedDataRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedDataRequestOperationQueue = [[NSOperationQueue alloc] init];
        _sharedDataRequestOperationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    });
    
    return _sharedDataRequestOperationQueue;
}


+ (instancetype)shareInstance {
    static MLDataResponseSerializer *_shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareInstance = [MLDataResponseSerializer serializer];
    });
    return _shareInstance;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.acceptableContentTypes = [[NSSet alloc] initWithObjects:@"*/*", nil];
    
    return self;
}

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    
    return data;
}

- (id)copyWithZone:(NSZone *)zone {
    MLDataResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    return serializer;
}


@end
