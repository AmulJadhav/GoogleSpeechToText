//
//  ViewController.m
//  GoogleSpeechToTextObjc
//
//  Created by Amul Jadhav on 09/06/17.
//  Copyright © 2017 Amul Jadhav. All rights reserved.
//

#import "ViewController.h"
#import <Google/SignIn.h>
#import "HintViewController.h"

@interface ViewController () <GIDSignInUIDelegate>
@property(weak, nonatomic) IBOutlet GIDSignInButton *signInButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [GIDSignIn sharedInstance].uiDelegate = self;
    
    
    NSString *driveScope = @"https://www.googleapis.com/auth/cloud-platform";
    NSArray *currentScopes = [GIDSignIn sharedInstance].scopes;
    [GIDSignIn sharedInstance].scopes = [currentScopes arrayByAddingObject:driveScope];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gotoRecordScreen:) name:@"GotoRecordScreen" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"GotoRecordScreen" object:nil];
}

- (IBAction)didTapSignOut:(id)sender {
    [[GIDSignIn sharedInstance] signOut];
}

- (void)gotoRecordScreen:(NSNotification*)notification
{
    NSDictionary* userInfo = notification.userInfo;
    NSString *accessToken = (NSString *)userInfo[@"accessToken"];
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    HintViewController *vc = [sb instantiateViewControllerWithIdentifier:@"HintViewController"];
    vc.accessToken = accessToken;
    [self.navigationController pushViewController:vc animated:true];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
