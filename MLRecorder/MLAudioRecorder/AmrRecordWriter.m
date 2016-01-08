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
    void *_destate;
}

@property (nonatomic, assign) unsigned long recordedFileSize;
@property (nonatomic, assign) double recordedSecondCount;

@property (nonatomic, assign) unsigned long lastBytesLength;
@property (nonatomic, assign) unsigned char * lastBytes;

@end

@implementation AmrRecordWriter

- (BOOL)createFileWithRecorder:(MLAudioRecorder*)recoder;
{
    _destate = 0;
    // amr 压缩句柄
    _destate = Encoder_Interface_init(0);
    
    if(_destate==0){
        return NO;
    }
    
    //建立amr文件
    _file = fopen((const char *)[self.filePath UTF8String], "wb+");
    if (_file==0) {
        NSLog(@"建立文件失败:%s",__FUNCTION__);
        return NO;
    }
    
    self.recordedFileSize = 0;
    self.recordedSecondCount = 0;
    
    if(!self.lastBytes)
        self.lastBytes = malloc(320);
    
    self.lastBytesLength = 0;
    
    //写入文件头
    static const char* amrHeader = "#!AMR\n";
    if(fwrite(amrHeader, 1, strlen(amrHeader), _file)==0){
        return NO;
    }
    
    self.recordedFileSize += strlen(amrHeader);
    
    return YES;
}

- (BOOL)writeIntoFileWithData:(NSData*)data withRecorder:(MLAudioRecorder*)recoder inAQ:(AudioQueueRef)						inAQ inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc
{
    if (self.maxSecondCount>0){
        if (self.recordedSecondCount+recoder.bufferDurationSeconds>self.maxSecondCount){
            //            NSLog(@"录音超时");
            dispatch_async(dispatch_get_main_queue(), ^{
                [recoder stopRecording];
            });
            return YES;
        }
        self.recordedSecondCount += recoder.bufferDurationSeconds;
    }
    
    //编码
    const void *recordingData = data.bytes;
    NSUInteger pcmLen = data.length;
    
//    NSLog(@"%lu",(unsigned long)pcmLen);
    
    if (pcmLen<=0){
        return YES;
    }
    if (pcmLen%2!=0){
        pcmLen--; //防止意外，如果不是偶数，情愿减去最后一个字节。
//        NSLog(@"不是偶数");
    }

    unsigned char * bytes = malloc(pcmLen+320);
    memset(bytes,0,pcmLen+320);
    memcpy(bytes,self.lastBytes,self.lastBytesLength);
    memcpy(bytes+self.lastBytesLength, recordingData, pcmLen);
    pcmLen += self.lastBytesLength;
    self.lastBytesLength=0;
    unsigned char buffer[320];
    for (int i =0; i < pcmLen ;i+=160*2) {
        short *pPacket = (short *)((unsigned char*)bytes+i);
        if (pcmLen-i<160*2){
            
            self.lastBytesLength = pcmLen - i;
            memcpy(self.lastBytes, pPacket, self.lastBytesLength);
            continue; //不是一个完整的就拜拜，等待下次数据传递进来再处理
        }
        
        memset(buffer, 0, sizeof(buffer));
        //encode
        int recvLen = Encoder_Interface_Encode(_destate,MR515,pPacket,buffer,0);
        if (recvLen>0) {
            if (self.maxFileSize>0){
                if(self.recordedFileSize+recvLen>self.maxFileSize){
                    //                    NSLog(@"录音文件过大");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [recoder stopRecording];
                    });
                    
                    free(bytes);
                    return YES;//超过了最大文件大小就直接返回
                }
            }
            
            if(fwrite(buffer,1,recvLen,_file)==0){
                 free(bytes);
                return NO;//只有写文件有可能出错。返回NO
            }
            self.recordedFileSize += recvLen;
        }
    }
    
    free(bytes);
    return YES;
}

- (BOOL)completeWriteWithRecorder:(MLAudioRecorder*)recoder withIsError:(BOOL)isError
{
    //关闭就关闭吧。管他关闭成功与否
    if(_file){
        fclose(_file);
        _file = 0;
    }
    if (_destate){
        Encoder_Interface_exit((void*)_destate);
        _destate = 0;
    }
    
    if(_lastBytes)
    {
        free(_lastBytes);
        _lastBytes = nil;
    }
    _lastBytesLength = 0;
    
    return YES;
}

- (void)dealloc
{
	if(_file){
        fclose(_file);
        _file = 0;
    }
    if (_destate){
        Encoder_Interface_exit((void*)_destate);
        _destate = 0;
    }
    
    if(_lastBytes)
    {
        free(_lastBytes);
        _lastBytes = nil;
    }
    _lastBytesLength = 0;
}


@end
