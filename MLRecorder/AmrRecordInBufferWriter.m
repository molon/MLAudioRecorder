//
//  AmrRecordInBufferWriter.m
//  MLRecorder
//
//  Created by molon on 14/12/22.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import "AmrRecordInBufferWriter.h"
//amr编码
#import "interf_enc.h"

@interface AmrRecordInBufferWriter()
{
    void *_enstate;
}

@end

@implementation AmrRecordInBufferWriter


- (BOOL)createFileWithRecorder:(MLAudioRecorder*)recoder
{
    _enstate = 0;
    // amr 压缩句柄
    _enstate = Encoder_Interface_init(0);
    
    if(_enstate==0){
        return NO;
    }
    
    
    return YES;
}

- (BOOL)writeIntoFileWithData:(NSData*)data withRecorder:(MLAudioRecorder*)recoder inAQ:(AudioQueueRef)						inAQ inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc
{
    if (self.didReceiveVoiceData) {
        
        const void *recordingData = data.bytes;
        NSUInteger pcmLen = data.length;
        
        if (pcmLen<=0){
            return YES;
        }
        if (pcmLen%2!=0){
            pcmLen--; //防止意外，如果不是偶数，情愿减去最后一个字节。
            DLOG(@"不是偶数");
        }
        
        NSMutableData *amrData = [NSMutableData data];
        unsigned char buffer[320];
        for (int i =0; i < pcmLen ;i+=160*2) {
            short *pPacket = (short *)((unsigned char*)recordingData+i);
            if (pcmLen-i<160*2){
                continue; //不是一个完整的就拜拜
            }
            
            memset(buffer, 0, sizeof(buffer));
            //encode
            int recvLen = Encoder_Interface_Encode(_enstate,MR515,pPacket,buffer,0);
            if (recvLen>0) {
                [amrData appendBytes:buffer length:recvLen];
            }
        }
        
        self.didReceiveVoiceData(amrData);
        
    }
    return YES;
}

- (BOOL)completeWriteWithRecorder:(MLAudioRecorder*)recoder withIsError:(BOOL)isError
{
    return YES;
}

-(void)dealloc
{
    if (_enstate){
        Encoder_Interface_exit((void*)_enstate);
        _enstate = 0;
    }
}


@end
