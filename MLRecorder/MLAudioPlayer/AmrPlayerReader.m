//
//  AmrPlayerReader.m
//  MLRecorder
//
//  Created by molon on 5/23/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "AmrPlayerReader.h"

//amr解码
#import "interf_dec.h"

#define AMR_MAGIC_NUMBER "#!AMR\n"

#define PCM_FRAME_SIZE 160 // 8khz 8000*0.02=160
#define MAX_AMR_FRAME_SIZE 32
#define AMR_FRAME_COUNT_PER_SECOND 50
int amrEncodeMode[] = {4750, 5150, 5900, 6700, 7400, 7950, 10200, 12200}; // amr 编码方式

@interface AmrPlayerReader()
{
    FILE *_file;
    void *_destate;
    
    //帧头标识和帧大小
    unsigned char _stdFrameHeader;
    int _stdFrameSize;
}

@property (nonatomic, assign) NSUInteger readedLength;
@property (nonatomic, assign) double readedSecondCount;

@end

@implementation AmrPlayerReader

const int myround(const double x)
{
	return((int)(x+0.5));
}

// 根据帧头计算当前帧大小
int caclAMRFrameSize(unsigned char frameHeader)
{
	int mode;
	int temp1 = 0;
	int temp2 = 0;
	int frameSize;
	
	temp1 = frameHeader;
	
	// 编码方式编号 = 帧头的3-6位
	temp1 &= 0x78; // 0111-1000
	temp1 >>= 3;
	
	mode = amrEncodeMode[temp1];
	
	// 计算amr音频数据帧大小
	// 原理: amr 一帧对应20ms，那么一秒有50帧的音频数据
	temp2 = myround((double)(((double)mode / (double)AMR_FRAME_COUNT_PER_SECOND) / (double)8));
	
	frameSize = myround((double)temp2 + 0.5);
	return frameSize;
}

// 读第一个帧 - (参考帧)
BOOL ReadAMRFrameFirst(FILE* fpamr, int* stdFrameSize, unsigned char* stdFrameHeader)
{
    unsigned long curpos = ftell(fpamr); //记录当前位置，这一帧只是读取一下，并不做处理
    
    fseek(fpamr, strlen(AMR_MAGIC_NUMBER), SEEK_SET);
    
    //先读帧头
	fread(stdFrameHeader, 1, sizeof(unsigned char), fpamr);
	if (feof(fpamr)) return NO;
	
    fseek(fpamr,curpos,SEEK_SET); //还原位置
    
	// 根据帧头计算帧大小
	*stdFrameSize = caclAMRFrameSize(*stdFrameHeader);
	
	return YES;
}

long filesize(FILE *stream)
{
    long curpos,length;
    curpos=ftell(stream);
    fseek(stream,0L,SEEK_END);
    length=ftell(stream);
    fseek(stream,curpos,SEEK_SET);
    return length;
}

+ (double)durationOfAmrFilePath:(NSString*)filePath
{
    //建立amr文件
    if ([filePath hasPrefix:@"file://"]) {
        filePath = [filePath substringFromIndex:7];
    }
    FILE *file = fopen((const char *)[filePath UTF8String], "rb");
    if (file==0) {
        DLOG(@"打开文件失败:%s",__FUNCTION__);
        return 0;
    }
    unsigned char stdFrameHeader;
    int stdFrameSize;
    if(!ReadAMRFrameFirst(file, &stdFrameSize, &stdFrameHeader)){
        return 0;
    }
    
    //检测此文件一共有多少帧
    long fileSize = filesize(file);
    if(file){
        fclose(file);
    }
    
    return ((fileSize - strlen(AMR_MAGIC_NUMBER))/(double)stdFrameSize)/(double)AMR_FRAME_COUNT_PER_SECOND;
}

- (double)duration
{
    return [[self class]durationOfAmrFilePath:self.filePath];
}

