//
//  AmrRecordWriter.m
//  MLAudioRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "AmrRecordWriter.h"

//amr编码
#import "interf_enc.h"

@interface AmrRecordWriter()
{
    FILE *_file;
    void *destate;
}

@property (nonatomic, assign) unsigned long fileSize;
@property (nonatomic, assign) double recordedSecondCount;

@end

@implementation AmrRecordWriter

- (void)createFileWithRecorder:(MLAudioRecorder*)recoder;
{
    // amr 压缩句柄
    destate = Encoder_Interface_init(0);
    
    //建立amr文件
    _file = fopen((const char *)[self.filePath UTF8String], "wb+");
    if (_file==0) {
        NSLog(@"建立文件失败:%s",__FUNCTION__);
        return;
    }
    
    self.fileSize = 0;
    self.recordedSecondCount = 0;
    
    //写入文件头
    static const char* amrHeader = "#!AMR\n";
    fwrite(amrHeader, 1, strlen(amrHeader), _file);

    self.fileSize += strlen(amrHeader);
    
    NSLog(@"filePath:%@",self.filePath);
    
}

- (void)writeIntoFileWithData:(NSData*)data withRecorder:(MLAudioRecorder*)recoder inAQ:(AudioQueueRef)						inAQ inBuffer:(AudioQueueBufferRef)inBuffer inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc
{
    
    if (self.maxSecondCount>0){
        if (self.recordedSecondCount+kBufferDurationSeconds>self.maxSecondCount){
//            NSLog(@"录音超时");
            dispatch_async(dispatch_get_main_queue(), ^{
                [recoder stopRecording];
            });
            return;
        }
        self.recordedSecondCount += kBufferDurationSeconds;
    }
    
    //编码
    const void *recordingData = data.bytes;
    NSUInteger pcmLen = data.length;
    
    if (pcmLen<=0){
        return;
    }
    if (pcmLen%2!=0){
        pcmLen--; //防止意外，如果不是偶数，情愿减去最后一个字节。
        NSLog(@"不是偶数");
    }
    
    unsigned char buffer[320];
    for (int i =0; i < pcmLen ;i+=160*2) {
        short *pPacket = (short *)((unsigned char*)recordingData+i);
        if (pcmLen-i<160*2){
            break; //不是一个完整的帧就拜拜
        }
        
        memset(buffer, 0, sizeof(buffer));
        //encode
        int recvLen = Encoder_Interface_Encode(destate,MR122,pPacket,buffer,0);
        if (recvLen>0) {
            if (self.maxFileSize>0){
                if(self.fileSize+recvLen>self.maxFileSize){
//                    NSLog(@"录音文件过大");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [recoder stopRecording];
                    });
                    return;//超过了最大文件大小就直接返回
                }
            }
            
            fwrite(buffer,1,recvLen,_file);
            self.fileSize += recvLen;
        }
    }
}

- (void)completeWriteWithRecorder:(MLAudioRecorder*)recoder
{
    fclose(_file);
    _file = 0;
    
    Encoder_Interface_exit((void*)destate);
    destate = 0;
    
}

- (void)dealloc
{
	if(_file){
        fclose(_file);
        _file = 0;
    }
}


@end
