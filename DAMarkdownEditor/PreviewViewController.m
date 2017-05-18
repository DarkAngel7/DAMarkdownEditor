//
//  PreviewViewController.m
//  DAMarkdownEditor
//
//  Created by DarkAngel on 2017/5/16.
//  Copyright © 2017年 暗の天使. All rights reserved.
//

#import "PreviewViewController.h"

@interface PreviewViewController ()

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation PreviewViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self initialize];
}

#pragma mark Initialize

- (void)initialize
{
    if (self.htmlString.length) {
        [self.webView loadHTMLString:self.htmlString baseURL:nil];
    }
}

@end
