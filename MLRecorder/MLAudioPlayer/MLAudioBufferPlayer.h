//
//  MLAudioBufferPlayer.h
//  MLRecorder
//
//  Created by molon on 14/12/19.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/**
 *  错误标识
 */
typedef NS_OPTIONS(NSUInteger, MLAudioBufferPlayerErrorCode) {
    MLAudioBufferPlayerErrorCodeAboutQueue = 0, //关于音频输入队列的错误
    MLAudioBufferPlayerErrorCodeAboutSession, //关于audio session的错误
    MLAudioBufferPlayerErrorCodeAboutOther, //关于其他的错误
};

@interface MLAudioBufferPlayer : NSObject
{
@public
    //音频输入队列
    AudioQueueRef				_audioQueue;
    //音频输入数据format
    AudioStreamBasicDescription	_audioFormat;
}
//可以设置音量默认是1.0
@property (nonatomic, assign) AudioQueueParameterValue volume;

//注意得到错误之后，didReceiveStoppedBlock也会得到。其他类并非如此，但现在感觉这样才合理
@property (nonatomic, copy) void(^didReceiveErrorBlock)(MLAudioBufferPlayer *player,NSError *error);

@property (nonatomic, copy) void(^didReceiveStoppedBlock)(MLAudioBufferPlayer *player);

//追加PCM数据等待播放
- (void)enqueuePacket:(NSData *)audioPacket;

//清空未播放的数据，可以清除并且立即enqueue新的，即可忽略中间的未读段，一般不需要调用
- (void)cleanPackets;

//开始播放
- (void)start;

//这个方法会清空当前未播放的Buffer，并且停止播放。
- (void)stop;


@end
