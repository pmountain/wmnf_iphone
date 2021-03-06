//
//  iPhoneStreamingPlayerViewController.m
//  iPhoneStreamingPlayer
//
//  Created by Matt Gallagher on 28/10/08.
//  Copyright Matt Gallagher 2008. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "AppDelegate.h"
#import "NowPlayingViewController.h"
#import "AudioStreamer.h"
#import "LevelMeterView.h"
#import <QuartzCore/CoreAnimation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CFNetwork/CFNetwork.h>

NSString * const HD1_HIGH_QUALITY = @"http://stream.wmnf.org:8000/wmnf_high_quality";
NSString * const HD2 = @"http://131.247.176.1:8000/stream";
NSString * const HD3 = @"http://stream.wmnf.org:8000/wmnf_hd3";
NSString * const HD4 = @"http://stream.wmnf.org:8000/wmnf_hd4";

@implementation NowPlayingViewController

@synthesize currentArtist, currentTitle, channelList, currentChannel;



- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"NowPlaying", @"NowPlaying");
        self.tabBarItem.image = [UIImage imageNamed:@"194-note-2"];
    }
    return self;
}

//
// setButtonImage:
//
// Used to change the image on the playbutton. This method exists for
// the purpose of inter-thread invocation because
// the observeValueForKeyPath:ofObject:change:context: method is invoked
// from secondary threads and UI updates are only permitted on the main thread.
//
// Parameters:
//    image - the image to set on the play button.
//
- (void)setButtonImage:(UIImage *)image
{
	[button.layer removeAllAnimations];
	if (!image)
	{
		[button setImage:[UIImage imageNamed:@"playbutton.png"] forState:0];
	}
	else
	{
		[button setImage:image forState:0];
        
		if ([button.currentImage isEqual:[UIImage imageNamed:@"loadingbutton.png"]])
		{
			[self spinButton];
		}
	}
}

//
// destroyStreamer
//
// Removes the streamer, the UI update timer and the change notification
//
- (void)destroyStreamer
{
	if (streamer)
	{
		[[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:ASStatusChangedNotification
         object:streamer];
		[self createTimers:NO];
		
		[streamer stop];
		[streamer release];
		streamer = nil;
	}
}

//
// forceUIUpdate
//
// When foregrounded force UI update since we didn't update in the background
//
-(void)forceUIUpdate {
	if (currentArtist)
		metadataArtist.text = currentArtist;
	if (currentTitle)
		metadataTitle.text = currentTitle;
    
	if (!streamer) {
		[levelMeterView updateMeterWithLeftValue:0.0 
									  rightValue:0.0];
		[self setButtonImage:[UIImage imageNamed:@"playbutton.png"]];
	}
	else 
		[self playbackStateChanged:NULL];
}

//
// createTimers
//
// Creates or destoys the timers
//
-(void)createTimers:(BOOL)create {
	if (create) {
		if (streamer) {
            [self createTimers:NO];
            progressUpdateTimer =
            [NSTimer
             scheduledTimerWithTimeInterval:0.1
             target:self
             selector:@selector(updateProgress:)
             userInfo:nil
             repeats:YES];
            levelMeterUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:.1 
                                                                     target:self 
                                                                   selector:@selector(updateLevelMeters:) 
                                                                   userInfo:nil 
                                                                    repeats:YES];
		}
	}
	else {
		if (progressUpdateTimer)
		{
			[progressUpdateTimer invalidate];
			progressUpdateTimer = nil;
		}
		if(levelMeterUpdateTimer) {
			[levelMeterUpdateTimer invalidate];
			levelMeterUpdateTimer = nil;
		}
	}
}

