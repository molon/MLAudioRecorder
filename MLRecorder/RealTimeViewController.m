//
//  RealTimeViewController.m
//  MLRecorder
//
//  Created by molon on 14/12/19.
//  Copyright (c) 2014年 molon. All rights reserved.
//

#import "RealTimeViewController.h"
#import "MLAudioRecorder.h"
#import "MLAudioRealTimePlayer.h"
#import "CafRecordInBufferWriter.h"
#import "AmrRecordInBufferWriter.h"

//amr解码
#import "interf_dec.h"

#warning 特别注意一个问题，测试此功能的时候请使用耳机，否则会造成电脑播放出来的声音又被录了进去，造成死循环不断重复。。老子因为这个屌问题研究了他妈的几个小时。最后还是我媳妇发现的！！

@interface RealTimeViewController()

@property (nonatomic, strong) MLAudioRecorder *recorder;
@property (nonatomic, strong) MLAudioRealTimePlayer *player;
@property (nonatomic, strong) CafRecordInBufferWriter *cafRecordWriter;
@property (nonatomic, strong) AmrRecordInBufferWriter *amrRecordWriter;

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
    self.simulateSlackButton.frame = CGRectMake(self.button.frame.origin.x-10.0f, CGRectGetMaxY(self.button.frame)+20.0f, 100, 40);
    
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


- (NSData*)decodeForAmrData:(NSData*)amrData
{
    //其实_destate 只需要初始化一次就够了。这里为了方便先扔这，只是demo嘛。。
    void *_destate = 0;
    // amr 解压句柄
    _destate = Decoder_Interface_init();
    
    if(_destate==0){
        return nil;
    }
    
    int amrFramelen = 14;
    int needReadFrameCount = floor(amrData.length/amrFramelen);
    
    NSMutableData *data = [NSMutableData data];
    
    unsigned char amrFrame[amrFramelen];
    short pcmFrame[160];
    
    for (NSUInteger i=0; i<needReadFrameCount; i++) {
        memset(amrFrame, 0, sizeof(amrFrame));
        memset(pcmFrame, 0, sizeof(pcmFrame));
        
        NSRange range = NSMakeRange(amrFramelen*i, amrFramelen);
        
        [amrData getBytes:amrFrame range:range];
        
        // 解码一个AMR音频帧成PCM数据 (8k-16b-单声道)
        Decoder_Interface_Decode(_destate, amrFrame, pcmFrame, 0);
        
        [data appendBytes:pcmFrame length:sizeof(pcmFrame)];
    }
    
    if (_destate){
        Decoder_Interface_exit((void*)_destate);
        _destate = 0;
    }
    
    return data;
}

- (AmrRecordInBufferWriter *)amrRecordWriter
{
    if (!_amrRecordWriter) {
        _amrRecordWriter = [AmrRecordInBufferWriter new];
        __weak __typeof(self)weakSelf = self;
        [_amrRecordWriter setDidReceiveVoiceData:^(NSData *data) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            
            //解码
            NSData *decodedData = [strongSelf decodeForAmrData:data];
            
            void (^executeBlock)() = ^{
                //投递到Player里
                if (strongSelf.isInSlack) {
                    [strongSelf.simulateSlackDatas addObject:decodedData];
                    //只保留4个，根据kDefaultBufferDurationSeconds的话应该是1秒的时间，原因见simulateSlackButtonPressed
                    if (strongSelf.simulateSlackDatas.count>4) {
                        [strongSelf.simulateSlackDatas removeObjectAtIndex:0];
                    }
                }else{
                    [strongSelf.player appendPacket:decodedData];
                }
            };
            
            if (![[NSThread currentThread]isEqual:[NSThread mainThread]]) {
                dispatch_async(dispatch_get_main_queue(), ^{ //注意这个屌地不是主线程，需要投递到主线程去做
                    executeBlock();
                });
            }else{
                executeBlock();
            }
        }];
    }
    return _amrRecordWriter;
}

- (CafRecordInBufferWriter *)cafRecordWriter
{
    if (!_cafRecordWriter) {
        _cafRecordWriter = [CafRecordInBufferWriter new];
        __weak __typeof(self)weakSelf = self;
        [_cafRecordWriter setDidReceiveVoiceData:^(NSData *data) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            void (^executeBlock)() = ^{
                //投递到Player里
                if (strongSelf.isInSlack) {
                    [strongSelf.simulateSlackDatas addObject:data];
                    //只保留4个，根据kDefaultBufferDurationSeconds的话应该是1秒的时间，原因见simulateSlackButtonPressed
                    if (strongSelf.simulateSlackDatas.count>4) {
                        [strongSelf.simulateSlackDatas removeObjectAtIndex:0];
                    }
                }else{
                    [strongSelf.player appendPacket:data];
                }
            };
            
            if (![[NSThread currentThread]isEqual:[NSThread mainThread]]) {
                dispatch_async(dispatch_get_main_queue(), ^{ //注意这个屌地不是主线程，需要投递到主线程去做
                    executeBlock();
                });
            }else{
                executeBlock();
            }
        }];
    }
    return _cafRecordWriter;
}


- (MLAudioRecorder *)recorder
{
    if (!_recorder) {
        _recorder = [MLAudioRecorder new];
        //这里可以改变是那种编码方式
//        _recorder.fileWriterDelegate = self.amrRecordWriter;
        _recorder.fileWriterDelegate = self.cafRecordWriter;
    }
    return _recorder;
}

- (MLAudioRealTimePlayer *)player
{
    if (!_player) {
        _player = [MLAudioRealTimePlayer new];
        [_player setDidReceiveErrorBlock:^(MLAudioRealTimePlayer *player, NSError *error) {
            DLOG(@"实时播放错误:%@",error);
        }];
        [_player setDidReceiveStoppedBlock:^(MLAudioRealTimePlayer *player) {
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
#warning 这里需要注意，卡顿的时间里记录的数据投递后，卡顿的时间实时播放里会永远延迟，测试下即可发现。对于这种情况是没法避免的，我们只能只能忽略卡顿内的数据，或者只播放其中的最后一小段，这个使用时请根据自身情况判断。
        for (NSData *data in self.simulateSlackDatas) {
            [self.player appendPacket:data];
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
