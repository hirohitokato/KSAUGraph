//
//  ksauIntervalInfo.h
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/30.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <Foundation/Foundation.h>

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
