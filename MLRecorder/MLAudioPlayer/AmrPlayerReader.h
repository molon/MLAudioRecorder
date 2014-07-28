//
//  AmrPlayerReader.h
//  MLRecorder
//
//  Created by molon on 5/23/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MLAudioPlayer.h"

@interface AmrPlayerReader : NSObject<FileReaderForMLAudioPlayer>

@property (nonatomic, copy) NSString *filePath;

+ (double)durationOfAmrFilePath:(NSString*)filePath;
- (double)duration;

@end
