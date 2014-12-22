//
//  AmrRecordInBufferWriter.h
//  MLRecorder
//
//  Created by molon on 14/12/22.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MLAudioRecorder.h"
@interface AmrRecordInBufferWriter : NSObject<FileWriterForMLAudioRecorder>

@property (nonatomic, copy) void(^didReceiveVoiceData)(NSData *data);

@end
