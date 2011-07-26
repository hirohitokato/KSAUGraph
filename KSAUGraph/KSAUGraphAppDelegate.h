//
//  KSAUGraphAppDelegate.h
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KSAUGraphViewController;

@interface KSAUGraphAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet KSAUGraphViewController *viewController;

@end
