//
//  KSAUGraphViewController.m
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "KSAUGraphViewController.h"
#import "KSAUGraph.h"

@implementation KSAUGraphViewController

- (void)dealloc
{
    [maxValueLabel release];
    [minValueLabel release];
    [intervalSlider release];
    [currentValueLabel release];
    [isRunningLabel release];
    [isInitializedLabel release];
    [isOpenedLabel release];
    [returnCodeLabel release];
    [volumeSlider release];
    [soundType release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    KSAUGraphManager *mgr = [KSAUGraphManager sharedInstance];
    mgr.delegate = self;
    [mgr prepareChannel:2];

    soundA = [[NSMutableArray alloc] initWithCapacity:2];
    soundB = [[NSMutableArray alloc] initWithCapacity:2];
    soundC = [[NSMutableArray alloc] initWithCapacity:2];
    NSString *filenamesA[] = {@"analog_rest", @"real_tock"};
    NSString *filenamesB[] = {@"click_tick_high", @"click_tock_low"};
    for (int i=0; i<2; i++) {
        // sound A
        NSString *path = [[NSBundle mainBundle] pathForResource:filenamesA[i] ofType:@"caf"];
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        KSAUSound *sound = [KSAUSoundFile soundWithContentsOfURL:fileURL];
        [soundA addObject:sound];
        // sound B
        path = [[NSBundle mainBundle] pathForResource:filenamesB[i] ofType:@"caf"];
        fileURL = [NSURL fileURLWithPath:path];
        sound = [KSAUSoundFile soundWithContentsOfURL:fileURL];
        [soundB addObject:sound];
        // sound C
        sound = [KSAUSoundMute muteSound];
        [soundC addObject:sound];
    }
    soundType.selectedSegmentIndex = 0;
    [self selectedSound:soundType];

    minValueLabel.text = [NSString stringWithFormat:@"%2.0f", intervalSlider.minimumValue];
    maxValueLabel.text = [NSString stringWithFormat:@"%2.0f", intervalSlider.maximumValue];
    currentValueLabel.text = [NSString stringWithFormat:@"%2.2f", intervalSlider.value];
    volumeSlider.value = mgr.volume;
    [self getStatus:nil];

    KSAudioSessionSetCategory(kAudioSessionCategory_MediaPlayback);

    // 割り込み用コールバックの設定
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(didReceiveNotification:) name:kKSAUAudioDidBeginInterruptionNotification object:nil];
    [center addObserver:self selector:@selector(didReceiveNotification:) name:kKSAUAudioDidBeginPlayingNotification object:nil];
    [center addObserver:self selector:@selector(didReceiveNotification:) name:kKSAUAudioDidEndPlayingNotification object:nil];
}

- (void)viewDidUnload
{
    [soundA release];
    [soundB release];

    [maxValueLabel release];
    maxValueLabel = nil;
    [minValueLabel release];
    minValueLabel = nil;
    [intervalSlider release];
    intervalSlider = nil;
    [currentValueLabel release];
    currentValueLabel = nil;
    [isRunningLabel release];
    isRunningLabel = nil;
    [isInitializedLabel release];
    isInitializedLabel = nil;
    [isOpenedLabel release];
    isOpenedLabel = nil;
    [returnCodeLabel release];
    returnCodeLabel = nil;
    [volumeSlider release];
    volumeSlider = nil;
    [soundType release];
    soundType = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (KSAUGraphNextTriggerInfo)nextTriggerInfo:(KSAUGraphManager *)audioManager {
    static int nextChannel = 1;
    nextChannel = (nextChannel==1)?0:1;
    KSAUGraphNextTriggerInfo info;
    info.channel = nextChannel;
    info.interval = [audioManager intervalForBpm:[intervalSlider value]];

    return info;
}

#pragma mark - Actions
- (IBAction)play:(id)sender {
    KSAUGraphManager *mgr = [KSAUGraphManager sharedInstance];
    NSLog(@"Start playing.");
    [mgr start];
}

- (IBAction)stop:(id)sender {
    KSAUGraphManager *mgr = [KSAUGraphManager sharedInstance];
    NSLog(@"Stop playing.");
    [mgr stop];
}

- (IBAction)intervalChanged:(id)sender {
    currentValueLabel.text = [NSString stringWithFormat:@"%2.2f", intervalSlider.value];
}

- (IBAction)getStatus:(id)sender {
    Boolean isRunning, isInitialized, isOpened;
    KSAUGraphManager *mgr = [KSAUGraphManager sharedInstance];
    int ret = [mgr isRunning:&isRunning isInitialized:&isInitialized isOpened:&isOpened];
    isRunningLabel.text = [NSString stringWithFormat:@"%@", isRunning?@"YES":@"NO"];
    isInitializedLabel.text = [NSString stringWithFormat:@"%@", isInitialized?@"YES":@"NO"];
    isOpenedLabel.text = [NSString stringWithFormat:@"%@", isOpened?@"YES":@"NO"];
    returnCodeLabel.text = [NSString stringWithFormat:@"%d", ret];
}

- (IBAction)volumeChanged:(UISlider *)sender {
    KSAUGraphManager *mgr = [KSAUGraphManager sharedInstance];
    [mgr setVolume:[sender value]];
    NSLog(@"Volume : %f", mgr.volume);
}

- (void)setSound:(NSUInteger)type {
    NSMutableArray *array = nil;
    switch (type) {
        case 0:
            array = soundA;
            break;
        case 1:
            array = soundB;
            break;
        case 2:
            array = soundC;
            break;
        default:
            break;
    }
    KSAUGraphManager *mgr = [KSAUGraphManager sharedInstance];
    for (int i=0; i<mgr.channels.count; i++) {
        KSAUGraphNode *node = [mgr.channels objectAtIndex:i];
        node.sound = [array objectAtIndex:i];
    }
}
- (IBAction)selectedSound:(UISegmentedControl *)sender {
    [self setSound:sender.selectedSegmentIndex];
}

- (void)didReceiveNotification:(NSNotification *)aNotification {
    NSLog(@"Receive a notification[%@]", aNotification);
    [self getStatus:nil];
}
@end
