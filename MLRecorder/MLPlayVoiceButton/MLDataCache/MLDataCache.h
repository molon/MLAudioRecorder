//
//  MLDataCache.h
//  CustomerPo
//
//  Created by molon on 8/15/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MLDataCache : NSCache

+ (instancetype)shareInstance;

- (NSData *)cachedDataForRequest:(NSURLRequest *)request;

- (void)cacheData:(NSData *)data
       forRequest:(NSURLRequest *)request;
/**
 *  带保存文件回调的
 */
- (void)cacheData:(NSData *)data forRequest:(NSURLRequest *)request afterCacheInFileSuccess:(void(^)(NSURL *filePath))success failure:(void(^)())failure;

/**
 *  返回缓存文件路径
 */
- (NSURL*)cachedFilePathForRequest:(NSURLRequest *)request;

/**
 *  把文件作为缓存文件复制到我们的缓存文件夹，使用缓存的命名方式
 */
- (void)cacheWithFilePath:(NSURL*)filePath
       forRequest:(NSURLRequest *)request;

@end
