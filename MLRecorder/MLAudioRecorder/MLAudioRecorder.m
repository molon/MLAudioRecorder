//
//  MLAudioRecorder.m
//  MLAudioRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "MLAudioRecorder.h"
#import <AVFoundation/AVFoundation.h>


/**
 *  缓存区的个数，3个一般不用改
 */
#define kNumberAudioQueueBuffers 3

@interface MLAudioRecorder()
{
    //音频输入缓冲区
    AudioQueueBufferRef	_audioBuffers[kNumberAudioQueueBuffers];
}

@property (nonatomic, strong) dispatch_queue_t writeFileQueue;
@property (nonatomic, assign) BOOL isRecording;

@end

@implementation MLAudioRecorder

- (id)init
{
    self = [super init];
    if (self) {
        //建立写入文件线程队列,串行
        self.writeFileQueue = dispatch_queue_create("com.molon.MLAudioRecorder.writeFileQueue", NULL);
        
        //设置录音的format数据
        [self setupAudioFormat:kAudioFormatLinearPCM SampleRate:kSampleRate];
        
    }
    return self;
}

- (void)dealloc
{
	[self stopRecording];
}


// 回调函数
void inputBufferHandler(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime,
                        UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
    MLAudioRecorder *recorder = (__bridge MLAudioRecorder*)inUserData;
    
    if (inNumPackets > 0) {
        NSData *pcmData = [[NSData alloc]initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        if (pcmData) {
            //写入文件
            __weak __typeof(recorder)weakSelf = recorder;
            if(recorder.fileWriterDelegate&&[recorder.fileWriterDelegate respondsToSelector:@selector(writeIntoFileWithData:withRecorder:inAQ:inBuffer:inStartTime:inNumPackets:inPacketDesc:)]){
                //在后台串行队列中去处理文件写入
                dispatch_async(recorder.writeFileQueue, ^{
                    [recorder.fileWriterDelegate writeIntoFileWithData:pcmData withRecorder:weakSelf inAQ:inAQ inBuffer:inBuffer inStartTime:inStartTime inNumPackets:inNumPackets inPacketDesc:inPacketDesc];
                });
            }
        }
    }
    if (recorder.isRecording) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}

- (void)startRecording
{
    NSError *error = nil;
    //设置audio session的category
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (!ret) {
        NSLog(@"%s - set audio session category failed with error %@", __func__,[error description]);
        return;
    }
    
    //启用audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret)
    {
        NSLog(@"%s - activate audio session failed with error %@", __func__,[error description]);
        return;
    }
    
    //建立文件
    if(!self.fileWriterDelegate||![self.fileWriterDelegate respondsToSelector:@selector(createFileWithRecorder:)]||![self.fileWriterDelegate respondsToSelector:@selector(writeIntoFileWithData:withRecorder:inAQ:inBuffer:inStartTime:inNumPackets:inPacketDesc:)]||![self.fileWriterDelegate respondsToSelector:@selector(completeWriteWithRecorder:)]){
        NSLog(@"%s - fileWriterDelegate is not valid", __func__);
        return;
    }
    
    //同步下写入串行队列，防止意外前面有没处理的
    dispatch_sync(self.writeFileQueue, ^{});
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(self.writeFileQueue, ^{
        [self.fileWriterDelegate createFileWithRecorder:weakSelf]; //delegate的操作全部在后台线程中处理
    });
    
#warning 异常处理未做
    //设置录音的回调函数
    AudioQueueNewInput(&_recordFormat, inputBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue);
    
    //计算估算的缓存区大小
    int frames = (int)ceil(kBufferDurationSeconds * _recordFormat.mSampleRate);
    int bufferByteSize = frames * _recordFormat.mBytesPerFrame;
    NSLog(@"缓冲区大小:%d",bufferByteSize);
    
    //创建缓冲器
    for (int i = 0; i < kNumberAudioQueueBuffers; ++i){
        AudioQueueAllocateBuffer(_audioQueue, bufferByteSize, &_audioBuffers[i]);
        AudioQueueEnqueueBuffer(_audioQueue, _audioBuffers[i], 0, NULL);
    }
    
    // 开始录音
    AudioQueueStart(_audioQueue, NULL);
    self.isRecording = YES;
}

- (void)stopRecording
{
//    NSLog(@"stopRecording");
    if (self.isRecording) {
        self.isRecording = NO;
        
        //停止录音队列和移除缓冲区
        AudioQueueStop(_audioQueue, true);
        AudioQueueDispose(_audioQueue, true);
        
        //关闭audio session
        NSError *error = nil;
        BOOL ret = [[AVAudioSession sharedInstance] setActive:NO error:&error];
        if (!ret)
        {
            NSLog(@"%s - inactivate audio session failed with error %@", __func__,[error description]);
            return;
        }
        
        if (self.fileWriterDelegate&&[self.fileWriterDelegate respondsToSelector:@selector(completeWriteWithRecorder:)]) {
            __weak __typeof(self)weakSelf = self;
            dispatch_async(self.writeFileQueue, ^{
                [self.fileWriterDelegate completeWriteWithRecorder:weakSelf];
            });
        }
        
        //简单同步下写入串行队列
        dispatch_sync(self.writeFileQueue, ^{});
        
        NSLog(@"录音结束");
        
        if(self.delegate&&[self.delegate respondsToSelector:@selector(recordStopped)]){
            [self.delegate recordStopped];
        }
        
        if (self.receiveStoppedBlock){
            self.receiveStoppedBlock();
        }
    }
}


// 设置录音格式
- (void)setupAudioFormat:(UInt32) inFormatID SampleRate:(int)sampeleRate
{
    //重置下
    memset(&_recordFormat, 0, sizeof(_recordFormat));
    
    //设置采样率，这里先获取系统默认的测试下 //TODO:
    //采样率的意思是每秒需要采集的帧数
    _recordFormat.mSampleRate = sampeleRate;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数,这里先使用系统的测试下 //TODO:
    _recordFormat.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
//    NSLog(@"sampleRate:%f,通道数:%d",_recordFormat.mSampleRate,_recordFormat.mChannelsPerFrame);
    
    //设置format，怎么称呼不知道。
	_recordFormat.mFormatID = inFormatID;
    
	if (inFormatID == kAudioFormatLinearPCM){
        //这个屌属性不知道干啥的。，
		_recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
		_recordFormat.mBitsPerChannel = 16;
        //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
        //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
        //至于为什么要这样。。。不知道。。。
		_recordFormat.mBytesPerPacket = _recordFormat.mBytesPerFrame = (_recordFormat.mBitsPerChannel / 8) * _recordFormat.mChannelsPerFrame;
		_recordFormat.mFramesPerPacket = 1;
	}
}
@end
