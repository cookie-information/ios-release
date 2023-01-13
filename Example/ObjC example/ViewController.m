//
//  ViewController.m
//  ObjC example
//
//  Created by András Marczell on 11/01/2023.
//  Copyright © 2023 ClearCode. All rights reserved.
//

#import "ViewController.h"
@import MobileConsentsSDK;

@interface ViewController ()
@property MobileConsents *mobileConsents;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mobileConsents = [[MobileConsents alloc] initWithUiLanguageCode:@"EN"
                                                                clientID:@""
                                                            clientSecret:@""
                                                              solutionId:@""
                                                             accentColor: UIColor.systemBlueColor
                                                                 fontSet: FontSet.standard];
    
    
    // Do any additional setup after loading the view.
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self.mobileConsents showPrivacyPopUpOnViewController:self animated:YES completion:nil];

}

@end