- (BOOL)openFileWithPlayer:(MLAudioPlayer*)player
{
    _destate = 0;
    // amr 解压句柄
    _destate = Decoder_Interface_init();
    
    if(_destate==0){
        return NO;
    }
    
    //建立amr文件
    NSString *filePath = self.filePath;
    if ([filePath hasPrefix:@"file://"]) {
        filePath = [filePath substringFromIndex:7];
    }
    _file = fopen((const char *)[filePath UTF8String], "rb");
    if (_file==0) {
        DLOG(@"打开文件失败:%s",__FUNCTION__);
        return NO;
    }

    //忽略文件头大小
    char magic[8];
    static const char* amrHeader = AMR_MAGIC_NUMBER;
    int realReadedLength = fread(magic, sizeof(char), strlen(amrHeader), _file);
	if (strncmp(magic, amrHeader, strlen(amrHeader)))
	{
		return NO;
	}
    self.readedLength += realReadedLength;
    
    //读取一个参考帧
    if(!ReadAMRFrameFirst(_file, &_stdFrameSize, &_stdFrameHeader)){
        return NO;
    }
//	DLOG(@"帧大小%d,帧头%c",_stdFrameSize,_stdFrameHeader);
    
    return YES;
}

- (AudioStreamBasicDescription)customAudioFormatAfterOpenFile
{
    AudioStreamBasicDescription format;
    format.mSampleRate = 8000;
    format.mChannelsPerFrame = 1;
	format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBitsPerChannel = 16;
    format.mBytesPerPacket = format.mBytesPerFrame = (format.mBitsPerChannel / 8) * format.mChannelsPerFrame;
    format.mFramesPerPacket = 1;
    return format;
}

- (NSData*)readDataFromFileWithPlayer:(MLAudioPlayer*)player andBufferSize:(NSUInteger)bufferSize error:(NSError**)error
{
    //读取数据
    if (!_file) {
        return nil;
    }
    
    //计算存储到bufferSize里需要读取多少帧
    int needReadFrameCount = floor(bufferSize/(PCM_FRAME_SIZE*sizeof(short)));
    
    NSMutableData *data = [NSMutableData data];
    
	unsigned char amrFrame[MAX_AMR_FRAME_SIZE];
	short pcmFrame[PCM_FRAME_SIZE];
    
    for (NSUInteger i=0; i<needReadFrameCount; i++) {
        memset(amrFrame, 0, sizeof(amrFrame));
        memset(pcmFrame, 0, sizeof(pcmFrame));
		
        int bytes = 0;
        unsigned char frameHeader; // 帧头
        
        // 读帧头
        // 如果是坏帧(不是标准帧头)，则继续读下一个字节，直到读到标准帧头
        while(1)
        {
            bytes = fread(&frameHeader, 1, sizeof(unsigned char), _file);
            if (feof(_file)) break;
            if (frameHeader == _stdFrameHeader) break;
            
            self.readedLength += bytes;
        }
        
        if (frameHeader!=_stdFrameHeader) {
            break;
        }
        
        // 读该帧的语音数据(帧头已经读过)
        amrFrame[0] = frameHeader;
        bytes = fread(&(amrFrame[1]), 1, (_stdFrameSize-1)*sizeof(unsigned char), _file);
        if (feof(_file)) break;
        
        self.readedLength += bytes;
		
		// 解码一个AMR音频帧成PCM数据 (8k-16b-单声道)
		Decoder_Interface_Decode(_destate, amrFrame, pcmFrame, 0);
        
        [data appendBytes:pcmFrame length:sizeof(pcmFrame)];
    }
    
    return data;
}

- (BOOL)completeReadWithPlayer:(MLAudioPlayer*)player withIsError:(BOOL)isError
{
    //关闭就关闭吧。管他关闭成功与否
    if(_file){
        fclose(_file);
        _file = 0;
    }
    if (_destate){
        Decoder_Interface_exit((void*)_destate);
        _destate = 0;
    }
    
    return YES;
}

- (void)dealloc
{
	if(_file){
        fclose(_file);
        _file = 0;
    }
    if (_destate){
        Decoder_Interface_exit((void*)_destate);
        _destate = 0;
    }
}



@end
