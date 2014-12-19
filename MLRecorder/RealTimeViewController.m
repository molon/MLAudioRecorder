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

@property (nonatomic, strong) UIButton *simulateSlackButton;

@property (nonatomic, assign) BOOL isInSlack;

//模拟卡顿中没投递播放的数据记录
@property (nonatomic, strong) NSMutableArray *simulateSlackDatas;

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
    
    [self.view addSubview:self.simulateSlackButton];
    self.simulateSlackButton.frame = CGRectMake(self.button.frame.origin.x, CGRectGetMaxY(self.button.frame)+20.0f, 100, 40);
    
    [self.player start];
}

#pragma mark - getter
- (NSMutableArray *)simulateSlackDatas
{
    if (!_simulateSlackDatas) {
        _simulateSlackDatas = [NSMutableArray new];
    }
    return _simulateSlackDatas;
}

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

- (UIButton *)simulateSlackButton
{
    if (!_simulateSlackButton) {
        UIButton *button = [[UIButton alloc]init];
        [button setTitle:@"Slack" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(simulateSlackButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _simulateSlackButton = button;
    }
    return _simulateSlackButton;
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
                if (strongSelf.isInSlack) {
                    [strongSelf.simulateSlackDatas addObject:data];
                }else{
                    [strongSelf.player enqueuePacket:data];
                }
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

- (void)simulateSlackButtonPressed
{
    if (self.isInSlack) {
        //一次性把卡顿记录数据全部投递
        for (NSData *data in self.simulateSlackDatas) {
            [self.player enqueuePacket:data];
        }
        [self.simulateSlackDatas removeAllObjects];
        
        self.isInSlack = NO;
        [self.simulateSlackButton setTitle:@"Slack" forState:UIControlStateNormal];
        DLOG(@"卡顿结束");
    }else{
        DLOG(@"开始卡顿了");
        self.isInSlack = YES;
        [self.simulateSlackButton setTitle:@"Stop Slack" forState:UIControlStateNormal];
    }
}
@end
