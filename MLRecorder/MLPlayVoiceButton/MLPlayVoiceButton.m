//
//  MLPlayVoiceButton.m
//  CustomerPo
//
//  Created by molon on 8/15/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "MLPlayVoiceButton.h"
#import "MLDataResponseSerializer.h"
#import "MLAmrPlayer.h"
#import "AFNetworking.h"
#define AMR_MAGIC_NUMBER "#!AMR\n"

@interface MLPlayVoiceButton()

@property (nonatomic, strong) AFHTTPRequestOperation *af_dataRequestOperation;

@property (nonatomic, strong) NSURL *voiceURL;

@property (nonatomic, assign) BOOL isVoicePlaying;

@property (nonatomic, strong) UIImageView *playingSignImageView;

@property (nonatomic, strong) NSURL *filePath;

@property (nonatomic, strong) UIActivityIndicatorView *indicator;

@property (nonatomic, assign) MLPlayVoiceButtonState voiceState;

@end

@implementation MLPlayVoiceButton

#pragma mark - cache
+ (MLDataCache*)sharedDataCache {
    return [MLDataCache shareInstance];
}

#pragma mark - cancel
- (void)cancelVoiceRequestOperation {
    [self.af_dataRequestOperation cancel];
    self.af_dataRequestOperation = nil;
}

#pragma mark - life
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self setUp];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setUp];
}

