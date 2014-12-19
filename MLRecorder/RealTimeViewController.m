//
//  RealTimeViewController.m
//  MLRecorder
//
//  Created by molon on 14/12/19.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import "RealTimeViewController.h"
#import "MLAudioRecorder.h"
#import "MLAudioBufferPlayer.h"
#import "CafRecordInBufferWriter.h"

@interface RealTimeViewController()

@property (nonatomic, strong) MLAudioRecorder *recorder;
@property (nonatomic, strong) MLAudioBufferPlayer *player;
@property (nonatomic, strong) CafRecordInBufferWriter *recordWriter;

@property (nonatomic, strong) UIButton *button;

@end

@implementation RealTimeViewController

- (void)dealloc
{
    [_recorder stopRecording];
    [_player stop];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"录音实时播放";
    
    [self.view addSubview:self.button];
    self.button.frame = CGRectMake(0, 0, 80, 40);
    self.button.center = self.view.center;
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *filePath = [path stringByAppendingPathComponent:@"record.caf"];
    //打开这个文件
    
    [self.player start];
}

#pragma mark - getter
- (UIButton *)button
{
    if (!_button) {
        UIButton *button = [[UIButton alloc]init];
        [button setTitle:@"Record" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _button = button;
    }
    return _button;
}

- (CafRecordInBufferWriter *)recordWriter
{
    if (!_recordWriter) {
        _recordWriter = [CafRecordInBufferWriter new];
        __weak __typeof(self)weakSelf = self;
        [_recordWriter setDidReceiveVoiceData:^(NSData *data) {
            dispatch_async(dispatch_get_main_queue(), ^{ //注意这个屌地不是主线程，需要投递到主线程去做
                //投递到Player里
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                [strongSelf.player enqueuePacket:data];
            });
        }];
    }
    return _recordWriter;
}

- (MLAudioRecorder *)recorder
{
    if (!_recorder) {
        _recorder = [MLAudioRecorder new];
        _recorder.fileWriterDelegate = self.recordWriter;
    }
    return _recorder;
}

- (MLAudioBufferPlayer *)player
{
    if (!_player) {
        _player = [MLAudioBufferPlayer new];
        [_player setDidReceiveErrorBlock:^(MLAudioBufferPlayer *player, NSError *error) {
            DLOG(@"实时播放错误:%@",error);
        }];
        [_player setDidReceiveStoppedBlock:^(MLAudioBufferPlayer *player) {
            DLOG(@"实时播放停止");
        }];
    }
    return _player;
}

#pragma mark - event
- (void)buttonPressed
{
    if (self.recorder.isRecording) {
        [self.recorder stopRecording];
        [self.button setTitle:@"Record" forState:UIControlStateNormal];
    }else{
        [self.recorder startRecording];
        [self.button setTitle:@"Stop" forState:UIControlStateNormal];
    }
}

@end
