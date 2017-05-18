# DAMarkdownEditor
A lightweight markdown editor. 


# 前言

相信不少小伙伴看过笔者前面发的《**iOS中UIWebView与WKWebView、JavaScript与OC交互、Cookie管理看我就够**》系列了吧，文章中笔者介绍过很多关于Native与JS交互的使用。今天呢，笔者来用最快速度撸个最简单的`Markdown`编辑器。

其实iOS原生Markdown编辑器的实现方式有很多，Github上面也有一些比较厉害的库，本着不重复造轮子的原则，`markdown`纯文本转`html`字符串这部分就不自己实现了，其他部分笔者用`JavaScriptCore`结合JS和OC（Swift其实也一样），来实现一个简单的`Markdown`编辑器。

这篇文章不是为了教大家如何开发`Markdown`编辑器，而是为广大iOS开发者打开一个新的思路，我们能使用的不只是iOS开源库，有了`JavaScriptCore`，即便脱离开`WebView`，我们也是可以使用`JavaScript`开源库的~😊

下面为小伙伴介绍下具体的实现细节，希望小伙伴们喜欢的给个Star。

# 分析

如何在iOS上实现一个`markdown`编辑器呢？让我们来分析下。

- 首先，既然是编辑器，那应该会用到`UITextView`控件。
- 其次，用户是在`UITextView`上输入的文本，那作为一个编辑器，应该会有预览功能，点击预览则可以看到html页面。
- 再次，点击预览实现的是`markdown`纯文本转`html`字符串，怎么实现呢？
- 最后，考虑给`UITextView`的`inputAccessoryView`添加一些用户常用的按钮，比如“#、link、img”等，便于用户操作。

# 方案

上面提到的是笔者在做一个`markdown`编辑器时的思路，其实这个很重要，小伙伴们在遇到问题和处理问题时，也应该先整体思考，分析一下，然后得出实现方案，最后再去落实，养成一个好的习惯。

笔者的方案如下：

