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

@interface ViewController ()

@property (nonatomic, strong) MLAudioRecorder *recorder;
@property (nonatomic, strong) CafRecordWriter *cafWriter;
@property (nonatomic, strong) AmrRecordWriter *amrWriter;
@property (nonatomic, strong) Mp3RecordWriter *mp3Writer;

@property (nonatomic, strong) AVAudioPlayer *player;

@property (nonatomic, copy) NSString *filePath;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@end

@implementation ViewController

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
    
    MLAudioRecorder *recorder = [[MLAudioRecorder alloc]init];
    __weak __typeof(self)weakSelf = self;
    recorder.receiveStoppedBlock = ^{
        [weakSelf.recordButton setTitle:@"Record" forState:UIControlStateNormal];
    };
    recorder.receiveErrorBlock = ^(NSError *error){
        [weakSelf.recordButton setTitle:@"Record" forState:UIControlStateNormal];
        [[[UIAlertView alloc]initWithTitle:@"错误" message:error.userInfo[NSLocalizedDescriptionKey] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"知道了", nil]show];
    };
    
    
    //caf
//    recorder.fileWriterDelegate = writer;
//    self.filePath = writer.filePath;
    
    //amr
    recorder.bufferDurationSeconds = 0.04;
    recorder.fileWriterDelegate = amrWriter;
    self.filePath  = amrWriter.filePath;
    
    //mp3
//    recorder.fileWriterDelegate = mp3Writer;
//    self.filePath = mp3Writer.filePath;
    
    self.recorder = recorder;
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
    }

}

- (IBAction)play:(id)sender {
    //除去amr的都能直接播放
    if (![self.recorder.fileWriterDelegate isKindOfClass:[AmrRecordWriter class]]){
        self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:self.filePath] error:nil];
        [self.player play];
    }
}

@end
