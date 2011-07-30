//
//  KSAUGraphViewController.h
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KSAUGraphManager.h"

@interface KSAUGraphViewController : UIViewController <KSAUGraphManagerDelegate>{
    
    IBOutlet UILabel *minValueLabel;
    IBOutlet UILabel *maxValueLabel;
    IBOutlet UILabel *currentValueLabel;
    IBOutlet UISlider *intervalSlider;
}
- (IBAction)play:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)intervalChanged:(id)sender;

@end