//
// createStreamer
//
// Creates or recreates the AudioStreamer object.
//
- (void)createStreamer:(NSString *)urlString
{
    NSLog(@">>> Entering %s <<<", __PRETTY_FUNCTION__);
    self.channelList = [[NSArray alloc] initWithObjects:@"http://stream.wmnf.org:8000/wmnf_high_quality",@"http://131.247.176.1:8000/stream",@"http://stream.wmnf.org:8000/wmnf_hd3",@"http://stream.wmnf.org:8000/wmnf_hd4", nil];

	if (streamer)
	{
		return;
	}
    NSLog(@"1");
    NSLog(@"nowplaing controller id:%@", self);
	[self destroyStreamer];
    NSLog(@"2");
	
//	NSString *escapedValue =
//    [(NSString *)CFURLCreateStringByAddingPercentEscapes(
//                                                         nil,
//                                                         (CFStringRef)downloadSourceField.text,
//                                                         NULL,
//                                                         NULL,
//                                                         kCFStringEncodingUTF8)
//     autorelease];
    NSLog(@"3");
    NSLog(@"channel list = %@", self.channelList);
    NSLog(@"channel index = %@", self.currentChannel);
    //NSString *urlString = [self.channelList objectAtIndex:[self.currentChannel intValue]];
    NSLog(@"url string = %@", urlString);
    NSLog(@"4");
    NSString *escapedValue =
    [(NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                         nil,
                                                         (CFStringRef)urlString,
                                                         NULL,
                                                         NULL,
                                                         kCFStringEncodingUTF8)
     autorelease];

    NSLog(@"5");

	NSURL *url = [NSURL URLWithString:escapedValue];
	streamer = [[AudioStreamer alloc] initWithURL:url];
	
	[self createTimers:YES];
    NSLog(@"6 ");

	[[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(playbackStateChanged:)
     name:ASStatusChangedNotification
     object:streamer];
#ifdef SHOUTCAST_METADATA
	[[NSNotificationCenter defaultCenter]
	 addObserver:self
	 selector:@selector(metadataChanged:)
	 name:ASUpdateMetadataNotification
	 object:streamer];
#endif
    NSLog(@">>> Leaving %s <<<", __PRETTY_FUNCTION__);
}

//
// viewDidLoad
//
// Creates the volume slider, sets the default path for the local file and
// creates the streamer immediately if we already have a file at the local
// location.
//
- (void)viewDidLoad
{
	[super viewDidLoad];
    
    self.channelList = [[NSArray alloc] initWithObjects:@"http://stream.wmnf.org:8000/wmnf_high_quality",@"http://131.247.176.1:8000/stream",@"http://stream.wmnf.org:8000/wmnf_hd3",@"http://stream.wmnf.org:8000/wmnf_hd4", nil];
    currentChannel = 0;
	
	MPVolumeView *volumeView = [[[MPVolumeView alloc] initWithFrame:volumeSlider.bounds] autorelease];
	[volumeSlider addSubview:volumeView];
	[volumeView sizeToFit];
	
	[self setButtonImage:[UIImage imageNamed:@"playbutton.png"]];
	
	levelMeterView = [[LevelMeterView alloc] initWithFrame:CGRectMake(10.0, 310.0, 300.0, 60.0)];
	[self.view addSubview:levelMeterView];


    NSError *setCategoryErr = nil;
    NSError *activationErr  = nil;
    [[AVAudioSession sharedInstance]
     setCategory: AVAudioSessionCategoryPlayback
     error: &setCategoryErr];
    //    [[AVAudioSessionsharedInstance]
    //     setActive: YES
    //     error: &activationErr];'



}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	UIApplication *application = [UIApplication sharedApplication];
	if([application respondsToSelector:@selector(beginReceivingRemoteControlEvents)])
		[application beginReceivingRemoteControlEvents];
	[self becomeFirstResponder]; // this enables listening for events
	// update the UI in case we were in the background
	NSNotification *notification =
	[NSNotification
	 notificationWithName:ASStatusChangedNotification
	 object:self];
	[[NSNotificationCenter defaultCenter]
	 postNotification:notification];
}

- (BOOL)canBecomeFirstResponder {
	return YES;
}

//
// spinButton
//
// Shows the spin button when the audio is loading. This is largely irrelevant
// now that the audio is loaded from a local file.
//
- (void)spinButton
{
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	CGRect frame = [button frame];
	button.layer.anchorPoint = CGPointMake(0.5, 0.5);
	button.layer.position = CGPointMake(frame.origin.x + 0.5 * frame.size.width, frame.origin.y + 0.5 * frame.size.height);
	[CATransaction commit];
    
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanFalse forKey:kCATransactionDisableActions];
	[CATransaction setValue:[NSNumber numberWithFloat:2.0] forKey:kCATransactionAnimationDuration];
    
	CABasicAnimation *animation;
	animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
	animation.fromValue = [NSNumber numberWithFloat:0.0];
	animation.toValue = [NSNumber numberWithFloat:2 * M_PI];
	animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionLinear];
	animation.delegate = self;
	[button.layer addAnimation:animation forKey:@"rotationAnimation"];
    
	[CATransaction commit];
}

//
// animationDidStop:finished:
//
// Restarts the spin animation on the button when it ends. Again, this is
// largely irrelevant now that the audio is loaded from a local file.
//
// Parameters:
//    theAnimation - the animation that rotated the button.
//    finished - is the animation finised?
//
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)finished
{
	if (finished)
	{
		[self spinButton];
	}
}

//
// buttonPressed:
//
// Handles the play/stop button. Creates, observes and starts the
// audio streamer when it is a play button. Stops the audio streamer when
// it isn't.
//
// Parameters:
//    sender - normally, the play/stop button.
//
- (IBAction)buttonPressed:(id)sender
{
	if ([button.currentImage isEqual:[UIImage imageNamed:@"playbutton.png"]] || [button.currentImage isEqual:[UIImage imageNamed:@"pausebutton.png"]])
	{
		[downloadSourceField resignFirstResponder];
		
		//[self createStreamer];
        [self createStreamer:[channelList objectAtIndex:[currentChannel intValue]]];

		[self setButtonImage:[UIImage imageNamed:@"loadingbutton.png"]];
		[streamer start];
	}
	else
	{
		[streamer stop];
	}
}

