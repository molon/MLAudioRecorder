//
//  MLAudioMeterObserver.h
//  MLRecorder
//
//  Created by molon on 5/13/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef void (^MLAudioMeterObserverActionBlock)(Float32 progress);
typedef void (^MLAudioMeterObserverErrorBlock)(NSError *error);

/**
 *  错误标识
 */
typedef NS_OPTIONS(NSUInteger, MLAudioMeterObserverErrorCode) {
    MLAudioMeterObserverErrorCodeAboutQueue, //关于音频输入队列的错误
};


@interface MLAudioMeterObserver : NSObject
{
    AudioQueueRef				_audioQueue;
	AudioQueueLevelMeterState	*_levelMeterStates;
}

@property AudioQueueRef audioQueue;

@property (nonatomic, copy) MLAudioMeterObserverActionBlock actionBlock;

@property (nonatomic, copy) MLAudioMeterObserverErrorBlock errorBlock;


@property (nonatomic, assign) NSTimeInterval refreshInterval; //刷新间隔,默认0.1

@end
