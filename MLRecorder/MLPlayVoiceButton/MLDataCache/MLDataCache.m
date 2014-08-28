//
//  MLDataCache.m
//  CustomerPo
//
//  Created by molon on 8/15/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "MLDataCache.h"
#import <CommonCrypto/CommonDigest.h>  //md5 用到

static dispatch_queue_t cachedata_concurrent_queue() {
    static dispatch_queue_t ml_cachedata_concurrent_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ml_cachedata_concurrent_queue = dispatch_queue_create("com.molon.ml_cache_data_concurrent_queue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return ml_cachedata_concurrent_queue;
}

static inline NSString * MLDataCacheKeyFromURLRequest(NSURLRequest *request) {
    return [[request URL] absoluteString];
}

@implementation MLDataCache

+ (instancetype)shareInstance {
    static MLDataCache *_shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareInstance = [MLDataCache new];
    });
    return _shareInstance;
}

//得到字符串的md5值
+ (NSString *)md5String:(NSString *)str
{
    const char *cStr = [str UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    memset(result, 0, CC_MD5_DIGEST_LENGTH);
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

- (NSString*)filePathForKey:(NSString*)key
{
    //文件路径需要搞搞
    NSString *documentDirectory = [NSString stringWithFormat:@"%@%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0],@"/Voice/"];//音频缓存文件夹名字
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentDirectory]){
        NSError *error = nil;
        if(![[NSFileManager defaultManager] createDirectoryAtPath:documentDirectory withIntermediateDirectories:YES attributes:nil error:&error]){
            DLOG(@"%@",error);
            return nil;
        }
    }
    
    return [documentDirectory stringByAppendingString:[MLDataCache md5String:key]];
}

- (NSData *)cachedDataForRequest:(NSURLRequest *)request {
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }
    
    NSString *key = MLDataCacheKeyFromURLRequest(request);
	NSData *data = [self objectForKey:key];
    if (!data) {
        //从文件夹里读取
        NSString *filePath = [self filePathForKey:key];
        if (filePath) {
            data = [[NSFileManager defaultManager] contentsAtPath:filePath];
            if(data){
                //存到cache里
                [self cacheData:data forRequest:request];
            }
        }
    }
    return data;
}

- (void)cacheData:(NSData *)data
       forRequest:(NSURLRequest *)request
{
    [self cacheData:data forRequest:request afterCacheInFileSuccess:nil failure:nil];
}

- (void)cacheData:(NSData *)data forRequest:(NSURLRequest *)request afterCacheInFileSuccess:(void(^)(NSURL *filePath))success failure:(void(^)())failure
{
    if (!data||!request) {
        if (failure) {
            failure();
        }
        return;
    }
    
    NSString *key = MLDataCacheKeyFromURLRequest(request);
    [self setObject:data forKey:key];
    
    NSString *filePath  = [self filePathForKey:key];
    if (filePath) {
        dispatch_async(cachedata_concurrent_queue(), ^{
            //下面这玩意是线程安全的，不用害怕
            if(![[NSFileManager defaultManager] createFileAtPath:filePath contents:data attributes:nil]){
                DLOG(@"建立文件缓存:%@失败",filePath);
                if (failure) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure();
                    });
                }
            }else{
                if (success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        success([NSURL fileURLWithPath:filePath]);
                    });
                }
            }
        });
    }
}

/**
 *  返回缓存文件路径
 */
- (NSURL*)cachedFilePathForRequest:(NSURLRequest *)request
{
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }
    
    //直接从文件夹里找
    NSString *filePath = [self filePathForKey:MLDataCacheKeyFromURLRequest(request)];
    if ([[NSFileManager defaultManager]isReadableFileAtPath:filePath]) {
        return [NSURL fileURLWithPath:filePath];
    }
    
    return nil;
}

/**
 *  把文件复制到我们的缓存文件夹
 */
- (void)cacheWithFilePath:(NSURL*)filePath
               forRequest:(NSURLRequest *)request
{
    if (![[NSFileManager defaultManager]isReadableFileAtPath:[filePath path]]||!request) {
        return;
    }
    
    NSString *cacheFilePath = [self filePathForKey:MLDataCacheKeyFromURLRequest(request)];
    //将文件复制到这里
    if(![[NSFileManager defaultManager] copyItemAtURL:filePath toURL:[NSURL fileURLWithPath:cacheFilePath] error:nil]){
        DLOG(@"缓存文件:%@失败",filePath);
    }
}

@end
