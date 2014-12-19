//
//  MLAudioBufferPlayer.m
//  MLRecorder
//
//  Created by molon on 14/12/19.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import "MLAudioBufferPlayer.h"
#import <AVFoundation/AVFoundation.h>

#define kMLAudioBufferPlayerErrorDomain @"MLAudioBufferPlayerErrorDomain"

#define kNumberAudioQueueBuffers 3

#define kDefaultBufferDurationSeconds 0.5

#define IfAudioQueueErrorPostAndReturnValue(operation,error,value) \
do{\
if(operation!=noErr) { \
[self postAErrorWithErrorCode:MLAudioBufferPlayerErrorCodeAboutQueue andDescription:error]; \
return (value); \
}   \
}while(0)

#define IfAudioQueueErrorPostAndReturn(operation,error) \
do{\
if(operation!=noErr) { \
[self postAErrorWithErrorCode:MLAudioBufferPlayerErrorCodeAboutQueue andDescription:error]; \
return; \
}   \
}while(0)

@interface MLAudioBufferPlayer()
{
    //音频输出缓冲区
    AudioQueueBufferRef	_audioBuffers[kNumberAudioQueueBuffers];
    //音频输出缓存区是否处于等待状态
    BOOL _isWaitingOfAudioBuffers[kNumberAudioQueueBuffers];
}

//标识当前是否正在播放中，注意是最准确的标识，根据audioqueue 队列的回调设置的
@property (nonatomic, assign) BOOL isPlaying;

@property (nonatomic, strong) NSMutableArray *audioPackets;

@property (nonatomic, assign) NSUInteger bufferByteSize;

@end

@implementation MLAudioBufferPlayer

static inline AudioStreamBasicDescription kDefaultAudioFormat() {
    static AudioStreamBasicDescription _defaultAudioFormat;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultAudioFormat.mSampleRate = 8000;
        _defaultAudioFormat.mChannelsPerFrame = 1;
        _defaultAudioFormat.mFormatID = kAudioFormatLinearPCM;
        _defaultAudioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        _defaultAudioFormat.mBitsPerChannel = 16;
        _defaultAudioFormat.mBytesPerPacket = _defaultAudioFormat.mBytesPerFrame = (_defaultAudioFormat.mBitsPerChannel / 8) * _defaultAudioFormat.mChannelsPerFrame;
        _defaultAudioFormat.mFramesPerPacket = 1;
    });
    
    return _defaultAudioFormat;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        AudioStreamBasicDescription format = kDefaultAudioFormat();
        [self configureWithAudioFormat:format];
    }
    return self;
}

- (instancetype)initWithAudioFormat:(AudioStreamBasicDescription)audioFormat
{
    self = [super init];
    if (self) {
        [self configureWithAudioFormat:audioFormat];
    }
    return self;
}

- (void)configureWithAudioFormat:(AudioStreamBasicDescription)audioFormat
{
    memcpy(&_audioFormat, &audioFormat, sizeof(_audioFormat));
    
    //简单检测下不支持可变速率
    if (_audioFormat.mFramesPerPacket<=0||_audioFormat.mBytesPerPacket<=0) {
        [self postAErrorWithErrorCode:MLAudioBufferPlayerErrorCodeAboutOther andDescription:@"format 设置有误，此player不支持VBR"];
        return;
    }
    
    //设置音频输出队列
    IfAudioQueueErrorPostAndReturn(AudioQueueNewOutput(&_audioFormat, outBufferHandlerForMLBufferPlayer, (__bridge void *)(self), CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &_audioQueue),@"音频输出队列初始化失败");
    
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
    
    //设置缓冲器
    for (int i = 0; i < kNumberAudioQueueBuffers; ++i){
        IfAudioQueueErrorPostAndReturn(AudioQueueAllocateBufferWithPacketDescriptions(_audioQueue, bufferByteSize,0, &_audioBuffers[i]),@"为音频输出队列建立缓冲区失败");
        //绑定useData
        _audioBuffers[i]->mUserData = &(_isWaitingOfAudioBuffers[i]);
    }
    
    //设置正在运行的回调,这个一般在执行start和stop的时候会执行
    IfAudioQueueErrorPostAndReturn(AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning,isRunningProcForMLBufferPlayer, (__bridge void *)(self)), @"adding property listener");
    
    //设置音量
    self.volume = 1.0f;
    
    
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

