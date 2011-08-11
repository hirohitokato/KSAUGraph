//
//  KSAUGraphNode.h
//  KSAUGraph
//
//  Created by 加藤寛人 on 11/07/27.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "iPhoneCoreAudio.h"

@class KSAUGraphManager;
@class KSAUSound;

@interface KSAUGraphNode : NSObject {
    // AUGraphにおけるパラメータ
    int channel_;               // 接続先のチャネル（バス）番号

    // 再生中のパラメータ
    BOOL isPlaying_;            // 現在再生中かどうか
    UInt64 cumulativeFrames_;   // 全体の再生開始を0とした累積のフレーム数
    UInt64 currentPos_;         // 現在の再生位置

    UInt64 nextTriggerFrame_;   // 次の区切りとなる位置
    int nextChannel_;           // 次の区切りで再生するチャネル

    // サウンドデータ
    KSAUSound *sound_;
}

// KSAUGraphの中での、自分のチャネル番号
@property (assign, nonatomic)int channel;
// サウンドデータ
@property (retain, nonatomic)KSAUSound *sound;

// 全体で再生開始したときの0を起点とする累積フレーム数
@property (assign, nonatomic)UInt64 cumulativeFrames;
// 現在の再生位置
@property (assign, nonatomic)UInt64 currentFrame;
// 現在再生中かどうか
@property (assign, nonatomic)BOOL isPlaying;
// 次の区切り位置
@property (assign, nonatomic)UInt64 nextTriggerFrame;
// 次の区切りで再生するチャネル
@property (assign, nonatomic)int nextChannel;

// データフィル用コールバック関数（インプリ側の処理）
- (UInt32)renderCallbackWithFlags:(AudioUnitRenderActionFlags *)ioActionFlags
                        timeStamp:(const AudioTimeStamp *)inTimeStamp
                        busNumber:(UInt32)inBusNumber
                   inNumberFrames:(UInt32)inNumberFrames
                          outLeft:(AudioUnitSampleType *)outL
                         outRight:(AudioUnitSampleType *)outR;

// 内部値のリセット
- (void)reset;

// 再生の準備
- (void)preparePlay;

@end
