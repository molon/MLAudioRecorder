//
//  MLPlayVoiceButton.h
//  CustomerPo
//
//  Created by molon on 8/15/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MLDataCache.h"

#define kMLPlayVoiceButtonErrorDomain @"MLPlayVoiceButtonErrorDomain"
/**
 *  错误标识
 */
typedef NS_OPTIONS(NSUInteger, MLPlayVoiceButtonErrorCode) {
    MLPlayVoiceButtonErrorCodeCacheFailed = 0, //写入缓存文件失败
    MLPlayVoiceButtonErrorCodeWrongVoiceFomrat,//音频文件格式错误
};


typedef NS_OPTIONS(NSUInteger, MLPlayVoiceButtonType) {
    MLPlayVoiceButtonTypeLeft = 0,
    MLPlayVoiceButtonTypeRight,
};

typedef NS_OPTIONS(NSUInteger, MLPlayVoiceButtonState) {
    MLPlayVoiceButtonStateNone = 0,
    MLPlayVoiceButtonStateNormal,
    MLPlayVoiceButtonStateDownloading,
};

@interface MLPlayVoiceButton : UIButton

@property (nonatomic, strong,readonly) NSURL *voiceURL;

@property (nonatomic, assign) MLPlayVoiceButtonType type;
@property (nonatomic, assign,readonly) MLPlayVoiceButtonState voiceState;
@property (nonatomic, assign) NSTimeInterval duration;

- (CGFloat)preferredWidth;

@property (nonatomic, copy) void(^preferredWidthChangedBlock)(MLPlayVoiceButton *voiceButton,BOOL isShouldBeAnimated);

@property (nonatomic, copy) void(^voiceWillPlayBlock)(MLPlayVoiceButton *voiceButton);

#pragma mark - cache
+ (MLDataCache*)sharedDataCache;

#pragma mark - cancel
- (void)cancelVoiceRequestOperation;

#pragma mark - set voice
- (void)setVoiceWithURL:(NSURL*)url;
- (void)setVoiceWithURL:(NSURL*)url withAutoPlay:(BOOL)autoPlay;

- (void)setVoiceWithURL:(NSURL *)url success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSURL* voicePath))success
                failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure;

- (void)setVoiceWithURLRequest:(NSURLRequest *)urlRequest success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSURL* voicePath))success
                failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure;
@end
