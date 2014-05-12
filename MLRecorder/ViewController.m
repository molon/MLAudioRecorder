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

#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@property (nonatomic, strong) MLAudioRecorder *recorder;
@property (nonatomic, strong) CafRecordWriter *cafWriter;
@property (nonatomic, strong) AmrRecordWriter *amrWriter;

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
    NSString *filePath = [path stringByAppendingPathComponent:@"recording.caf"];
    self.filePath = filePath;
    
    CafRecordWriter *writer = [[CafRecordWriter alloc]init];
    writer.filePath = filePath;
    
    AmrRecordWriter *amrWriter = [[AmrRecordWriter alloc]init];
    amrWriter.filePath = [path stringByAppendingPathComponent:@"record.amr"];
    amrWriter.maxSecondCount = 2;
    amrWriter.maxFileSize = 1024*256;
    self.amrWriter = amrWriter;
    
    MLAudioRecorder *recorder = [[MLAudioRecorder alloc]init];
//    recorder.fileWriterDelegate = writer;
    recorder.fileWriterDelegate = amrWriter;
    
    __weak __typeof(self)weakSelf = self;
    recorder.receiveStoppedBlock = ^{
        [weakSelf.recordButton setTitle:@"Record" forState:UIControlStateNormal];
    };
    
    self.cafWriter = writer;
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
        [recordButton setTitle:@"Record" forState:UIControlStateNormal];
    }else{
        //开始录音
        [self.recorder startRecording];
        [recordButton setTitle:@"Stop" forState:UIControlStateNormal];
    }

}

- (IBAction)play:(id)sender {
//    self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:self.filePath] error:nil];
//    [self.player play];
}

@end
