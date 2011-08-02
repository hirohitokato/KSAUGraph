//
//  KSAUGraphViewController.m
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/26.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "KSAUGraphViewController.h"
#import "KSAUGraph.h"
#import "KSAUGraphNode.h"

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
    NSString *path = [[NSBundle mainBundle] pathForResource:@"analog_rest" ofType:@"caf"];
	NSURL *fileURL = [NSURL fileURLWithPath:path];
    KSAUGraphNode *node0 = [[[KSAUGraphNode alloc] initWithContentsOfURL:fileURL] autorelease];
    path = [[NSBundle mainBundle] pathForResource:@"real_tock" ofType:@"caf"];
	fileURL = [NSURL fileURLWithPath:path];
    KSAUGraphNode *node1 = [[[KSAUGraphNode alloc] initWithContentsOfURL:fileURL] autorelease];

    [mgr prepareWithChannels:[NSArray arrayWithObjects:node0, node1, nil]];

    minValueLabel.text = [NSString stringWithFormat:@"%2.0f", intervalSlider.minimumValue];
    maxValueLabel.text = [NSString stringWithFormat:@"%2.0f", intervalSlider.maximumValue];
    currentValueLabel.text = [NSString stringWithFormat:@"%2.2f", intervalSlider.value];
    volumeSlider.value = mgr.volume;
    [self getStatus:nil];

    // 割り込み用コールバックの設定
	UInt32 category = kAudioSessionCategory_MediaPlayback;
	OSStatus result = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
	if (result) printf("Error setting audio session category! %d\n", (int)result);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(dedReceiveNotification:) name:kKSAUAudioDidBeginInterruptionNotification object:nil];
}

- (void)viewDidUnload
{
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
}

- (void)didReceiveNotification:(NSNotification *)aNotification {
    NSLog(@"Receive a notification[%@]", [aNotification name]);
    [self getStatus:nil];
}
@end
