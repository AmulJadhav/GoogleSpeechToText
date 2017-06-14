//
//  HintViewController.m
//  GoogleSpeechToTextObjc
//
//  Created by Amul Jadhav on 12/06/17.
//  Copyright © 2017 Amul Jadhav. All rights reserved.
//

#import "HintViewController.h"
#import <AVFoundation/AVFoundation.h>

#define API_KEY @"YOUR_API_KEY"

#define SAMPLE_RATE 16000
#define FILE_NAME @"Sound"


@interface HintViewController () <AVAudioRecorderDelegate, AVAudioPlayerDelegate, UITextViewDelegate>
{
    NSTimer *stopTimer;
    NSDate *startDate;
    BOOL running;
    NSMutableDictionary *phraseDict;
}

@property (weak, nonatomic) IBOutlet UITextView *readingTextView;

@property (nonatomic, strong) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UITextView *hintTextView;

@property (strong, nonatomic) AVAudioRecorder *audioRecorder;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) NSString *googleCloudFileURI;
@property (strong, nonatomic) NSString *transcriptId;
@property (weak, nonatomic) IBOutlet UILabel *timerLabel;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;

@end

@implementation HintViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *soundFileURL = [NSURL fileURLWithPath:[self soundFilePath]];
    NSDictionary *recordSettings = @{AVEncoderAudioQualityKey:@(AVAudioQualityMax),
                                     AVEncoderBitRateKey: @16,
                                     AVNumberOfChannelsKey: @1,
                                     AVSampleRateKey: @(SAMPLE_RATE)};
    NSError *error;
    _audioRecorder = [[AVAudioRecorder alloc]
                      initWithURL:soundFileURL
                      settings:recordSettings
                      error:&error];
    if (error) {
        NSLog(@"error: %@", error.localizedDescription);
    }
    
    self.timerLabel.text = @"00.00.00";
    running = FALSE;
    startDate = [NSDate date];
    
    [_messageLabel setAdjustsFontSizeToFitWidth:true];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:tap];
}

// MARK:- Private Methods

- (NSString *) soundFilePath {
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = dirPaths[0];
    NSLog(@"%@", [docsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.flac", FILE_NAME]]);
    return [docsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.flac", FILE_NAME]];
}

- (void) updateTime {
    
    NSDate *currentDate = [NSDate date];
    NSTimeInterval timeInterval = [currentDate timeIntervalSinceDate:startDate];
    NSDate *timerDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0.0]];
    NSString *timeString=[dateFormatter stringFromDate:timerDate];
    self.timerLabel.text = timeString;
}

-(void)resetPressed{
    [stopTimer invalidate];
    stopTimer = nil;
    startDate = [NSDate date];
    self.timerLabel.text = @"00.00.00.000";
    running = FALSE;
}

- (void)dismissKeyboard
{
    [_textView resignFirstResponder];
    [_hintTextView resignFirstResponder];
    [_readingTextView resignFirstResponder];
}


// MARK:- IBActions

- (IBAction)recordAudio:(id)sender {
    [self stopAudio:sender];
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [_audioRecorder record];
    _messageLabel.text = @"Recording...";
    
    [self resetPressed];
    stopTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/10.0
                                                 target:self
                                               selector:@selector(updateTime)
                                               userInfo:nil
                                                repeats:YES];
}

- (IBAction)playAudio:(id)sender {
    [self stopAudio:sender];
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    NSError *error;
    _audioPlayer = [[AVAudioPlayer alloc]
                    initWithContentsOfURL:_audioRecorder.url
                    error:&error];
    _audioPlayer.delegate = self;
    _audioPlayer.volume = 1.0;
    if (error)
        NSLog(@"Error: %@",
              error.localizedDescription);
    else
        [_audioPlayer play];
}

- (IBAction)stopAudio:(id)sender {
    if (_audioRecorder.recording) {
        [_audioRecorder stop];
    } else if (_audioPlayer.playing) {
        [_audioPlayer stop];
    }
    _messageLabel.text = @"";
    running = FALSE;
    [stopTimer invalidate];
    stopTimer = nil;
}
- (IBAction)processAudio:(id)sender {
    [self stopAudio:sender];
    phraseDict = nil;
    [self uploadAudio:nil];
}
- (IBAction)processWithHintAudio:(id)sender {
    [self stopAudio:sender];
    // Create a phrasearray
    NSArray *arr = [_hintTextView.text componentsSeparatedByString:@","];
    NSMutableArray *phraseArray = [NSMutableArray arrayWithObjects:@"means probably you", @"this is a hello", nil];
    [phraseArray addObjectsFromArray:arr];
    phraseDict = [NSMutableDictionary dictionaryWithObjectsAndKeys: phraseArray, @"phrases", nil];
    [self uploadAudio:nil];
}

