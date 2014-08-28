//
//  NSURL+String.m
//  MLRecorder
//
//  Created by molon on 8/28/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "NSURL+String.h"

@implementation NSURL (String)

- (NSString*)string
{
    if ([self isFileURL]) {
        return [self path];
    }
    
    return [self absoluteString];
}

@end
