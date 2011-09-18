//
//  KSAUGraphViewController.h
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KSAUGraph.h"

@interface KSAUGraphViewController : UIViewController <KSAUGraphManagerDelegate>{
    NSMutableArray *soundA;
    NSMutableArray *soundB;
    NSMutableArray *soundC;

    IBOutlet UILabel *minValueLabel;
    IBOutlet UILabel *maxValueLabel;
    IBOutlet UILabel *currentValueLabel;
    IBOutlet UISlider *intervalSlider;
    IBOutlet UILabel *isRunningLabel;
    IBOutlet UILabel *isInitializedLabel;
    IBOutlet UILabel *isOpenedLabel;
    IBOutlet UILabel *returnCodeLabel;
    IBOutlet UISlider *volumeSlider;
    IBOutlet UISegmentedControl *soundType;
}
- (IBAction)play:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)intervalChanged:(id)sender;
- (IBAction)getStatus:(id)sender;
- (IBAction)volumeChanged:(UISlider *)sender;
- (IBAction)selectedSound:(id)sender;

- (void)didReceiveNotification:(NSNotification *)aNotification;
@end
