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

@property (nonatomic, assign) BOOL isPlayDone;//是否正常的播放完毕

@end

@implementation MLAudioPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.isPlayDone = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(sensorStateChange:)
                                                     name:UIDeviceProximityStateDidChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(sessionRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruption:)
                                                     name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
        
    }
    return self;
}

- (void)dealloc
{
    NSAssert(!self.isPlaying, @"MLAudioPlayer dealloc之前必须停止播放");
    
    //    if (self.isPlaying){
    //        [self stopPlaying];
    //    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    
    DLOG(@"MLAudioPlayer dealloc");
}

#pragma mark - read data callback

void isRunningProc (void * inUserData,AudioQueueRef inAQ,AudioQueuePropertyID inID)
{
	MLAudioPlayer *player = (__bridge MLAudioPlayer*)inUserData;
    
    UInt32 isRunning;
	UInt32 size = sizeof(isRunning);
	OSStatus result = AudioQueueGetProperty (inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
	
	if ((result == noErr) && (!isRunning)&&player.isPlaying){
        [player performSelector:@selector(stopPlaying) withObject:nil afterDelay:0.001f];
    }
}

void outBufferHandler(void *inUserData,AudioQueueRef inAQ,AudioQueueBufferRef inCompleteAQBuffer)
{
    MLAudioPlayer *player = (__bridge MLAudioPlayer*)inUserData;
    
    if (player.isPlayDone) {
        return;
    }
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
        
        if(AudioQueueEnqueueBuffer(inAQ, inCompleteAQBuffer, 0, NULL)!=noErr){
            [player postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutQueue andDescription:@"重准备音频输出缓存区失败"];
        }
    }else{
        player.isPlayDone = YES;
        AudioQueueStop(inAQ, false); //注意这里是停止没错但是传递的false，不会停止当前未完成的播放。
    }
}

#pragma mark - control
- (void)startPlaying
{
    NSAssert(!self.isPlaying, @"播放必须先停止上一个才可开始新的");
    
    NSError *error = nil;
    
    //设置audio session的category
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
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
    
    //简单检测下不支持可变速率
    if (_audioFormat.mFramesPerPacket<=0||_audioFormat.mBytesPerPacket<=0) {
        [self postAErrorWithErrorCode:MLAudioPlayerErrorCodeAboutOther andDescription:@"format 设置有误，此player不支持VBR"];
        return;
    }
    
    //设置音频输出队列
    IfAudioQueueErrorPostAndReturn(AudioQueueNewOutput(&_audioFormat, outBufferHandler, (__bridge void *)(self), CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &_audioQueue),@"音频输出队列初始化失败");
    
    //设置正在运行的回调，这个还真不知道啥时候执行，回头测试下
	IfAudioQueueErrorPostAndReturn(AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning,isRunningProc, (__bridge void *)(self)), @"adding property listener");
    
    //计算估算的缓存区大小，这里我们忽略可变速率的情况
    static const int maxBufferSize = 0x10000;
	static const int minBufferSize = 0x4000;
	
    //每秒采集的帧数/每个packet有的帧数，算出来每秒有多少packet，然后乘以秒数，即为inSeconds时间里需要的packet数目
    //最后乘以参数给予的buffer最大的packet数目。即为估算的保守的buffer大小
    Float64 numPacketsForTime = ceil(_audioFormat.mSampleRate* kDefaultBufferDurationSeconds)/ _audioFormat.mFramesPerPacket ;
    int bufferByteSize = ceil(numPacketsForTime * _audioFormat.mBytesPerPacket);
	bufferByteSize = bufferByteSize>maxBufferSize?maxBufferSize:bufferByteSize;
    bufferByteSize = bufferByteSize<minBufferSize?minBufferSize:bufferByteSize;
    self.bufferByteSize = bufferByteSize;
    DLOG(@"缓冲区大小:%d",bufferByteSize);
    
    //创建缓冲器
    for (int i = 0; i < kNumberAudioQueueBuffers; ++i){
        IfAudioQueueErrorPostAndReturn(AudioQueueAllocateBufferWithPacketDescriptions(_audioQueue, bufferByteSize,0, &_audioBuffers[i]),@"为音频输出队列建立缓冲区失败");
    }
    
    // 开始录音
    IfAudioQueueErrorPostAndReturn(AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, 1.0),@"为音频输出设置音量失败");
    
    self.isPlaying = YES;
    
    self.isPlayDone = NO;
    [self startProximityMonitering];
    
    //输出的buffer必须先填满一次才能准备下一次buffer
    for (int i = 0; i < kNumberAudioQueueBuffers; ++i) {
        outBufferHandler((__bridge void *)(self), _audioQueue, _audioBuffers[i]);
    }
    
    IfAudioQueueErrorPostAndReturn(AudioQueueStart(_audioQueue, NULL),@"音频输出启动失败");
}


- (void)stopPlaying
{
    if (!self.isPlaying) {
        return;
    }
    
    [self stopProximityMonitering];
    self.isPlayDone = YES; //和isPlaying的区别是这个是给里面看的，那个是给外面看的
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
    [self stopProximityMonitering];
    self.isPlayDone = YES;
    self.isPlaying = NO;
    
    AudioQueueStop(_audioQueue, true);
    AudioQueueDispose(_audioQueue, true);
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    
    [self.fileReaderDelegate completeReadWithPlayer:self withIsError:YES];
    DLOG(@"播放发生错误");
    
    NSError *error = [NSError errorWithDomain:kMLAudioPlayerErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
    
    if( self.receiveErrorBlock){
        self.receiveErrorBlock(error);
    }
}

#pragma mark - proximity monitor

- (BOOL)isNotUseBuiltInPort
{
    NSArray *outputs = [[AVAudioSession sharedInstance]currentRoute].outputs;
    if (outputs.count<=0) {
        return NO;
    }
    AVAudioSessionPortDescription *port = (AVAudioSessionPortDescription*)outputs[0];
    
    return ![port.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]&&![port.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker];
}

- (void)startProximityMonitering {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
//    [self sensorStateChange:nil];
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    DLOG(@"开启距离监听");
}

- (void)stopProximityMonitering {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    DLOG(@"关闭距离监听");
}

- (void)sensorStateChange:(NSNotification *)notification {
    if ([self isNotUseBuiltInPort]) {
        //        DLOG(@"有耳机");
        return;//带上耳机不需要这个
    }
    //如果此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出，并将屏幕变暗
    if ([UIDevice currentDevice].isProximityMonitoringEnabled) {
        if ([[UIDevice currentDevice] proximityState] == YES) {
            //        DLOG(@"听筒");
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        }else {
            //        DLOG(@"扬声器");
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        }
    }
}

- (void)sessionRouteChange:(NSNotification *)notification {
    
    if ([notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue] == AVAudioSessionRouteChangeReasonNewDeviceAvailable) {
        //        DLOG(@"新设备插入");
        if ([self isNotUseBuiltInPort]) {
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        }
    }else if ([notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue] == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        //        DLOG(@"新设备拔出");
        if (![self isNotUseBuiltInPort]) {
            [self sensorStateChange:nil];
        }
    }
}

- (void)sessionInterruption:(NSNotification *)notification {
    AVAudioSessionInterruptionType interruptionType = [[[notification userInfo]
                                                        objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType)
    {
        DLOG(@"begin interruption");
        //直接停止播放
        [self stopPlaying];
    }
    else if (AVAudioSessionInterruptionTypeEnded == interruptionType)
    {
        DLOG(@"end interruption");
    }
}

@end
