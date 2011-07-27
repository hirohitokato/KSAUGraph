//
//  KSAUGraphManager.m
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "KSAUGraphManager.h"
#import "KSAUGraphNode.h"

@interface KSAUGraphManager ()
#pragma mark Private methods
// オーディオリソースの解放
- (void)unload;

@end

@implementation KSAUGraphManager
static id _instance = nil;
static BOOL _willDelete = NO;

- (id)init {
    self = [super init];
    if (self) {
        isPlaying_ = NO;
        auGraph_ = NULL;
        multiChannelMixerAudioUnit_ = NULL;
    }
    return self;
}

static OSStatus renderCallback(void*                       inRefCon,
                               AudioUnitRenderActionFlags* ioActionFlags,
                               const AudioTimeStamp*       inTimeStamp,
                               UInt32                      inBusNumber,
                               UInt32                      inNumberFrames,
                               AudioBufferList*            ioData
                               ){
    KSAUGraphNode *node = (KSAUGraphNode *)inRefCon;
    KSAUGraphManager *manager = node.manager;
    
    // 再生が始まるまではゼロフィル
    // waitFramesが0ならば
    //   自分が鳴らすべきかどうかを
    //   nodeのisPlayingがNOで、waitFramesが0より大きければ、ゼロフィル＆waitFramesをデクリメント
    //   nodeのisPlayingがYESで、waitFramesが0より大きければ、nodeにフィルしてもらう＆waitFramesをデクリメント
    // 始まったら呼ぶ
    // （残りのバッファサイズが戻ってくる）
    // バッファサイズが非ゼロなら、残りをゼロフィル
    return noErr;
}

- (void)prepareWithChannels:(NSArray *)array {
    // 8チャンネル以下
    if ([array count] > 8) {
        NSLog(@"Array count(%d) must be within 8.", [array count]);
        return;
    }

    //AUGraphをインスタンス化
    NewAUGraph(&auGraph_);
	AUGraphOpen(auGraph_);

    //Remote IOのAudioComponentDescriptionを用意する
    AudioComponentDescription cd;
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_RemoteIO;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    
    //AUGraphにRemote IOのノードを追加する
    AUNode remoteIONode;
    AUGraphAddNode(auGraph_, &cd, &remoteIONode);
    
    //MultiChannelMixerのAudioComponentDescriptionを用意する
    cd.componentType = kAudioUnitType_Mixer;
    cd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    
    //AUGraphにMultiChannelMixerのノードを追加する
    AUNode multiChannelMixerNode;
    AUGraphAddNode(auGraph_, &cd, &multiChannelMixerNode);
    
    
    // インプットバスにコールバック関数を登録
    // 引数には配列の各要素を渡す
    int inputCount = [array count];
    for(int i = 0; i < inputCount; i++){
        KSAUGraphNode *node = [array objectAtIndex:i];
        node.manager = self;
        node.channel = i;
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = renderCallback;
        callbackStruct.inputProcRefCon = node;      
        //コールバック関数の設定
        AUGraphSetNodeInputCallback(auGraph_,
                                    multiChannelMixerNode, 
                                    i, //バスナンバー
                                    &callbackStruct);
    }
    
    AudioUnit remoteIOAudioUnit;
    AUGraphNodeInfo(auGraph_, remoteIONode, 
                    NULL, &remoteIOAudioUnit);
    
    AUGraphNodeInfo(auGraph_, multiChannelMixerNode,
                    NULL, &multiChannelMixerAudioUnit_);

    //Audio Unit正準形
	AudioStreamBasicDescription audioFormat = AUCanonicalASBD(44100.0, 2);
    
    //それぞれのAudio UnitにASBDを設定する
    AudioUnitSetProperty(remoteIOAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &audioFormat,
                         sizeof(audioFormat));
    
    AudioUnitSetProperty(multiChannelMixerAudioUnit_,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &audioFormat,
                         sizeof(audioFormat));
    
    //multiChannelMixerNode(バス:0)からremoteIONode(バス:0)に繫ぐ
    AUGraphConnectNodeInput(auGraph_, 
                            multiChannelMixerNode, //このノードの
                            0,//このバス(output)から
                            remoteIONode, //このノードの
                            0 //このバス(input)に接続する
                            );
    
    //準備が整ったらAUGraphを初期化
    AUGraphInitialize(auGraph_);
}

- (void)unload {
    if(isPlaying_)[self stop];
    AUGraphUninitialize(auGraph_);
    AUGraphClose(auGraph_);
    DisposeAUGraph(auGraph_);
    auGraph_ = NULL;
    multiChannelMixerAudioUnit_ = NULL;
}

#pragma mark -
-(void)play {
    if(!isPlaying_){
        AUGraphStart(auGraph_);
    }
    isPlaying_ = YES;
}

-(void)stop {
    if(isPlaying_)AUGraphStop(auGraph_);
    isPlaying_ = NO;
}

- (Float32)volume {
    Float32 volume;
    AudioUnitGetParameter(multiChannelMixerAudioUnit_,
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
    AudioUnitSetParameter(multiChannelMixerAudioUnit_,
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