//
// sliderMoved:
//
// Invoked when the user moves the slider
//
// Parameters:
//    aSlider - the slider (assumed to be the progress slider)
//
- (IBAction)sliderMoved:(UISlider *)aSlider
{
	if (streamer.duration)
	{
		double newSeekTime = (aSlider.value / 100.0) * streamer.duration;
		[streamer seekToTime:newSeekTime];
	}
}

//
// playbackStateChanged:
//
// Invoked when the AudioStreamer
// reports that its playback status has changed.
//
- (void)playbackStateChanged:(NSNotification *)aNotification
{
	AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
	if ([streamer isWaiting])
	{
		if (appDelegate.uiIsVisible) {
			[levelMeterView updateMeterWithLeftValue:0.0 
                                          rightValue:0.0];
			[streamer setMeteringEnabled:NO];
			[self setButtonImage:[UIImage imageNamed:@"loadingbutton.png"]];
		}
	}
	else if ([streamer isPlaying])
	{
		if (appDelegate.uiIsVisible) {
			[streamer setMeteringEnabled:YES];
			[self setButtonImage:[UIImage imageNamed:@"stopbutton.png"]];
		}
	}
	else if ([streamer isPaused]) {
		if (appDelegate.uiIsVisible) {
			[levelMeterView updateMeterWithLeftValue:0.0 
                                          rightValue:0.0];
			[streamer setMeteringEnabled:NO];
			[self setButtonImage:[UIImage imageNamed:@"pausebutton.png"]];
		}
	}
	else if ([streamer isIdle])
	{
		if (appDelegate.uiIsVisible) {
			[levelMeterView updateMeterWithLeftValue:0.0 
                                          rightValue:0.0];
			[self setButtonImage:[UIImage imageNamed:@"playbutton.png"]];
		}
		[self destroyStreamer];
	}
}

#ifdef SHOUTCAST_METADATA
/** Example metadata
 * 
 StreamTitle='Kim Sozzi / Amuka / Livvi Franc - Secret Love / It's Over / Automatik',
 StreamUrl='&artist=Kim%20Sozzi%20%2F%20Amuka%20%2F%20Livvi%20Franc&title=Secret%20Love%20%2F%20It%27s%20Over%20%2F%20Automatik&album=&duration=1133453&songtype=S&overlay=no&buycd=&website=&picture=',
 
 Format is generally "Artist hypen Title" although servers may deliver only one. This code assumes 1 field is artist.
 */
- (void)metadataChanged:(NSNotification *)aNotification
{
	NSString *streamArtist;
	NSString *streamTitle;
	NSString *streamAlbum;
    //NSLog(@"Raw meta data = %@", [[aNotification userInfo] objectForKey:@"metadata"]);
    
	NSArray *metaParts = [[[aNotification userInfo] objectForKey:@"metadata"] componentsSeparatedByString:@";"];
	NSString *item;
	NSMutableDictionary *hash = [[NSMutableDictionary alloc] init];
	for (item in metaParts) {
		// split the key/value pair
		NSArray *pair = [item componentsSeparatedByString:@"="];
		// don't bother with bad metadata
		if ([pair count] == 2)
			[hash setObject:[pair objectAtIndex:1] forKey:[pair objectAtIndex:0]];
	}
    
	// do something with the StreamTitle
	NSString *streamString = [[hash objectForKey:@"StreamTitle"] stringByReplacingOccurrencesOfString:@"'" withString:@""];
	
	NSArray *streamParts = [streamString componentsSeparatedByString:@" - "];
	if ([streamParts count] > 0) {
		streamArtist = [streamParts objectAtIndex:0];
	} else {
		streamArtist = @"";
	}
	// this looks odd but not every server will have all artist hyphen title
	if ([streamParts count] >= 2) {
		streamTitle = [streamParts objectAtIndex:1];
		if ([streamParts count] >= 3) {
			streamAlbum = [streamParts objectAtIndex:2];
		} else {
			streamAlbum = @"";
		}
	} else {
		streamTitle = @"";
		streamAlbum = @"";
	}
	NSLog(@"%@ by %@ from %@", streamTitle, streamArtist, streamAlbum);
    
	// only update the UI if in foreground
	AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	if (appDelegate.uiIsVisible) {
		metadataArtist.text = streamArtist;
		metadataTitle.text = streamTitle;
		metadataAlbum.text = streamAlbum;
	}
	self.currentArtist = streamArtist;
	self.currentTitle = streamTitle;
}
#endif

