//
//  KSAUGraph.h
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

#import "KSAUGraphNode.h"
#import "KSAUSound.h"

#import "iPhoneCoreAudio.h"

@class KSAUGraphNode;
@protocol KSAUGraphManagerDelegate;

@interface KSAUGraphManager : NSObject {
    BOOL isPlaying_;
    AUGraph auGraph_;
    AudioUnit multiChannelMixerAudioUnit_;

    NSInteger numChannels_;
    NSMutableArray *channels_;

    NSMutableArray *triggers_;
    id<KSAUGraphManagerDelegate> delegate_;
}
@property (assign, nonatomic)Float32 volume;
@property (assign, nonatomic)id<KSAUGraphManagerDelegate> delegate;
@property (readonly, nonatomic)NSArray *channels;

#pragma mark 外部API
// シングルトンオブジェクトの取得
+ (id)sharedInstance;

// オーディオ出力の準備（初期化処理）
// 指定した個数のチャネルを作成する
- (void)prepareChannel:(NSInteger)numChannels;

-(void)start;   // 動作開始
-(void)stop;    // 動作停止

- (void)setVolume:(Float32)volume;  // 全体のボリュームを設定(0.0〜1.0)
- (Float32)volume;                  // 全体のボリュームを取得(0.0〜1.0)

// BPMをインターバル(秒)に変換するユーティリティメソッド
- (Float32)intervalForBpm:(Float32)bpm;

// 現在状態の取得（デバッグ）
- (int)isRunning:(Boolean *)isRunning isInitialized:(Boolean *)isInitialized isOpened:(Boolean *)isOpened;
@end

// オーディオが割り込まれたときに呼ばれる通知
#define kKSAUAudioDidBeginInterruptionNotification @"KSAUAudioDidBeginInterruption"
#define kKSAUAudioDidEndInterruptionNotification @"KSAUAudioDidEndInterruption"

// 次の再生タイミングの情報を返すときの構造体
typedef struct {
    Float32 interval;
    int channel;
} KSAUGraphNextTriggerInfo;

@protocol KSAUGraphManagerDelegate<NSObject>
@required
// 次の再生までのインターバルを秒で返すためのデリゲートメソッド
- (KSAUGraphNextTriggerInfo)nextTriggerInfo:(KSAUGraphManager *)audioManager;
@end

// KSAUGraphのバージョンを返す関数
NSString *KSAUGraphVersion();
