//
//  KSAUGraphManager.m
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "KSAUGraphManager.h"
#import "KSAUGraphNode.h"

// オーディオ再生タイミングを扱うプライベートクラス
@interface ksauIntervalInfo : NSObject {
@private
    UInt64  nextTriggerFrame_;  // 再生開始するタイミング（フレーム）
    int     channel_;   // 再生開始するチャネル
    int     count_;     // 参照された回数
}
@property (nonatomic, assign)UInt64 nextTriggerFrame;
@property (nonatomic, assign)int channel;
@property (nonatomic, assign)int count;
@end

@implementation ksauIntervalInfo
@synthesize nextTriggerFrame=nextTriggerFrame_, channel=channel_, count=count_;
- (id)init {
    self = [super init];
    if (self) {
        nextTriggerFrame_ = 0;
        channel_ = -1;
        count_ = 0;
    }
    return self;
}
@end

#pragma mark -
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

static id _instance = nil;
static BOOL _willDelete = NO;

- (id)init {
    self = [super init];
    if (self) {
        isPlaying_ = NO;
        auGraph_ = NULL;
        multiChannelMixerAudioUnit_ = NULL;
        delegate_ = nil;

        triggers_ = [[NSMutableArray alloc] init];
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

    UInt64 targetFrame = node.nextTriggerFrame;
    int    targetChannel = node.nextChannel;
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
            if (node.channel == node.nextChannel) {
                // 次から再生
                [node preparePlay];
            }
            // その次のトリガーフレームを取得
            UInt64 nextTriggerFrame;
            [manager nextTriggerFrame:&nextTriggerFrame
                              channel:&targetChannel
                         currentFrame:targetFrame];
            node.nextTriggerFrame = targetFrame = nextTriggerFrame;
            node.nextChannel = targetChannel;
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

    // 現在の情報と、取得できるなら次の情報を取得
    ksauIntervalInfo *now=nil, *next=nil;
    int numTriggers = [triggers_ count];
    for (int index=0; index<numTriggers; index++) {
        ksauIntervalInfo *obj = [triggers_ objectAtIndex:index];
        if (obj.nextTriggerFrame == currentFrame) {
            now = obj;
            if (index<(numTriggers-1)) {
                next = [triggers_ objectAtIndex:index+1];
            }
            break;
        }
    }
    
    if (!now) {
        NSLog(@"ERROR: current frame(%llu) is not triggerFrame!!", currentFrame);
        exit(1);
    }

    // 次の情報が未取得であれば、問い合わせる
    if (!next) {
        if (delegate_) {
            KSAUGraphNextTriggerInfo info = [delegate_ nextTriggerInfo:self];
            next = [[ksauIntervalInfo alloc] init];
            next.nextTriggerFrame = info.interval*44100 + currentFrame;
            next.channel = info.channel;
            [triggers_ addObject:next];
            [next release];
        } else {
            NSLog(@"ERROR: delegate is nil!");
            exit(1);
        }
    }
    // 全バスが情報を取得していたら、該当する情報を配列から除外
    if (++now.count == [channels_ count]) {
        [triggers_ removeObject:now];
    }
    // 情報を返す
    *nextFrame = next.nextTriggerFrame;
    *nextChannel = next.channel;
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
    channels_ = [array retain];

    OSStatus err;

    AudioSessionSetFrameBufferSize(44100.0, 1024);
    //AUGraphをインスタンス化
    err = NewAUGraph(&auGraph_); KSAUCheckError(err, "NewAUGraph");
	err = AUGraphOpen(auGraph_); KSAUCheckError(err, "AUGraphOpen");

    //Remote IOのAudioComponentDescriptionを用意する
    AudioComponentDescription cd;
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_RemoteIO;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    
    //AUGraphにRemote IOのノードを追加する
    AUNode remoteIONode;
    err = AUGraphAddNode(auGraph_, &cd, &remoteIONode);
    KSAUCheckError(err, "AUGraphAddNode(remoteIONode)");
    
    //MultiChannelMixerのAudioComponentDescriptionを用意する
    cd.componentType = kAudioUnitType_Mixer;
    cd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    
    //AUGraphにMultiChannelMixerのノードを追加する
    AUNode multiChannelMixerNode;
    AUGraphAddNode(auGraph_, &cd, &multiChannelMixerNode);
    KSAUCheckError(err, "AUGraphAddNode(multiChannelMixerNode)");
    
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
        err = AUGraphSetNodeInputCallback(auGraph_, 
                                          // ミキサーノードのi番目のバスナンバー
                                          multiChannelMixerNode, i,
                                          &callbackStruct);
        KSAUCheckError(err, "AUGraphSetNodeInputCallback");
    }
    
    AudioUnit remoteIOAudioUnit;
    err = AUGraphNodeInfo(auGraph_, remoteIONode, 
                          NULL, &remoteIOAudioUnit);
    KSAUCheckError(err, "AUGraphNodeInfo(&remoteIOAudioUnit)");
    
    err = AUGraphNodeInfo(auGraph_, multiChannelMixerNode,
                          NULL, &multiChannelMixerAudioUnit_);
    KSAUCheckError(err, "AUGraphNodeInfo(&multiChannelMixerAudioUnit_)");

    //それぞれのAudio UnitにASBD(Audio Unit正準形)を設定する
	AudioStreamBasicDescription audioFormat = AUCanonicalASBD(44100.0, 2);
    err = AudioUnitSetProperty(remoteIOAudioUnit,
                               kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                               &audioFormat, sizeof(audioFormat));
    KSAUCheckError(err, "AudioUnitSetProperty(remoteIOAudioUnit)");
    err = AudioUnitSetProperty(multiChannelMixerAudioUnit_,
                               kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                               &audioFormat, sizeof(audioFormat));
    KSAUCheckError(err, "AudioUnitSetProperty(multiChannelMixerAudioUnit_)");
    
    //multiChannelMixerNode(バス:0)からremoteIONode(バス:0)に繫ぐ
    err = AUGraphConnectNodeInput(auGraph_, 
                                  // このノードのこのバス(output)から
                                  multiChannelMixerNode, 0,
                                  // このノードのこのバス(input)に接続する
                                  remoteIONode, 0);
    KSAUCheckError(err, "AUGraphConnectNodeInput(auGraph_)");

    //準備が整ったらAUGraphを初期化
    err = AUGraphInitialize(auGraph_);
    KSAUCheckError(err, "AUGraphInitialize(auGraph_)");    
}

- (void)unload {
    if(isPlaying_)[self stop];
    AUGraphUninitialize(auGraph_);
    AUGraphClose(auGraph_);
    DisposeAUGraph(auGraph_);
    auGraph_ = NULL;
    multiChannelMixerAudioUnit_ = NULL;
    [channels_ release]; channels_ = nil;
    [triggers_ release]; triggers_ = nil;
}

#pragma mark -
-(void)play {
    if(!isPlaying_){
        for (KSAUGraphNode *node in channels_) {
            [node reset];
        }
        // 初期値を代入しておく
        ksauIntervalInfo *i = [[[ksauIntervalInfo alloc] init] autorelease];
        [triggers_ addObject:i];

        OSStatus err = AUGraphStart(auGraph_);
        KSAUCheckError(err, "AUGraphStart(auGraph_)");
    } else {
        NSLog(@"Warning: play method is called though now is playing.");
    }
    isPlaying_ = YES;
}

-(void)stop {
    if(isPlaying_) {
        AUGraphStop(auGraph_);
        [triggers_ removeAllObjects];
    } else {
        NSLog(@"Warning: stop method is called though now is not playing.");
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
