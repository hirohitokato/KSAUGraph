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
// 次のトリガーフレームを取得
- (void)nextTriggerFrame:(UInt64 *)nextFrame
                 channel:(int*)nextChannel
            currentFrame:(UInt64)currentFrame;
@end

@implementation KSAUGraphManager
@synthesize delegate=delegate_;
@synthesize currentChannel=currentChannel_,currentTriggerFrame=currentTriggerFrame_;
@synthesize nextChannel=nextChannel_,nextTriggerFrame=nextTriggerFrame_;

static id _instance = nil;
static BOOL _willDelete = NO;

- (id)init {
    self = [super init];
    if (self) {
        isPlaying_ = NO;
        auGraph_ = NULL;
        multiChannelMixerAudioUnit_ = NULL;
        delegate_ = nil;

        currentTriggerFrame_ = 0;
        currentChannel_ = -1;
        nextTriggerFrame_ = 0;
        nextChannel_ = -1;
        count_ = 0;
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

    AudioUnitSampleType *outL = ioData->mBuffers[0].mData;
    AudioUnitSampleType *outR = ioData->mBuffers[1].mData;

    UInt64 targetFrame = manager.currentTriggerFrame;
    UInt32 bufferRemains = inNumberFrames;

    do {
        // フィルする単位を決定（inNumberFramesすべてか、次のトリガーフレームまでか）
        UInt32 nextFrame = MIN(targetFrame-node.cumulativeFrames, bufferRemains);

        // nextFrameまでフィルしてもらう
        [node renderCallbackWithFlags:ioActionFlags
                            timeStamp:inTimeStamp
                            busNumber:inBusNumber
                       inNumberFrames:nextFrame
                              outLeft:outL
                             outRight:outR];
        //フィルした量で残りの書き込む量と、書き込み位置(L/R)を更新
        bufferRemains -= nextFrame;
        outL += nextFrame;
        outR += nextFrame;

        // 次のトリガーフレームに到達？
        if (targetFrame == node.cumulativeFrames) {
            if (node.channel == manager.currentChannel) {
                // 次から再生
                [node preparePlay];
            }
            // その次のトリガーフレームを取得
            UInt64 nextTriggerFrame;
            int nextChannel;
            [manager nextTriggerFrame:&nextTriggerFrame
                              channel:&nextChannel
                         currentFrame:targetFrame];
            node.nextTriggerFrame = targetFrame = nextTriggerFrame;
        } else if (targetFrame < node.cumulativeFrames) {
            // これはおかしい
            NSLog(@"targetFrame(%llu) < node.cumulativeFrames(%llu)",targetFrame,node.cumulativeFrames);
            exit(1);
        }
    } while(bufferRemains > 0);

    return noErr;
}

- (void)nextTriggerFrame:(UInt64 *)nextFrame
                 channel:(int*)nextChannel
            currentFrame:(UInt64)currentFrame {
    if (currentFrame != currentTriggerFrame_) {
        NSLog(@"ERROR: current(%llu) is not triggerFrame(%llu)!!", currentFrame, currentTriggerFrame_);
        exit(1);
    }
    // else NSLog(@"current(%llu) is OK.", currentFrame);

    count_++;
    // 次の情報が未取得であれば、問い合わせる
    if (currentTriggerFrame_ == nextTriggerFrame_) {
        if (delegate_) {
            KSAUGraphNextTriggerInfo info = [delegate_ nextTriggerInfo:self];
            nextTriggerFrame_ = info.interval*44100 + currentFrame;
            nextChannel_ = info.channel;
        } else {
            NSLog(@"ERROR: delegate is nil!");
            exit(1);
        }
    }
    // 全バスが情報を取得できたら、次へ
    if (count_==[channels_ count]) {
        count_ = 0;
        currentChannel_ = nextChannel_;
        currentTriggerFrame_ = nextTriggerFrame_;
    }
    // 情報を返す
    *nextChannel = nextChannel_;
    *nextFrame = nextTriggerFrame_;
    return;
}

- (void)prepareWithChannels:(NSArray *)array {
    // 8チャンネル以下であること
    if ([array count] > 8) {
        NSLog(@"Array count(%d) must be within 8.", [array count]);
        return;
    }
    if (delegate_==nil) {
        NSLog(@"Delegate property must not be nil.");
        return;
    }
    AudioSessionSetFrameBufferSize(44010.0f, 2048);
    channels_ = [array retain];

    //AUGraphをインスタンス化
    NewAUGraph(&auGraph_);
	AUGraphOpen(auGraph_);
    AudioSessionSetFrameBufferSize(44010.0f, 2048);

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
        // ミキサーの各バスにコールバック関数を設定
        AUGraphSetNodeInputCallback(auGraph_, 
                                    multiChannelMixerNode, i, // ミキサーノードのi番目のバスナンバー
                                    &callbackStruct);
    }
    
    AudioUnit remoteIOAudioUnit;
    AUGraphNodeInfo(auGraph_, remoteIONode, 
                    NULL, &remoteIOAudioUnit);
    
    AUGraphNodeInfo(auGraph_, multiChannelMixerNode,
                    NULL, &multiChannelMixerAudioUnit_);

    //それぞれのAudio UnitにASBD(Audio Unit正準形)を設定する
	AudioStreamBasicDescription audioFormat = AUCanonicalASBD(44100.0, 2);
    AudioUnitSetProperty(remoteIOAudioUnit,
                         kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                         &audioFormat, sizeof(audioFormat));
    AudioUnitSetProperty(multiChannelMixerAudioUnit_,
                         kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                         &audioFormat, sizeof(audioFormat));
    
    //multiChannelMixerNode(バス:0)からremoteIONode(バス:0)に繫ぐ
    AUGraphConnectNodeInput(auGraph_, 
                            multiChannelMixerNode, 0,   // このノードのこのバス(output)から
                            remoteIONode, 0);           // このノードのこのバス(input)に接続する
    
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
    [channels_ release]; channels_ = nil;
}

#pragma mark -
-(void)play {
    if(!isPlaying_){
        for (KSAUGraphNode *node in channels_) {
            node.currentFrame = 0;
            node.cumulativeFrames = 0;
            node.isPlaying = YES;

            currentTriggerFrame_ = 0;
            currentChannel_ = -1;
            nextTriggerFrame_ = 0;
            nextChannel_ = -1;
            count_ = 0;
        }
        AUGraphStart(auGraph_);
    } else {
        NSLog(@"Warning: play method is called though now is playing.");
    }
    isPlaying_ = YES;
}

-(void)stop {
    if(isPlaying_) {
        AUGraphStop(auGraph_);
    }
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
                          0, // バスナンバー
                          v, // ボリューム
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