- 页面结构：一个`UIViewController`上面放一个`UITextView`，顶部`NavigationBar`上面放个**预览**按钮和**保存**按钮。点击预览，查看编辑好的预览页；点击保存，保存当前文章到沙盒目录（真的业务需求的话可能是发送）。
- `UITextView`的`markdown`纯文本转`html`字符串，[通过成熟的`js`来实现](https://cdn.rawgit.com/showdownjs/showdown/1.6.3/dist/showdown.min.js)，至于交互，使用`JavaScriptCore`（不重复造轮子，就不自己写正则处理了）。
- 预览页直接用`WebView`加载`html`字符串即可。

# 实现

## 搭建UI

这个So easy，分分钟~如下图

![63DAF661-7D46-42D2-BDAC-935FDEA66532](http://ww1.sinaimg.cn/large/006tNc79ly1ffpljo5k99j31kw0wlh03.jpg)

上面的图足够明确了吧~

编辑页中持有一个`JSContext`对象，同时持有一个`inputBar`，一个`TextView`（正文），一个`UITextField`（标题）。

预览页中是一个`UIWebView`（也可以是`WKWebView`）。

## 逻辑处理

### 初始化

`EditViewController`中首先实现初始化方法。

```objective-c
- (void)initialize
{
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
```

上面的代码中，我们提前给`jsContext`注入`showdown.js`文件，然后可以使用`(new showdown.Converter()).makeHtml(md);`的方法来将`markdown`字符串转换为`html`字符串。那么我们也提前注入了一个方法`convert` `function`来供我们自己调用。

### 添加工具栏

有一些字符，比如"*、-"等都是很常用的，这里我们添加一个工具栏，便于用户快捷操作。我们在初始化方法`initialize`中添加如下的方法。

```objective-c
self.textView.inputAccessoryView = self.inputBar;
```

当用户点击inputBar上的按钮时，触发事件：

```objective-c
/**
 点击了toolBar上面的item
 
 @param item item
 */
- (IBAction)inputBarItemClicked:(UIBarButtonItem *)item
{
    NSString *title = item.title;
    //插入的文本内容
    NSString *insertText;
    //插入文本内容后，移动光标到指定位置
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
```

效果如下

![工具栏输入](http://ww2.sinaimg.cn/large/006tNc79ly1ffpqjn9wngg30aa0iahdt.gif)

### 预览

此时用户可以愉悦地编辑内容，当用户编辑完成时，可以点击预览。预览的方法实现：

```objective-c
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

#pragma mark - Setters and Getters

- (NSString *)htmlString
{
    //markdown -> html
    JSValue *jsFunctionValue = self.jsContext[@"convert"];
    JSValue *htmlValue = [jsFunctionValue callWithArguments:@[self.textView.text]];
    return [NSString stringWithFormat:@"\
            <html>\
                <head>\
                    <title>%@</title>\
                </head>\
                <body>\
                    %@\
                </body>\
            </html>\
            ", self.titleTextField.text, htmlValue.toString];
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
```

点击预览，跳转到`PreviewViewController`页面，同时传递`htmlString`。这里如何获取`htmlString`呢？之前我们在`initialize`方法里，提前注入了名为`convert`的方法，现在我们来调用它

```objective-c
JSValue *jsFunctionValue = self.jsContext[@"convert"];
JSValue *htmlValue = [jsFunctionValue callWithArguments:@[self.textView.text]];
```

那我们很容易获取到了`markdown`文本转换成`html`的字符串了，然后我们给这个字符串完善下，添加上`html`标签、`head`标签以及页面的`title`，然后传递给预览页，直接展示就OK了。

效果如下图

![点击预览](http://ww2.sinaimg.cn/large/006tNc79ly1ffpqvmwpzfg30ac0ir49m.gif)

### 保存

其实保存，这里只是简单实现，保存到沙盒。实际业务需求，很可能一个发送按钮，上传到服务器，或者是分享到其他的App。这里简单介绍下保存到沙盒。下面上代码

```objective-c
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
```

保存的时候，直接保存源码到本地，就好了，文件命名为`标题.md`。

当我点击保存时，保存到本地，同时输出

```
DAMarkdownEditor[9717:192504] md成功保存，地址/Users/DarkAngel/Library/Developer/CoreSimulator/Devices/CF831783-E4A6-4EC2-AB99-E04304331C3A/data/Containers/Data/Application/A7837233-9EC3-4E4C-94CB-252329746176/Documents/A test title.md
```

我们用Safari，Cmd+Shift+G，打开上面的地址可以看到

![FC42EBA3-1996-4266-A7BC-9B2363F40E04](http://ww3.sinaimg.cn/large/006tNc79ly1ffpqsm8tfjj316s0o8jyj.jpg)

打开这个文件，可以查看下，源码就是我们输入的内容。

其实到这里，我们已经完成一个简单的`Markdown`编辑器。但是小伙伴们可能会说，预览的`html`太丑了，中间的代码块都没有高亮。那如何解决呢？

## 美化样式

如果你拥有前端的一点点知识，你会立刻想到，少了一个好看的`css`样式。我们可以通过给`html`添加`css`，来使页面看起来更好看。

下面我们在`- (NSString *)htmlString`方法中，给html添加css，这里我本地添加了一个`css`文件，直接读取并拼接到`head`标签中

```objective-c
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
```

好啦，让我们再点击预览一下

![添加css后，点击预览](http://ww4.sinaimg.cn/large/006tNc79ly1ffpr28i2xlg30ac0ir7f7.gif)

这下好看多了，如果小伙伴们想要自定义样式，只需要修改css文件就OK啦，当然Github上有很多好看的样式哦~可以找找看，也可以自己修改下css。

至此，我们的`Markdown`编辑器就完成了，`EditViewController`一共181行，`PreviewViewController`一共38行，加上一个简单的`Storyboard`，我们的编辑器非常清爽。后续，再可以优化下页面的UI、InputBar中多添加一些快捷按钮，优化下UE，我们就可以上传AppStore啦~

# 总结

上面我们用很少的代码，很少的时间完成了一个简单的`Markdown`编辑器，又一次证明了`JavaScriptCore`的强大，同时也证明了前端如此火热的今天，Native开发依然是王道。`Github`前十的开源项目中，有**六**款是基于`JavaScript`语言的。可能有些小伙伴作为一个Native端开发，会很方，很多小伙伴开始学习前端，学习js。当然，学习新的东西本就无可厚非。但我相信，被动学习的不在少数。

那么，我们可不可以利用它，结合Native打造更好的App呢？答案是：一定可以。
