//
//  ViewController.m
//  MLRecorder
//
//  Created by molon on 5/12/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "ViewController.h"
#import "MLAudioRecorder.h"
#import "CafRecordWriter.h"
#import "AmrRecordWriter.h"
#import "Mp3RecordWriter.h"
#import <AVFoundation/AVFoundation.h>
#import "MLAudioMeterObserver.h"

#import "MLAudioPlayer.h"
#import "AmrPlayerReader.h"

@interface ViewController ()

@property (nonatomic, strong) MLAudioRecorder *recorder;
@property (nonatomic, strong) CafRecordWriter *cafWriter;
@property (nonatomic, strong) AmrRecordWriter *amrWriter;
@property (nonatomic, strong) Mp3RecordWriter *mp3Writer;

@property (nonatomic, strong) MLAudioPlayer *player;
@property (nonatomic, strong) AmrPlayerReader *amrReader;

@property (nonatomic, strong) AVAudioPlayer *avAudioPlayer;

@property (nonatomic, copy) NSString *filePath;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (nonatomic, strong) MLAudioMeterObserver *meterObserver;
@end

@implementation ViewController

- (void)dealloc
{
    //音谱检测关联着录音类，录音类要停止了。所以要设置其audioQueue为nil
    self.meterObserver.audioQueue = nil;
	[self.recorder stopRecording];
    
    [self.player stopPlaying];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    CafRecordWriter *writer = [[CafRecordWriter alloc]init];
    writer.filePath = [path stringByAppendingPathComponent:@"record.caf"];
    self.cafWriter = writer;
    
    AmrRecordWriter *amrWriter = [[AmrRecordWriter alloc]init];
    amrWriter.filePath = [path stringByAppendingPathComponent:@"record.amr"];
    amrWriter.maxSecondCount = 60;
    amrWriter.maxFileSize = 1024*256;
    self.amrWriter = amrWriter;
    
    Mp3RecordWriter *mp3Writer = [[Mp3RecordWriter alloc]init];
    mp3Writer.filePath = [path stringByAppendingPathComponent:@"record.mp3"];
    mp3Writer.maxSecondCount = 60;
    mp3Writer.maxFileSize = 1024*256;
    self.mp3Writer = mp3Writer;
    
    MLAudioMeterObserver *meterObserver = [[MLAudioMeterObserver alloc]init];
    meterObserver.actionBlock = ^(NSArray *levelMeterStates,MLAudioMeterObserver *meterObserver){
                DLOG(@"volume:%f",[MLAudioMeterObserver volumeForLevelMeterStates:levelMeterStates]);
    };
    meterObserver.errorBlock = ^(NSError *error,MLAudioMeterObserver *meterObserver){
        [[[UIAlertView alloc]initWithTitle:@"错误" message:error.userInfo[NSLocalizedDescriptionKey] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"知道了", nil]show];
    };
    self.meterObserver = meterObserver;
    
    MLAudioRecorder *recorder = [[MLAudioRecorder alloc]init];
    __weak __typeof(self)weakSelf = self;
    recorder.receiveStoppedBlock = ^{
        [weakSelf.recordButton setTitle:@"Record" forState:UIControlStateNormal];
        weakSelf.meterObserver.audioQueue = nil;
    };
    recorder.receiveErrorBlock = ^(NSError *error){
        [weakSelf.recordButton setTitle:@"Record" forState:UIControlStateNormal];
        weakSelf.meterObserver.audioQueue = nil;
        
        [[[UIAlertView alloc]initWithTitle:@"错误" message:error.userInfo[NSLocalizedDescriptionKey] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"知道了", nil]show];
    };
    
    
    //caf
//        recorder.fileWriterDelegate = writer;
//        self.filePath = writer.filePath;
    //mp3
    //    recorder.fileWriterDelegate = mp3Writer;
    //    self.filePath = mp3Writer.filePath;
    
    //amr
    recorder.bufferDurationSeconds = 0.25;
    recorder.fileWriterDelegate = self.amrWriter;
    
    self.recorder = recorder;
    
    
    
    
    MLAudioPlayer *player = [[MLAudioPlayer alloc]init];
    AmrPlayerReader *amrReader = [[AmrPlayerReader alloc]init];
    
    player.fileReaderDelegate = amrReader;
    player.receiveErrorBlock = ^(NSError *error){
        [weakSelf.playButton setTitle:@"Play" forState:UIControlStateNormal];
        
        [[[UIAlertView alloc]initWithTitle:@"错误" message:error.userInfo[NSLocalizedDescriptionKey] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"知道了", nil]show];
    };
    player.receiveStoppedBlock = ^{
        [weakSelf.playButton setTitle:@"Play" forState:UIControlStateNormal];
    };
    self.player = player;
    self.amrReader = amrReader;
    
    
    
    
    
    //button event test
        [self.recordButton addTarget:self action:@selector(dragEnter) forControlEvents:UIControlEventTouchDragEnter];
        [self.recordButton addTarget:self action:@selector(dragExit) forControlEvents:UIControlEventTouchDragExit];
        [self.recordButton addTarget:self action:@selector(upOutSide) forControlEvents:UIControlEventTouchUpOutside];
        [self.recordButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchCancel];
     [self.recordButton addTarget:self action:@selector(down) forControlEvents:UIControlEventTouchDown];
    [self.recordButton addTarget:self action:@selector(upInside) forControlEvents:UIControlEventTouchUpInside];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionDidChangeInterruptionType:)
                                                 name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    
    
}

- (void)audioSessionDidChangeInterruptionType:(NSNotification *)notification
{
    AVAudioSessionInterruptionType interruptionType = [[[notification userInfo]
                                                        objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType)
    {
        DLOG(@"begin");
    }
    else if (AVAudioSessionInterruptionTypeEnded == interruptionType)
    {
        DLOG(@"end");
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)record:(id)sender {
    
    UIButton *recordButton = (UIButton*)sender;
    
    if (self.recorder.isRecording) {
        //取消录音
        [self.recorder stopRecording];
    }else{
        [recordButton setTitle:@"Stop" forState:UIControlStateNormal];
        //开始录音
        [self.recorder startRecording];
        self.meterObserver.audioQueue = self.recorder->_audioQueue;
    }
}

- (IBAction)play:(id)sender {
//    UIButton *playButton = (UIButton*)sender;
//    if (self.avAudioPlayer.isPlaying) {
//        [self.avAudioPlayer stop];
//         [playButton setTitle:@"Play" forState:UIControlStateNormal];
//    }else{
//        self.avAudioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:self.filePath] error:nil];
//        [self.avAudioPlayer play];
//        [playButton setTitle:@"Stop" forState:UIControlStateNormal];
//    }
    
    
    self.amrReader.filePath = self.amrWriter.filePath;
    
    DLOG(@"文件时长%f",[AmrPlayerReader durationOfAmrFilePath:self.amrReader.filePath]);
    
    UIButton *playButton = (UIButton*)sender;
    
    if (self.player.isPlaying) {
        [self.player stopPlaying];
    }else{
        [playButton setTitle:@"Stop" forState:UIControlStateNormal];
        [self.player startPlaying];
    }
    
}

- (void)dragEnter
{
    DLOG(@"T普通提示录音状态");
}
- (void)dragExit
{
    DLOG(@"T提示松开可取消");
}
- (void)upOutSide
{
    DLOG(@"T取消录音");
}
- (void)cancel
{
    DLOG(@"T取消录音");
}

- (void)down
{
    DLOG(@"T开始录音");
    [self dragEnter];
}

- (void)upInside
{
    DLOG(@"T结束录音");
}
@end