- (void)process
{
    _messageLabel.text = @"Processing...";
    NSString *service = @"https://speech.googleapis.com/v1/speech:longrunningrecognize";
    service = [service stringByAppendingString:@"?key="];
    service = [service stringByAppendingString:API_KEY];
    
    //    NSData *audioData = [NSData dataWithContentsOfFile:[self soundFilePath]];
    
    NSDictionary *configRequest = nil;
  
    if ( phraseDict == nil )
    {
        
        configRequest = @{@"encoding":@"LINEAR16",
                          @"sampleRateHertz":@(SAMPLE_RATE),
                          @"languageCode":@"en-US"};
        //                                  @"maxAlternatives":@30,
        //                                  @"speechContexts": phrasDict};
    }
    else
    {
        configRequest = @{@"encoding":@"LINEAR16",
                          @"sampleRateHertz":@(SAMPLE_RATE),
                          @"languageCode":@"en-US",
                          @"speechContexts": phraseDict};
        //                                  @"maxAlternatives":@30,
    }
    //    NSDictionary *audioRequest = @{@"content":[audioData base64EncodedStringWithOptions:0]};
    
    //    NSDictionary *audioURI = [NSDictionary dictionaryWithObjectsAndKeys:@"https://storage.googleapis.com/texttospeech-poc/sound.flac", @"uri", nil];
    NSDictionary *requestDictionary = @{@"config":configRequest,
                                        @"audio": @{@"uri":_googleCloudFileURI}}; //@"gs://texttospeech-poc/sound.flac"
    NSError *error;
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestDictionary
                                                          options:0
                                                            error:&error];
    
    NSString *path = service;
    NSURL *URL = [NSURL URLWithString:path];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    // if your API key has a bundle ID restriction, specify the bundle ID like this:
    [request addValue:[[NSBundle mainBundle] bundleIdentifier] forHTTPHeaderField:@"X-Ios-Bundle-Identifier"];
    NSString *contentType = @"application/json";
    [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:requestData];
    [request setHTTPMethod:@"POST"];
    
    NSURLSessionTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:
     ^(NSData *data, NSURLResponse *response, NSError *error) {
         dispatch_async(dispatch_get_main_queue(),
                        ^{
                            
                            NSError* error;
                            NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data
                                                                                 options:kNilOptions
                                                                                   error:&error];
                            
                            if (error == nil)
                            {
                                _transcriptId = [json objectForKey:@"name"];
                                _messageLabel.text = @"Processing complete. Wait 30 seconds and then click Transcript";
                            }
                            else
                            {
                            }
                            
                            /*
                             NSArray *arr = [json objectForKey:@"results"];
                             NSDictionary *alter = arr[0];
                             NSArray *alterArray = [alter objectForKey:@"alternatives"];
                             for (NSDictionary *dict in alterArray)
                             {
                             _textView.text = [dict objectForKey:@"transcript"];
                             }
                             */
                            NSString *stringResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                            //                      _textView.text = stringResult;
                            NSLog(@"RESULT: %@", stringResult);
                        });
     }];
    [task resume];
}

- (IBAction) uploadAudio:(id) sender {
    
    _messageLabel.text = @"Uploading...";
    NSString *accessTokenString = [NSString stringWithFormat:@"Bearer %@", _accessToken];
    NSDictionary *headers = @{ @"content-type": @"audio/x-caf",
                               @"authorization": accessTokenString,
                               @"accept": @"application/json",
                               @"cache-control": @"no-cache",
                               };
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.googleapis.com/upload/storage/v1/b/texttospeech-poc/o?uploadType=media&name=%@.flac", FILE_NAME]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    NSData *audioData = [NSData dataWithContentsOfFile:[self soundFilePath]];
    [request setHTTPBody:audioData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"%@", error);
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        NSLog(@"%@", httpResponse);
                                                        
                                                        NSError* error;
                                                        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data
                                                                                                             options:kNilOptions
                                                                                                               error:&error];
                                                        NSLog(@"%@", json);
                                                        if (error == nil)
                                                        {
                                                            NSString *bucketName = [json objectForKey:@"bucket"];
                                                            NSString *fileName = [json objectForKey:@"name"];
                                                            NSString *completeGoogleStoragePath = [NSString stringWithFormat:@"gs://%@/%@", bucketName, fileName];
                                                            self.googleCloudFileURI = completeGoogleStoragePath;
                                                            [self process];
                                                        }
                                                    }
                                                }];
    [dataTask resume];
}

- (IBAction)getTranscript:(id)sender
{
    _messageLabel.text = @"Transcripting...";
    NSString *service = [NSString stringWithFormat:@"https://speech.googleapis.com/v1/operations/%@?key=%@", _transcriptId, API_KEY]; //@"https://speech.googleapis.com/v1/operations/1797849961581420399?key=AIzaSyDz7AUTIV5lr_DbIDtwKFxSNqzMWbn2InY";
    NSURL *URL = [NSURL URLWithString:service];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:
                              ^(NSData *data, NSURLResponse *response, NSError *error) {
                                  dispatch_async(dispatch_get_main_queue(),
                                                 ^{
                                                     
                                                     NSError* error;
                                                     NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data
                                                                                                          options:kNilOptions
                                                                                                            error:&error];
                                                     NSLog(@"%@", error.localizedDescription);
                                                     NSLog(@"%@", json);
                                                     if (error == nil)
                                                     {
                                                         NSDictionary *res = [json objectForKey:@"response"];
                                                         NSArray *resultArray = [res objectForKey:@"results"];
                                                         _textView.text = @"";
                                                         for (NSDictionary *dict in resultArray)
                                                         {
                                                             NSArray *alternatArray = [dict objectForKey:@"alternatives"];
                                                             
                                                             for (NSDictionary *transcriptDict in alternatArray)
                                                             {
                                                                 NSString *transcriptString = [transcriptDict objectForKey:@"transcript"];
                                                                 _textView.text = [_textView.text stringByAppendingString:transcriptString];
                                                             }
                                                         }
                                                         
                                                     }
                                                     
                                                     //                                                     NSString *stringResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                                     //                                                     NSLog(@"RESULT: %@", stringResult);
                                                     //                                                     _textView.text = stringResult;
                                                     _messageLabel.text = @"";
                                                 });
                              }];
    [task resume];
    
}

// MARK:- UITextview delegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ( [text isEqualToString:@"\n"])
    {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}
@end