#pragma mark - getter
- (NSMutableArray *)audioPackets
{
    if (!_audioPackets) {
        _audioPackets = [NSMutableArray array];
    }
    return _audioPackets;
}

#pragma mark - error
- (void)postAErrorWithErrorCode:(MLAudioBufferPlayerErrorCode)code andDescription:(NSString*)description
{
    NSError *error = [NSError errorWithDomain:kMLAudioBufferPlayerErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
    if (self.didReceiveErrorBlock) {
        self.didReceiveErrorBlock(self,error);
    }
    
    //停止
    [self stop];
}

#pragma mark - callback
- (void)enqueueToPlayPacket:(NSData*)audioPacket withAudioBuffer:(AudioQueueBufferRef)audioBuffer
{
    NSAssert([audioPacket length] <= audioBuffer->mAudioDataBytesCapacity, @"Error: audioPacket太大了");
    
    //把数据塞进去准备播放
    audioBuffer->mAudioDataByteSize = [audioPacket length];
    memcpy(audioBuffer->mAudioData, audioPacket.bytes, audioPacket.length);
    audioBuffer->mPacketDescriptionCount = 0;
    
    IfAudioQueueErrorPostAndReturn(AudioQueueEnqueueBuffer(_audioQueue, audioBuffer, 0, NULL),@"准备音频输出缓存区失败");
}

void isRunningProcForMLBufferPlayer(void * inUserData,AudioQueueRef inAQ,AudioQueuePropertyID inID)
{
    MLAudioBufferPlayer *player = (__bridge MLAudioBufferPlayer*)inUserData;
    
    UInt32 isRunning;
    UInt32 size = sizeof(isRunning);
    OSStatus result = AudioQueueGetProperty (inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
    
    if (result == noErr){
        player.isPlaying = isRunning;
        if (!player.isPlaying) {
            if (player.didReceiveStoppedBlock) {
                player.didReceiveStoppedBlock(player);
            }
        }
    }
}

void outBufferHandlerForMLBufferPlayer(void *inUserData,AudioQueueRef inAQ,AudioQueueBufferRef inCompleteAQBuffer)
{
    MLAudioBufferPlayer *player = (__bridge MLAudioBufferPlayer*)inUserData;

    BOOL *p_isWaitingOfAudioBuffer = (BOOL *)(inCompleteAQBuffer->mUserData);
    
    //这里就设置为在等待塞数据
    *p_isWaitingOfAudioBuffer = YES;
    
    if (player.audioPackets.count>0) {
        NSData *packet = [player.audioPackets objectAtIndex:0];
        //删除丫的
        [player.audioPackets removeObjectAtIndex:0];
        //投递播放请求
        [player enqueueToPlayPacket:packet withAudioBuffer:inCompleteAQBuffer];
        
        DLOG(@"buffer %p 投递了 packet %p",inCompleteAQBuffer,packet);
        
        //塞了完毕，即将播放
        *p_isWaitingOfAudioBuffer = NO;
        
    }
}

#pragma mark - outcall
- (void)setVolume:(AudioQueueParameterValue)volume
{
    _volume = volume;
    
    IfAudioQueueErrorPostAndReturn(AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, volume),@"为音频输出设置音量失败");
}

- (BOOL)isWaiting
{
    //三个缓冲区现在都处于闲置状态才算数
    for (NSInteger i=0; i<kNumberAudioQueueBuffers; i++) {
        if (!_isWaitingOfAudioBuffers[i]) {
            return NO;
        }
    }
    return YES;
}

- (void)enqueuePacket:(NSData *)audioPacket
{
    NSAssert([audioPacket length] <= self.bufferByteSize, @"Error: audioPacket太大了,不能追加");
    
    [self.audioPackets addObject:audioPacket];
    
    if ([self isWaiting]&&self.audioPackets.count>=kNumberAudioQueueBuffers) {
        DLOG(@"等待后继续填充实时数据");
        //塞入三个Buffer
        for (NSInteger i=0; i<kNumberAudioQueueBuffers; i++) {
            [self enqueueToPlayPacket:self.audioPackets[i] withAudioBuffer:_audioBuffers[i]];
            _isWaitingOfAudioBuffers[i] = NO;
        }
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, kNumberAudioQueueBuffers)];
        [self.audioPackets removeObjectsAtIndexes:indexSet];
    }
}

