//
//  CafRecordInBuffer.h
//  MLRecorder
//
//  Created by molon on 14/12/19.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MLAudioRecorder.h"

//简单的测试，这里代码不太好，有兴趣自己根据实际情况改
@interface CafRecordInBufferWriter : NSObject<FileWriterForMLAudioRecorder>

@property (nonatomic, copy) void(^didReceiveVoiceData)(NSData *data);

@end
