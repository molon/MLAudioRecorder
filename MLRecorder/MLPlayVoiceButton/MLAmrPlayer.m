//
//  MLAmrPlayer.m
//  CustomerPo
//
//  Created by molon on 8/15/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "MLAmrPlayer.h"
#import "MLAudioPlayer.h"
#import "AmrPlayerReader.h"

@interface MLAmrPlayer()

@property (nonatomic, strong) MLAudioPlayer *player;
@property (nonatomic, strong) AmrPlayerReader *amrReader;

@property (nonatomic, strong) NSURL *filePath;

@end

@implementation MLAmrPlayer

+ (instancetype)shareInstance {
    static MLAmrPlayer *_shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareInstance = [MLAmrPlayer new];
    });
    return _shareInstance;
}

#pragma mark - life
- (void)dealloc
{
	[_player stopPlaying];
}

#pragma mark - getter
- (MLAudioPlayer *)player
{
	if (!_player) {
		_player = [MLAudioPlayer new];
        _player.fileReaderDelegate = self.amrReader;
        
        __weak __typeof(self)weakSelf = self;
        _player.receiveErrorBlock = ^(NSError *error){
            //这里应该post 一个通知，通知音频播放错误
            [[NSNotificationCenter defaultCenter]postNotificationName:MLAMRPLAYER_PLAY_RECEIVE_ERROR_NOTIFICATION object:nil userInfo:@{@"error":error,@"filePath":weakSelf.filePath}];
        };
        _player.receiveStoppedBlock = ^{
            //这里应该post 一个通知，通知音频播放完毕
            [[NSNotificationCenter defaultCenter]postNotificationName:MLAMRPLAYER_PLAY_RECEIVE_STOP_NOTIFICATION object:nil userInfo:@{@"filePath":weakSelf.filePath}];
        };
	}
	return _player;
}

- (AmrPlayerReader *)amrReader
{
	if (!_amrReader) {
		_amrReader = [AmrPlayerReader new];
		
	}
	return _amrReader;
}

- (BOOL)isPlaying
{
	return self.player.isPlaying;
}

#pragma mark - setter
- (void)setFilePath:(NSURL *)filePath
{
    _filePath = filePath;

    self.amrReader.filePath = [filePath path];
}

#pragma mark - outcall
- (void)playWithFilePath:(NSURL*)filePath
{
    [self.player stopPlaying];
    self.filePath = filePath;
    [self.player startPlaying];
}

- (void)stopPlaying
{
    [self.player stopPlaying];
}

#pragma mark - other
+ (double)durationOfAmrFilePath:(NSURL*)filePath
{
    return [AmrPlayerReader durationOfAmrFilePath:[filePath path]];
}
@end
