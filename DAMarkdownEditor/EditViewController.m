//
//  EditViewController.m
//  DAMarkdownEditor
//
//  Created by DarkAngel on 2017/5/16.
//  Copyright © 2017年 暗の天使. All rights reserved.
//

#import "EditViewController.h"
#import "PreviewViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>

static NSString *const kShowPreviewSegueId = @"ShowPreviewSegue";

@interface EditViewController ()

@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) IBOutlet UIToolbar *inputBar;
@property (strong, nonatomic) IBOutlet JSContext *jsContext;

@end

@implementation EditViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self initialize];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.view endEditing:YES];
}

- (void)initialize
{
    self.textView.inputAccessoryView = self.inputBar;
    self.textView.textContainerInset = UIEdgeInsetsMake(10, 5, 10, 5);
    //错误回调
    [self.jsContext setExceptionHandler:^(JSContext *context, JSValue *exception){
        NSLog(@"%@", exception.toString);
    }];
    
    //markdown -> html  js参考 https://github.com/showdownjs/showdown
    static NSString *js;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        js = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"showdown" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    });
    //加载js
    [self.jsContext evaluateScript:js];
    
    //注入function  markdown -> html，使用时，可以通过 convert('xxx'); 调用
    NSString *jsFunction = @"\
                            function convert(md) { \
                                return (new showdown.Converter()).makeHtml(md);\
                            }";
    [self.jsContext evaluateScript:jsFunction];
}

#pragma mark - Events

- (void)showMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

/**
 预览
 
 @param sender item
 */
- (IBAction)preview:(id)sender
{
    //标题不能为空
    if (!self.titleTextField.text.length) {
        [self showMessage:@"请先填写文章标题"];
        return;
    }
    //跳转到预览页
    [self performSegueWithIdentifier:kShowPreviewSegueId sender:self];
}

/**
 保存到沙盒目录
 
 @param sender item
 */
- (IBAction)save:(id)sender
{
    //标题不能为空
    if (!self.titleTextField.text.length) {
        [self showMessage:@"请先填写文章标题"];
        return;
    }
    NSData *data = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *filePath = [documentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.md", self.titleTextField.text]];
    //写入文件
    [data writeToFile:filePath atomically:YES];
    NSLog(@"md成功保存，地址%@", filePath);
    [self showMessage:@"保存成功"];
}

/**
 点击了toolBar上面的item
 
 @param item item
 */
- (IBAction)inputBarItemClicked:(UIBarButtonItem *)item
{
    NSString *title = item.title;
    //插入的文本内容
    NSString *insertText;
    //插入文本内容后，光标的位置
    NSRange selectedRange = self.textView.selectedRange;
    if ([title isEqualToString:@"link"]) {
        insertText = @"[]()";
        selectedRange.location += 1;    //移动到 [ 后面
    } else if ([title isEqualToString:@"img"]) {
        insertText = @"![]()";
        selectedRange.location += 4;    //移动到 ( 后面
    } else {
        insertText = title;
        selectedRange.location += title.length; //移动到插入文本的最后
    }
    //插入文本
    [self.textView insertText:insertText];
    //移动光标
    self.textView.selectedRange = selectedRange;
}

#pragma mark - Setters and Getters

- (NSString *)htmlString
{
    //markdown -> html
    JSValue *jsFunctionValue = self.jsContext[@"convert"];
    JSValue *htmlValue = [jsFunctionValue callWithArguments:@[self.textView.text]];
    //加载css样式
    static NSString *css;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        css = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"markdown" ofType:@"css"] encoding:NSUTF8StringEncoding error:nil];
    });
    return [NSString stringWithFormat:@"\
            <html>\
                <head>\
                    <title>%@</title>\
                    <style>%@</style>\
                </head>\
                <body>\
                    %@\
                </body>\
            </html>\
            ", self.titleTextField.text, css, htmlValue.toString];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //跳转到预览页
    if ([segue.identifier isEqualToString:kShowPreviewSegueId]) {
        PreviewViewController *vc = segue.destinationViewController;
        vc.htmlString = [self htmlString];
        vc.title = self.titleTextField.text;
    }
}

@end
