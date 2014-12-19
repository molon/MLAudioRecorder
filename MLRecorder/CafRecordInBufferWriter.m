//
//  CafRecordInBuffer.m
//  MLRecorder
//
//  Created by molon on 14/12/19.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import "CafRecordInBufferWriter.h"

@interface CafRecordInBufferWriter()

@end

@implementation CafRecordInBufferWriter


- (BOOL)createFileWithRecorder:(MLAudioRecorder*)recoder
{
    return YES;
}

- (BOOL)writeIntoFileWithData:(NSData*)data withRecorder:(MLAudioRecorder*)recoder inAQ:(AudioQueueRef)						inAQ inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc
{
    if (self.didReceiveVoiceData) {
        self.didReceiveVoiceData(data);
    }
    return YES;
}

- (BOOL)completeWriteWithRecorder:(MLAudioRecorder*)recoder withIsError:(BOOL)isError
{
    return YES;
}

-(void)dealloc
{
}


@end
