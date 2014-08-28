//
//  MLDataResponseSerializer.h
//  CustomerPo
//
//  Created by molon on 8/15/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "AFURLResponseSerialization.h"

@interface MLDataResponseSerializer : AFHTTPResponseSerializer<NSCopying>

+ (instancetype)shareInstance;
+ (NSOperationQueue *)sharedDataRequestOperationQueue;

@end
