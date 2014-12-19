//
//  PlayNetworkVoiceViewController.m
//  MLRecorder
//
//  Created by molon on 8/28/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "PlayNetworkVoiceViewController.h"
#import "MLPlayVoiceButton.h"
#import "MLAmrPlayer.h"

@interface PlayNetworkVoiceViewController ()

@property (weak, nonatomic) IBOutlet MLPlayVoiceButton *voiceButton1;
@property (weak, nonatomic) IBOutlet MLPlayVoiceButton *voiceButton2;

@end

@implementation PlayNetworkVoiceViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
	[[MLAmrPlayer shareInstance]stopPlaying];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.voiceButton1 setVoiceWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/molon/MLAudioRecorder/master/record1.amr"]];
    
    self.voiceButton2.type = MLPlayVoiceButtonTypeRight;
    [self.voiceButton2 setVoiceWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/molon/MLAudioRecorder/master/record2.amr"]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
