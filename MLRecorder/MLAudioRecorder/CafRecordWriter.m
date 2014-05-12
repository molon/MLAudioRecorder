//
//  CafRecordWriter.m
//  MLAudioRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "CafRecordWriter.h"

@interface CafRecordWriter()
{
    AudioFileID mRecordFile;
    SInt64 recordPacketCount;
}

@end

@implementation CafRecordWriter


- (void)createFileWithRecorder:(MLAudioRecorder*)recoder
{
    //PS:注意以下都没有做错误处理
    
    //建立文件
    recordPacketCount = 0;
    
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)self.filePath, NULL);
    AudioFileCreateWithURL(url, kAudioFileCAFType, (const AudioStreamBasicDescription	*)(&(recoder->_recordFormat)), kAudioFileFlags_EraseFile, &mRecordFile);
    CFRelease(url);
}

- (void)writeIntoFileWithData:(NSData*)data withRecorder:(MLAudioRecorder*)recoder inAQ:(AudioQueueRef)						inAQ inBuffer:(AudioQueueBufferRef)inBuffer inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc
{
    AudioFileWritePackets(mRecordFile, FALSE, inBuffer->mAudioDataByteSize,
                          inPacketDesc, recordPacketCount, &inNumPackets, inBuffer->mAudioData);
    recordPacketCount += inNumPackets;
}

- (void)completeWriteWithRecorder:(MLAudioRecorder*)recoder
{
    AudioFileClose(mRecordFile);
    
//    NSData *data = [[NSData alloc]initWithContentsOfFile:self.filePath];
//    NSLog(@"文件长度%ld",data.length);
}

-(void)dealloc
{
    AudioFileClose(mRecordFile);
}
@end
