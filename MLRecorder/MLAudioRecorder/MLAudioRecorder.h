//
//  MLAudioRecorder.h
//  MLAudioRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

/**
 *  使用audioqueque来实时录音，边录音边转码，可以设置自己的转码方式。从PCM数据转
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/**
 *  每次的音频输入队列缓存区所保存的是多少秒的数据
 */
#define kBufferDurationSeconds 0.04
/**
 *  采样率，要转码为amr的话必须为8000
 */
#define kSampleRate 8000


//录音停止事件的block回调，作用参考MLAudioRecorderDelegate的recordStopped
typedef void (^MLAudioRecorderReceiveStoppedBlock)();

@class MLAudioRecorder;

/**
 *  处理写文件操作的，实际是转码的操作在其中进行。算作可扩展自定义的转码器
 *  当然如果是实时语音的需求的话，就可以在此处理编码后发送语音数据到对方
 *  PS:这里的三个方法是在后台线程中处理的
 */
@protocol FileWriterForMLAudioRecorder <NSObject>

@required
/**
 *  在录音开始时候建立文件和写入文件头信息等操作
 *
 */
- (void)createFileWithRecorder:(MLAudioRecorder*)recoder;

/**
 *  写入音频输入数据，内部处理转码等其他逻辑
 *  能传递过来的都传递了。以方便多能扩展使用
 */
- (void)writeIntoFileWithData:(NSData*)data withRecorder:(MLAudioRecorder*)recoder inAQ:(AudioQueueRef)						inAQ inBuffer:(AudioQueueBufferRef)inBuffer inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets inPacketDesc:(const AudioStreamPacketDescription*)inPacketDesc;

/**
 *  文件写入完成之后的操作，例如文件句柄关闭等
 *
 */
- (void)completeWriteWithRecorder:(MLAudioRecorder*)recoder;

@end

@protocol MLAudioRecorderDelegate <NSObject>

/**
 *  录音被停止
 *  一般是在writer delegate中因为一些状况意外停止录音获得此事件时候使用，参考AmrRecordWriter里实现。
 */
@optional
- (void)recordStopped;

@end

@interface MLAudioRecorder : NSObject
{
    @public
    //音频输入队列
    AudioQueueRef				_audioQueue;
    //音频输入数据format
    AudioStreamBasicDescription	_recordFormat;
}

/**
 *  是否正在录音
 */
@property (nonatomic, assign,readonly) BOOL isRecording;

/**
 *  处理写文件操作的，实际是转码的操作在其中进行。算作可扩展自定义的转码器
 */
@property (nonatomic, weak) id<FileWriterForMLAudioRecorder> fileWriterDelegate;

/**
 *  参考MLAudioRecorderReceiveStoppedBlock
 */
@property (nonatomic, copy) MLAudioRecorderReceiveStoppedBlock receiveStoppedBlock;

/**
 *  参考MLAudioRecorderDelegate
 */
@property (nonatomic, assign) id<MLAudioRecorderDelegate> delegate;

- (void)startRecording;
- (void)stopRecording;


@end