- (void)cleanPackets
{
    self.audioPackets  = nil;
}

//开始播放
- (void)start
{
    //开始session
    NSAssert(!self.isPlaying, @"播放必须先停止上一个才可开始新的");
    
    NSError *error = nil;
    
    //设置audio session的category
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (!ret) {
        [self postAErrorWithErrorCode:MLAudioBufferPlayerErrorCodeAboutSession andDescription:@"为AVAudioSession设置Category失败"];
        return;
    }
    
    //启用audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret)
    {
        [self postAErrorWithErrorCode:MLAudioBufferPlayerErrorCodeAboutSession andDescription:@"Active AVAudioSession失败"];
        return;
    }
    
    //开始近感检测
    [self startProximityMonitering];
    
    for (NSInteger i=0; i<kNumberAudioQueueBuffers; i++) {
        _isWaitingOfAudioBuffers[i] = YES;
    }
    
    IfAudioQueueErrorPostAndReturn(AudioQueueStart(_audioQueue, NULL),@"音频输出启动失败");
    DLOG(@"开始实时播放,等待数据投递");
}

- (void)stop
{
    if (!self.isPlaying) {
        return;
    }
    
    [self cleanPackets];
    
    //关闭近感检测
    [self stopProximityMonitering];
    
    //停止音频输出
    AudioQueueStop(_audioQueue, true);
    //释放音频输出队列缓存
    AudioQueueDispose(_audioQueue, true);
    //关闭session
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
}

#pragma mark - proximity monitor
//是否使用除了内建的声音以外的播放系统
- (BOOL)isUseOutputExceptBuiltInPort
{
    NSArray *outputs = [[AVAudioSession sharedInstance]currentRoute].outputs;
    if (outputs.count<=0) {
        return NO;
    }
    
    for (AVAudioSessionPortDescription *port in outputs) {
        //如果不是两个内建里的一个
        if ([port.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]||[port.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
            continue;
        }
        return YES;
    }
    
    return NO;
}

- (void)startProximityMonitering {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    if ([self isUseOutputExceptBuiltInPort]) {
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    }else{
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    }
    DLOG(@"开启距离监听");
}

- (void)stopProximityMonitering {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    DLOG(@"关闭距离监听");
}

- (void)sensorStateChange:(NSNotification *)notification {
    if ([self isUseOutputExceptBuiltInPort]) {
        //                DLOG(@"有耳机");
        return;//带上耳机直接返回
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
    
    if ([notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue] == AVAudioSessionRouteChangeReasonNewDeviceAvailable) {
        //        DLOG(@"新设备插入");
        if ([self isUseOutputExceptBuiltInPort]) {
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        }
    }else if ([notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue] == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        //        DLOG(@"新设备拔出");
        if (![self isUseOutputExceptBuiltInPort]) {
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
        if (self.isPlaying) {
            [self stop];
        }
    }
    else if (AVAudioSessionInterruptionTypeEnded == interruptionType)
    {
        DLOG(@"end interruption");
        //继续播放
        if (!self.isPlaying) {
//            可以选择清空下中间来的实时数据吧，不管丫了
//            [self cleanPackets];
            [self start];
        }
    }
}

@end
