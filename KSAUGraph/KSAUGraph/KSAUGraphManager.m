//
//  KSAUGraphManager.m
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "KSAUGraphManager.h"

@interface KSAUGraphManager ()
// オーディオリソースの解放
- (void)unload;

@end

@implementation KSAUGraphManager
static id _instance = nil;
static BOOL _willDelete = NO;

- (void)prepare {	
    //AUGraphをインスタンス化
    NewAUGraph(&mAuGraph);
	AUGraphOpen(mAuGraph);
	
    //Remote IOのAudioComponentDescriptionを用意する
    AudioComponentDescription cd;
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_RemoteIO;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    
    //AUGraphにRemote IOのノードを追加する
    AUNode remoteIONode;
    AUGraphAddNode(mAuGraph, &cd, &remoteIONode);
    
    //MultiChannelMixerのAudioComponentDescriptionを用意する
    cd.componentType = kAudioUnitType_Mixer;
    cd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    
    //AUGraphにMultiChannelMixerのノードを追加する
    AUNode multiChannelMixerNode;
    AUGraphAddNode(mAuGraph, &cd, &multiChannelMixerNode);
    
    
    //2つのインプットバスにコールバック関数を登録
    UInt32 numOfBus = 2;
    for(int i = 0; i < numOfBus; i++){
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = renderCallback;
        callbackStruct.inputProcRefCon = &sineWaveDef[i];      
        //コールバック関数の設定
        AUGraphSetNodeInputCallback(mAuGraph,
                                    multiChannelMixerNode, 
                                    i, //バスナンバー
                                    &callbackStruct);
    }
    
    AudioUnit remoteIOAudioUnit;
    AUGraphNodeInfo(mAuGraph, remoteIONode, 
                    NULL, &remoteIOAudioUnit);
    
    AUGraphNodeInfo(mAuGraph, multiChannelMixerNode,
                    NULL, &multiChannelMixerAudioUnit);

    //Audio Unit正準形
	AudioStreamBasicDescription audioFormat = AUCanonicalASBD(44100.0, 2);
    
    //それぞれのAudio UnitにASBDを設定する
    AudioUnitSetProperty(remoteIOAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &audioFormat,
                         sizeof(audioFormat));
    
    AudioUnitSetProperty(multiChannelMixerAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &audioFormat,
                         sizeof(audioFormat));
    
    //multiChannelMixerNode(バス:0)からremoteIONode(バス:0)に繫ぐ
    AUGraphConnectNodeInput(mAuGraph, 
                            multiChannelMixerNode, //このノードの
                            0,//このバス(output)から
                            remoteIONode, //このノードの
                            0 //このバス(input)に接続する
                            );
    
    //準備が整ったらAUGraphを初期化
    AUGraphInitialize(mAuGraph);
}

- (void)unload {
    if(isPlaying)[self stop];
    AUGraphUninitialize(mAuGraph);
    AUGraphClose(mAuGraph);
    DisposeAUGraph(mAuGraph);
}

#pragma mark -
-(void)play {
    if(!isPlaying){
        AUGraphStart(mAuGraph);
    }
    isPlaying = YES;
}

-(void)stop {
    if(isPlaying)AUGraphStop(mAuGraph);
    isPlaying = NO;
}

- (Float32)volume {
    Float32 volume;
    AudioUnitGetParameter(multiChannelMixerAudioUnit,
                          kMultiChannelMixerParam_Volume,
                          kAudioUnitScope_Output,
                          0,
                          &volume);
    return volume;
}
- (void)setVolume:(Float32)volume {
    if (volume<0.0f || volume>1.0) {
        NSLog(@"Invalid volume(%f)\n", volume);
        return;
    }
    AudioUnitParameterValue v = (AudioUnitParameterValue)volume;
    AudioUnitSetParameter(multiChannelMixerAudioUnit,
                          kMultiChannelMixerParam_Volume,
                          kAudioUnitScope_Output, //アウトプット
                          0, //バスナンバー
                          v, 
                          0);
}

#pragma mark -
#pragma mark Methods for singleton
+ (id)sharedInstance {
    @synchronized(self) {
        if (!_instance) {
            [[self alloc] init]; // ここでは代入していない
        }
    }
    return _instance;
}

+ (id)allocWithZone:(NSZone*)zone {
    @synchronized(self) {
        if (!_instance) {
            _instance = [super allocWithZone:zone]; // ここで代入
            return _instance;
        }
    }
    return nil; // ２回目以降の割り当てではnilを返す
}

- (id)copyWithZone:(NSZone*)zone { return self; }
- (id)retain { return self; }
- (unsigned)retainCount { return UINT_MAX;/* 解放できないオブジェクト */ }
- (id)autorelease { return self; }

- (void)release {
    @synchronized(self) {
        if (_willDelete) {
            [super release];
        }
    }
}

+ (void)deleteInstance {
    if (_instance) {
        @synchronized(_instance) {
            _willDelete = YES;
            [_instance release];
            _instance = nil;
            _willDelete = NO;
        }
    }
}

- (void)dealloc {
    [self unload];

    [super dealloc];
}

@end
