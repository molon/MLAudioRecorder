//
//  AmrRecordWriter.h
//  MLAudioRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//
/**
 *  采样率必须为8000，然后缓冲区秒数必须为0.02的倍数。
 *
 */
#import <Foundation/Foundation.h>

#import "MLAudioRecorder.h"

@interface AmrRecordWriter : NSObject<FileWriterForMLAudioRecorder>

@property (nonatomic, copy) NSString *filePath;
/**
 * 暂时没有需求需要做实时语音，队列输出暂时不写了。这里弄个caf的备份吧，免得还需要转码才能使用AVAudioPlayer播放
 */
@property (nonatomic, copy) NSString *cafFilePath;

@property (nonatomic, assign) unsigned long maxFileSize;
@property (nonatomic, assign) double maxSecondCount;

@end
