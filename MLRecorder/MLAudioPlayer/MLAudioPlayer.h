//
//  MLAudioPlayer.h
//  MLRecorder
//
//  Created by molon on 5/22/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class MLAudioPlayer;

typedef void (^MLAudioPlayerReceiveStoppedBlock)();
typedef void (^MLAudioPlayerReceiveErrorBlock)(NSError *error);

/**
 *  错误标识
 */
typedef NS_OPTIONS(NSUInteger, MLAudioPlayerErrorCode) {
    MLAudioPlayerErrorCodeAboutFile = 0, //关于文件操作的错误
    MLAudioPlayerErrorCodeAboutQueue, //关于音频输入队列的错误
    MLAudioPlayerErrorCodeAboutSession, //关于audio session的错误
    MLAudioPlayerErrorCodeAboutOther, //关于其他的错误
};

@protocol FileReaderForMLAudioPlayer <NSObject>

@required
- (BOOL)openFileWithPlayer:(MLAudioPlayer*)player;
- (AudioStreamBasicDescription)customAudioFormatAfterOpenFile;
- (NSData*)readDataFromFileWithPlayer:(MLAudioPlayer*)player andBufferSize:(NSUInteger)bufferSize error:(NSError**)error;
- (BOOL)completeReadWithPlayer:(MLAudioPlayer*)player withIsError:(BOOL)isError;

@end


@interface MLAudioPlayer : NSObject
{
@public
    //音频输入队列
    AudioQueueRef				_audioQueue;
    //音频输入数据format
    AudioStreamBasicDescription	_audioFormat;
}


@property (nonatomic, assign) BOOL isPlaying;

@property (nonatomic, weak) id<FileReaderForMLAudioPlayer> fileReaderDelegate;

@property (nonatomic, copy) MLAudioPlayerReceiveErrorBlock receiveErrorBlock;
@property (nonatomic, copy) MLAudioPlayerReceiveStoppedBlock receiveStoppedBlock;

- (void)startPlaying;
- (void)stopPlaying;

@end
