//
//  KSAUGraphManager.h
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "iPhoneCoreAudio.h"

// 次の再生タイミングの情報を返すときの構造体
typedef struct {
    Float32 interval;
    int channel;
} KSAUGraphNextTriggerInfo;

@class KSAUGraphManager;
@protocol KSAUGraphManagerDelegate<NSObject>
@required
// 次の再生までのインターバルを秒で返すこと
- (KSAUGraphNextTriggerInfo)nextTriggerInfo:(KSAUGraphManager *)audioManager;
@end

@interface KSAUGraphManager : NSObject {
    BOOL isPlaying_;
    AUGraph auGraph_;
    AudioUnit multiChannelMixerAudioUnit_;

    NSArray *channels_;

    NSMutableArray *triggers_;
    id<KSAUGraphManagerDelegate> delegate_;
}
@property (assign, nonatomic)Float32 volume;
@property (assign, nonatomic)id<KSAUGraphManagerDelegate> delegate;

// シングルトンオブジェクトの取得
+ (id)sharedInstance;

// オーディオ出力の準備
// arrayには各チャネルを定義したクラスを入れておく（最大８個）
- (void)prepareWithChannels:(NSArray *)array;

// 動作開始/停止
-(void)play;
-(void)stop;

// 全体のボリュームを設定・取得(0.0〜1.0)
- (void)setVolume:(Float32)volume;
- (Float32)volume;
@end
