//
//  PreviewViewController.h
//  DAMarkdownEditor
//
//  Created by DarkAngel on 2017/5/16.
//  Copyright © 2017年 暗の天使. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
/**
 预览Html页面
 */
@interface PreviewViewController : UIViewController
/**
 html文本
 */
@property (nonatomic, copy, nullable) NSString *htmlString;

@end

NS_ASSUME_NONNULL_END