//
// updateProgress:
//
// Invoked when the AudioStreamer
// reports that its playback progress has changed.
//
- (void)updateProgress:(NSTimer *)updatedTimer
{
	if (streamer.bitRate != 0.0)
	{
		double progress = streamer.progress;
		double duration = streamer.duration;
		
		if (duration > 0)
		{
			[positionLabel setText:
             [NSString stringWithFormat:@"Time Played: %.1f/%.1f seconds",
              progress,
              duration]];
			[progressSlider setEnabled:YES];
			[progressSlider setValue:100 * progress / duration];
		}
		else
		{
			[progressSlider setEnabled:NO];
		}
	}
	else
	{
		positionLabel.text = @"Time Played:";
	}
}


//
// updateLevelMeters:
//

- (void)updateLevelMeters:(NSTimer *)timer {
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	if([streamer isMeteringEnabled] && appDelegate.uiIsVisible) {
		[levelMeterView updateMeterWithLeftValue:[streamer averagePowerForChannel:0] 
									  rightValue:[streamer averagePowerForChannel:([streamer numberOfChannels] > 1 ? 1 : 0)]];
	}
}


- (void)changeChannel:(int)channelIndex {
    NSLog(@">>> Entering %s <<<", __PRETTY_FUNCTION__);
    self.channelList = [[NSArray alloc] initWithObjects:@"http://stream.wmnf.org:8000/wmnf_high_quality",@"http://131.247.176.1:8000/stream",@"http://stream.wmnf.org:8000/wmnf_hd3",@"http://stream.wmnf.org:8000/wmnf_hd4", nil];

    [streamer stop];
    [self destroyStreamer];
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    appDelegate.tabBarController.selectedIndex = 0;
	[self createStreamer:[channelList objectAtIndex:channelIndex]];
    [streamer start];
    switch (channelIndex) {
        case 0:
            callButton.hidden = NO;
            emailButton.hidden = NO;
            phoneLabel.hidden = NO;
            break;
        case 1:
            callButton.hidden = NO;
            emailButton.hidden = NO;
            phoneLabel.hidden = NO;
            break;
        case 2:
            callButton.hidden = YES;
            emailButton.hidden = NO;
            phoneLabel.hidden = NO;
            break;
        case 3:
            callButton.hidden = YES;
            emailButton.hidden = NO;
            phoneLabel.hidden = NO;
        default:
            callButton.hidden = YES;
            emailButton.hidden = NO;
            phoneLabel.hidden = NO;
            break;
    }
    self.currentChannel = [NSString stringWithFormat:@"%d", channelIndex];
    NSLog(@"<<< Leaving %s >>>", __PRETTY_FUNCTION__);

}


//
// textFieldShouldReturn:
//
// Dismiss the text field when done is pressed
//
// Parameters:
//    sender - the text field
//
// returns YES
//
- (BOOL)textFieldShouldReturn:(UITextField *)sender
{
	[sender resignFirstResponder];
	[self createStreamer];
	return YES;
}

- (IBAction)callButtonPressed:(id)sender
{
    switch ([currentChannel intValue]) {
        case 0:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tel:813-239-9663"]]; 
            break;
        case 1:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tel:813-974-9285"]]; 
            break;
        default:
            break;
    }
}

- (IBAction)emailButtonPressed:(id)sender
{
    switch ([currentChannel intValue]) {
        case 0:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:dj@wmnf.org"]]; 
            break;
        case 1:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:hd2@wmnf.org"]]; 
            break;
        case 2:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:hd3@wmnf.org"]]; 
            break;
        case 3:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:hd4@wmnf.org"]]; 
            break;
        default:
            break;
    }
   [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:dj@wmnf.org"]]; 
}


//********** SCREEN TOUCHED **********
// - (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
// {
//     //See if touch was inside the label
//     if (CGRectContainsPoint(phoneLabel.frame, [[[event allTouches] anyObject] locationInView:mainView])) {
//         //Open webpage
//         //[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.google.com"]];
//         [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tel:813-239-9663"]];
//     }
// }

//
// dealloc
//
// Releases instance memory.
//
- (void)dealloc
{
	[self destroyStreamer];
	[self createTimers:NO];
	[levelMeterView release];
    [channelList release], channelList = nil;
    [phoneLabel release];
    [mainView release];
	[super dealloc];
}

#pragma mark Remote Control Events
/* The iPod controls will send these events when the app is in the background */
- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
	switch (event.subtype) {
		case UIEventSubtypeRemoteControlTogglePlayPause:
			[streamer pause];
			break;
		case UIEventSubtypeRemoteControlPlay:
			[streamer start];
			break;
		case UIEventSubtypeRemoteControlPause:
			[streamer pause];
			break;
		case UIEventSubtypeRemoteControlStop:
			[streamer stop];
			break;
		default:
			break;
	}
}

@end
