//
//  MLAudioPlayer.m
//  MLRecorder
//
//  Created by molon on 5/22/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "MLAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>

#define kMLAudioPlayerErrorDomain @"MLAudioPlayerErrorDomain"

#define kDefaultBufferDurationSeconds 0.5

#define kNumberAudioQueueBuffers 3


#define IfAudioQueueErrorPostAndReturn(operation,error) \
do{\
if(operation!=noErr) { \
[self postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutQueue andDescription:error]; \
return; \
}   \
}while(0)


@interface MLAudioPlayer()
{
    //音频输出缓冲区
    AudioQueueBufferRef	_audioBuffers[kNumberAudioQueueBuffers];
}

@property (nonatomic, assign) NSUInteger bufferByteSize;

@end

@implementation MLAudioPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

#pragma mark - read data callback

void outBufferHandler(void *inUserData,AudioQueueRef inAQ,AudioQueueBufferRef inCompleteAQBuffer)
{
    MLAudioPlayer *player = (__bridge MLAudioPlayer*)inUserData;
    
    //获取数据放进去
    NSData *data = nil;
    if (player.fileReaderDelegate) {
        NSError *error = nil;
        data = [player.fileReaderDelegate readDataFromFileWithPlayer:player andBufferSize:player.bufferByteSize error:&error];
        if (error) {
            [player postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutFile andDescription:@"读取数据失败"];
            return;
        }
    }
    if (data.length>0) {
        memcpy(inCompleteAQBuffer->mAudioData, data.bytes, data.length);
        inCompleteAQBuffer->mAudioDataByteSize = data.length;
		inCompleteAQBuffer->mPacketDescriptionCount = 0;
    }else{
        NSLog(@"无数据播放了");
        return;
    }
    
    if (player.isPlaying) {
        if(AudioQueueEnqueueBuffer(inAQ, inCompleteAQBuffer, 0, NULL)!=noErr){
            [player postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutQueue andDescription:@"重准备音频输出缓存区失败"];
        }
    }
}

#pragma setUp
- (void)setUpNewPlay
{
    NSError *error = nil;
    
    //设置audio session的category
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!ret) {
        [self postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutSession andDescription:@"为AVAudioSession设置Category失败"];
        return;
    }
    
    //启用audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret)
    {
        [self postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutSession andDescription:@"Active AVAudioSession失败"];
        return;
    }
    
    //需要检测delegate没实现方法就不行。
    if (!self.fileReaderDelegate||
        ![self.fileReaderDelegate respondsToSelector:@selector(customAudioFormatAfterOpenFile)]||
        ![self.fileReaderDelegate respondsToSelector:@selector(openFileWithPlayer:)]||
        ![self.fileReaderDelegate respondsToSelector:@selector(readDataFromFileWithPlayer:andBufferSize:error:)]||
        ![self.fileReaderDelegate respondsToSelector:@selector(completeReadWithPlayer:withIsError:)]) {
        [self postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutOther andDescription:@"fileWriterDelegate的代理未设置或其代理方法不完整"];
        return;
    }
    
    //打开文件
    if (self.fileReaderDelegate&&![self.fileReaderDelegate openFileWithPlayer:self]) {
        [self postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutFile andDescription:@"为音频输出打开文件失败"];
        return;
    }
    
    
    //得到format
    AudioStreamBasicDescription format = [self.fileReaderDelegate customAudioFormatAfterOpenFile];
    memcpy(&_audioFormat, &format, sizeof(_audioFormat));
    
    
#warning - 这里应该检查下format是否有效，无效就抛出错误，检查是否有mFramesPerPacket和mBytesPerPacket是否为0，为0也不行，不支持可变速率
    
    //设置音频输出队列
    IfAudioQueueErrorPostAndReturn(AudioQueueNewOutput(&_audioFormat, outBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue),@"音频输出队列初始化失败");
    
    //计算估算的缓存区大小，这里我们忽略可变速率的情况
    static const int maxBufferSize = 0x10000; // limit size to 64K
	static const int minBufferSize = 0x4000; // limit size to 16K
	
    //每秒采集的帧数/每个packet有的帧数，算出来每秒有多少packet，然后乘以秒数，即为inSeconds时间里需要的packet数目
    //最后乘以参数给予的buffer最大的packet数目。即为估算的保守的buffer大小
    Float64 numPacketsForTime = ceil(_audioFormat.mSampleRate* kDefaultBufferDurationSeconds)/ _audioFormat.mFramesPerPacket ;
    int bufferByteSize = ceil(numPacketsForTime * _audioFormat.mBytesPerPacket);
	bufferByteSize = bufferByteSize>maxBufferSize?maxBufferSize:bufferByteSize;
    bufferByteSize = bufferByteSize<minBufferSize?minBufferSize:bufferByteSize;
//    bufferByteSize = 8000;
    self.bufferByteSize = bufferByteSize;
    NSLog(@"缓冲区大小:%d",bufferByteSize);
    
    //创建缓冲器
    for (int i = 0; i < kNumberAudioQueueBuffers; ++i){
        IfAudioQueueErrorPostAndReturn(AudioQueueAllocateBufferWithPacketDescriptions(_audioQueue, bufferByteSize,0, &_audioBuffers[i]),@"为音频输出队列建立缓冲区失败");
    }
    
    // 开始录音
    IfAudioQueueErrorPostAndReturn(AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, 1.0),@"为音频输出设置音量失败");
    
    self.isPlaying = YES;
}

#pragma mark - control
- (void)startPlaying
{
    if (!self.isPlaying) {
        [self setUpNewPlay];
        
        for (int i = 0; i < kNumberAudioQueueBuffers; ++i) {
            outBufferHandler((__bridge void *)(self), _audioQueue, _audioBuffers[i]);
        }
    }
    
    IfAudioQueueErrorPostAndReturn(AudioQueueStart(_audioQueue, NULL),@"音频输出启动失败");
}


- (void)stopPlaying
{
    if (!self.isPlaying) {
        return;
    }
    
    self.isPlaying = NO;
    
    AudioQueueStop(_audioQueue, true);
    AudioQueueDispose(_audioQueue, true);
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    
    if (self.fileReaderDelegate&&![self.fileReaderDelegate completeReadWithPlayer:self withIsError:NO]) {
        [self postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutFile andDescription:@"为音频输出关闭文件失败"];
        return;
    }
    
    if(self.receiveStoppedBlock){
        self.receiveStoppedBlock();
    }
}

#pragma mark - error

- (void)postAErrorWithErrorCode:(MLAudioPlayerErrorCode)code andDescription:(NSString*)description
{
    self.isPlaying = NO;
    
    NSLog(@"播放发生错误");
    
    NSError *error = [NSError errorWithDomain:kMLAudioPlayerErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
    
    if( self.receiveErrorBlock){
        self.receiveErrorBlock(error);
    }
}


@end