- (void)setUp
{
    [self addSubview:self.playingSignImageView];
    [self addSubview:self.indicator];
    self.voiceState = MLPlayVoiceButtonStateNone;
    
    [self updatePlayingSignImage];
    
    //        [self setBackgroundImage:[UIImage imageWithPureColor:[UIColor colorWithWhite:0.253 alpha:0.650]] forState:UIControlStateHighlighted];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playReceiveStop:) name:MLAMRPLAYER_PLAY_RECEIVE_STOP_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playReceiveError:) name:MLAMRPLAYER_PLAY_RECEIVE_ERROR_NOTIFICATION object:nil];
    
    [self addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

#pragma mark - notification
- (void)playReceiveStop:(NSNotification*)notification
{
    NSDictionary *userInfo = notification.userInfo;
    if (![userInfo[@"filePath"] isEqual:self.filePath]) {
        return;
    }
    DLOG(@"发现音频播放停止:%@,如果发现此处执行多次不用在意。那可能是因为tableView复用的关系",[self.filePath path]);
    
    [self updatePlayingSignImage];
    
}

- (void)playReceiveError:(NSNotification*)notification
{
    NSDictionary *userInfo = notification.userInfo;
    if (![userInfo[@"filePath"] isEqual:self.filePath]) {
        return;
    }
#warning 这里最好做下发现当前音频播放错误处理
    DLOG(@"发现音频播放错误:%@",[self.filePath path]);
    [self updatePlayingSignImage];
}

#pragma mark - event
- (void)click
{
    if (!self.filePath) {
        return;
    }
    
    if (!self.isVoicePlaying) {
        if (self.voiceWillPlayBlock) {
            self.voiceWillPlayBlock(self);
        }
        [[MLAmrPlayer shareInstance]playWithFilePath:self.filePath];
        [self updatePlayingSignImage];
    }else{
        [[MLAmrPlayer shareInstance]stopPlaying];
    }
}

#pragma mark - getter
- (BOOL)isVoicePlaying
{
	if ([MLAmrPlayer shareInstance].isPlaying&&[[MLAmrPlayer shareInstance].filePath isEqual:self.filePath]) {
        return YES;
    }
    return NO;
}

- (UIImageView *)playingSignImageView
{
    if (!_playingSignImageView) {
		UIImageView *imageView = [[UIImageView alloc]init];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        _playingSignImageView = imageView;
    }
    return _playingSignImageView;
}

- (UIActivityIndicatorView *)indicator
{
	if (!_indicator) {
		_indicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        
	}
	return _indicator;
}
#pragma mark - setter
- (void)setType:(MLPlayVoiceButtonType)type
{
    _type = type;
    
    [self updatePlayingSignImage];
    
    [self setNeedsLayout];
}

- (void)setFilePath:(NSURL *)filePath
{
    _filePath = filePath;
    
    if (filePath) {
        if (self.duration<=0) {
            _duration = [MLAmrPlayer durationOfAmrFilePath:filePath];
        }
        self.voiceState = MLPlayVoiceButtonStateNormal;
    }else{
        _duration = 0.0f;
        self.voiceState = MLPlayVoiceButtonStateNone;
    }
}

- (void)setVoiceState:(MLPlayVoiceButtonState)voiceState
{
    _voiceState = voiceState;
    
    //如果none啥都没，
    if (voiceState == MLPlayVoiceButtonStateNone) {
        [self.indicator stopAnimating];
        self.playingSignImageView.hidden = YES;
    }else if (voiceState == MLPlayVoiceButtonStateDownloading){
        [self.indicator startAnimating];
        self.playingSignImageView.hidden = YES;
    }else if (voiceState == MLPlayVoiceButtonStateNormal){
        self.playingSignImageView.hidden = NO;
        [self.indicator stopAnimating];
    }
    
    if (self.preferredWidthChangedBlock) {
        self.preferredWidthChangedBlock(self,NO);
    }
}

- (void)setDuration:(NSTimeInterval)duration
{
    _duration = duration;
    
    if (self.preferredWidthChangedBlock) {
        self.preferredWidthChangedBlock(self,NO);
    }
}

#pragma mark - 图像
- (void)updatePlayingSignImage
{
    if (self.voiceState==MLPlayVoiceButtonStateDownloading) {
        self.playingSignImageView.image = nil;
        return;
    }
    
    NSString *prefix = self.type==MLPlayVoiceButtonTypeLeft?@"ReceiverVoiceNodePlaying00":@"SenderVoiceNodePlaying00";
    if ([self isVoicePlaying]) {
        self.playingSignImageView.image = [UIImage animatedImageNamed:prefix duration:1.0f];
    }else{
        self.playingSignImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@3",prefix]];
    }
}


#pragma mark - layout
- (void)layoutSubviews
{
    [super layoutSubviews];
    
#define kVoicePlaySignSideLength 20.0f
    if (self.type == MLPlayVoiceButtonTypeRight) {
        self.playingSignImageView.frame = CGRectMake(self.frame.size.width-kVoicePlaySignSideLength-5.0f, (self.frame.size.height-kVoicePlaySignSideLength)/2, kVoicePlaySignSideLength, kVoicePlaySignSideLength);
    }else{
        self.playingSignImageView.frame = CGRectMake(5.0f, (self.frame.size.height-kVoicePlaySignSideLength)/2, kVoicePlaySignSideLength, kVoicePlaySignSideLength);
    }
    
    self.indicator.frame = self.playingSignImageView.frame;
}

#pragma mark - outcall
- (void)setVoiceWithURL:(NSURL*)url
{
    [self setVoiceWithURL:url withAutoPlay:NO];
}

- (void)setVoiceWithURL:(NSURL*)url withAutoPlay:(BOOL)autoPlay
{
    __weak __typeof(self)weakSelf = self;
    [self setVoiceWithURL:url success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSURL *voicePath) {
        if (!voicePath) {
            weakSelf.filePath = voicePath;
            return;
        }
        
        weakSelf.filePath = voicePath;
        if (autoPlay) {
            if (weakSelf.voiceWillPlayBlock) {
                weakSelf.voiceWillPlayBlock(weakSelf);
            }
            [[MLAmrPlayer shareInstance]playWithFilePath:weakSelf.filePath];
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
        DLOG(@"%@",error);
        weakSelf.filePath = nil;
    }];
}

- (void)setVoiceWithURL:(NSURL *)url success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSURL* voicePath))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"*/*" forHTTPHeaderField:@"Accept"];
    
    [self setVoiceWithURLRequest:request success:success failure:failure];
}

