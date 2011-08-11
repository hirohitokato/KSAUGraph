//
//  KSAUSound.m
//  KSAUGraph
//
//  Created by 加藤寛人 on 11/08/11.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "KSAUSound.h"

@interface KSAUSound ()
-(void)prepareExtAudio:(NSURL*)fileURL;
@end

@implementation KSAUSound
@synthesize data=playBuffer_;
@synthesize totalFrames=totalFrames_, numberOfChannels=numberOfChannels_;

+(id)soundWithContentsOfURL:(NSURL*)url {
    return [[[KSAUSound alloc] initWithContentsOfURL:url] autorelease];
}

-(id)initWithContentsOfURL:(NSURL*)url {
    self = [super init];
    if(self != nil){
        [self prepareExtAudio:url];        
    }
    return self;
}

- (void)dealloc {
    for(int i = 0; i < numberOfChannels_; i++){
        free(playBuffer_[i]);
    }
    if(playBuffer_)free(playBuffer_);
    [super dealloc];
}

#pragma mark Audio construction
-(void)prepareExtAudio:(NSURL*)fileURL{
    OSStatus err;
    
    ExtAudioFileRef extAudioFile;
    //ExAudioFileの作成
    err = ExtAudioFileOpenURL((CFURLRef)fileURL, &extAudioFile);
    KSAUCheckError(err,"ExtAudioFileOpenURL");
    
	//ファイルデータフォーマットを取得[1]
    AudioStreamBasicDescription inputFormat;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    err = ExtAudioFileGetProperty(extAudioFile, 
                                  kExtAudioFileProperty_FileDataFormat, 
                                  &size,
                                  &inputFormat);
    KSAUCheckError(err,"kExtAudioFileProperty_FileDataFormat");
    
    //Audio Unit正準形のASBD(outputFormat)をそのチャンネル数に変更[2]
    numberOfChannels_ = inputFormat.mChannelsPerFrame;   
    
    AudioStreamBasicDescription clientFormat = AUCanonicalASBD(44100.0, numberOfChannels_);
    //読み込むフォーマットをAudio Unit正準形に設定[3]
    err = ExtAudioFileSetProperty(extAudioFile,
                                  kExtAudioFileProperty_ClientDataFormat, 
                                  sizeof(AudioStreamBasicDescription), 
                                  &clientFormat);
    KSAUCheckError(err,"kExtAudioFileProperty_ClientDataFormat");
    
    //トータルフレーム数を取得しておく
    SInt64 fileLengthFrames;
    size = sizeof(SInt64);
    err = ExtAudioFileGetProperty(extAudioFile, 
                                  kExtAudioFileProperty_FileLengthFrames, 
                                  &size, 
                                  &fileLengthFrames);
    KSAUCheckError(err,"kExtAudioFileProperty_FileLengthFrames");
    totalFrames_ = fileLengthFrames;
    
    
    //AudioBufferListの作成
    playBuffer_ = (AudioUnitSampleType**)malloc(sizeof(AudioUnitSampleType*) * numberOfChannels_);
    for(int i = 0; i < numberOfChannels_; i++){
        playBuffer_[i] = malloc(sizeof(AudioUnitSampleType) * fileLengthFrames);
    }
    
    AudioBufferList *audioBufferList = malloc(sizeof(AudioBufferList));
    audioBufferList->mNumberBuffers = numberOfChannels_;
    for(int i = 0; i < numberOfChannels_; i++){
        audioBufferList->mBuffers[i].mNumberChannels = 1;
        audioBufferList->mBuffers[i].mDataByteSize = sizeof(AudioUnitSampleType) * fileLengthFrames;
        audioBufferList->mBuffers[i].mData = playBuffer_[i];
    }
    
    //位置を0に移動
    ExtAudioFileSeek(extAudioFile, 0);
    
	//全てのフレームをバッファに読み込む
    UInt32 readFrameSize = fileLengthFrames;
    err = ExtAudioFileRead(extAudioFile, &readFrameSize, audioBufferList);
    KSAUCheckError(err,"ExtAudioFileRead");
    
    free(audioBufferList);
}

@end