- (void)setVoiceWithURLRequest:(NSURLRequest *)urlRequest success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSURL* voicePath))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    self.voiceURL = [urlRequest URL];

    //无论如何，该去掉的就得去掉
#warning 这里有个弊端，例如上一个设置了autoPlay，然后tableViewCell重用后，会取消，然后肯定上面那个就不能自动播放了，似乎也不适合处理这个情况。回头再考虑吧。不过有个应该考虑下，下一半还没下完，然后被重用了,这样之前的下载就被丢弃了！，AFNetworking的图片处理也有类似情况
    self.filePath = nil;
    [self cancelVoiceRequestOperation];
    
    if ([self.voiceURL isFileURL]) {
        if (success) {
            success(urlRequest, nil, self.voiceURL);
        } else if (self.voiceURL) {
            self.filePath = self.voiceURL;
        }
        return;
    }
    
    if (nil==self.voiceURL) {
        if (success) {
            success(urlRequest,nil,self.voiceURL);
        }
        return;
    }
    
    NSURL *filePath = [[[self class] sharedDataCache] cachedFilePathForRequest:urlRequest];
    if (filePath) {
        if (success) {
            success(nil, nil, filePath);
        } else {
            self.filePath = filePath;
        }
        self.af_dataRequestOperation = nil;
    } else {
        self.voiceState = MLPlayVoiceButtonStateDownloading;
        
        DLOG(@"下载音频%@",[urlRequest URL]);
        __weak __typeof(self)weakSelf = self;
        self.af_dataRequestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
        self.af_dataRequestOperation.responseSerializer = [MLDataResponseSerializer shareInstance];
        [self.af_dataRequestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            static const char* amrHeader = AMR_MAGIC_NUMBER;
            char magic[8];
            [responseObject getBytes:magic length:strlen(amrHeader)];
            
            if (strncmp(magic, amrHeader, strlen(amrHeader)))
            {
                NSError *error = [NSError errorWithDomain:kMLPlayVoiceButtonErrorDomain code:MLPlayVoiceButtonErrorCodeWrongVoiceFomrat userInfo:@{NSLocalizedDescriptionKey:@"音频非amr文件"}];
                if (failure) {
                    failure(urlRequest,operation.response,error);
                }
                return;
            }
            
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                //写入文件
                [[[strongSelf class] sharedDataCache] cacheData:responseObject forRequest:urlRequest afterCacheInFileSuccess:^(NSURL *filePath) {
                    if (success) {
                        success(urlRequest, operation.response, filePath);
                    } else if (filePath) {
                        strongSelf.filePath = filePath;
                    }
                } failure:^{
                    NSError *error = [NSError errorWithDomain:kMLPlayVoiceButtonErrorDomain code:MLPlayVoiceButtonErrorCodeCacheFailed userInfo:@{NSLocalizedDescriptionKey:@"写入音频缓存文件失败"}];
                    if (failure) {
                        failure(urlRequest, operation.response, error);
                    }
                }];
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                if (failure) {
                    failure(urlRequest, operation.response, error);
                }
            }
        }];
        
        [[MLDataResponseSerializer sharedDataRequestOperationQueue] addOperation:self.af_dataRequestOperation];
    }
}


#pragma mark - preferredWidth
- (CGFloat)preferredWidth
{
#define kMinDefaultWidth 50.0f
#define kMaxWidth 120.0f
    if (self.voiceState != MLPlayVoiceButtonStateNormal) {
        return kMinDefaultWidth;
    }
    
    CGFloat width = kMinDefaultWidth + ceil(self.duration)*5.0f;
    if (width>kMaxWidth) {
        width = kMaxWidth;
    }
    return width;
}

@end
