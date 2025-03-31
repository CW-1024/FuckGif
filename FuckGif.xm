/* 
 * Tweak Name: FuckGif
 * Target App: com.ss.iphone.ugc.Aweme
 * Dev: @c00kiec00k 曲奇的坏品味🍻
 * iOS Version: 16.5
 */
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "AwemeHeaders.h"
#import "FuckGifManager.h"

// 全局变量，用于控制下载选项
static BOOL isDownloadFlied = NO;

// 初始化钩子，确保功能自动启用
%ctor {
    // 设置默认启用表情包下载功能
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYFourceDownloadEmotion"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 输出日志，帮助调试
    NSLog(@"[FuckGif] 插件已初始化，表情包自动保存已启用");
}

// 第一种方法：拦截SaveImageElement的方法
%hook _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement

// 确保表情包保存选项可见
-(BOOL)elementShouldShow {
    AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
    if (!commentPageContext) {
        NSLog(@"[FuckGif] commentPageContext为空");
        return %orig;
    }
    
    AWECommentModel *selectdComment = [commentPageContext selectdComment];
    if(!selectdComment) {
        AWECommentLongPressPanelParam *params = [commentPageContext params];
        if (params) {
            selectdComment = [params selectdComment];
        }
    }
    
    if (!selectdComment) {
        NSLog(@"[FuckGif] selectdComment为空");
        return %orig;
    }
    
    AWEIMStickerModel *sticker = [selectdComment sticker];
    if(sticker) {
        AWEURLModel *staticURLModel = [sticker staticURLModel];
        if (staticURLModel) {
            NSArray *originURLList = [staticURLModel originURLList];
            if (originURLList && originURLList.count > 0) {
                NSLog(@"[FuckGif] 检测到表情包，显示保存选项");
                return YES;
            }
        }
    }
    return %orig;
}

-(void)elementTapped {
    NSLog(@"[FuckGif] SaveImageElement 被点击");
    AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
    if (!commentPageContext) {
        %orig;
        return;
    }
    
    AWECommentModel *selectdComment = [commentPageContext selectdComment];
    if(!selectdComment) {
        AWECommentLongPressPanelParam *params = [commentPageContext params];
        if (params) {
            selectdComment = [params selectdComment];
        }
    }
    
    if (!selectdComment) {
        %orig;
        return;
    }
    
    AWEIMStickerModel *sticker = [selectdComment sticker];
    if(sticker) {
        AWEURLModel *staticURLModel = [sticker staticURLModel];
        if (staticURLModel) {
            NSArray *originURLList = [staticURLModel originURLList];
            if (originURLList && originURLList.count > 0) {
                NSString *urlString = @"";
                if(isDownloadFlied) {
                    urlString = originURLList[originURLList.count-1];
                    isDownloadFlied = NO;
                } else {
                    urlString = originURLList[0];
                }

                NSURL *heifURL = [NSURL URLWithString:urlString];
                NSLog(@"[FuckGif] 开始下载表情包: %@", urlString);
                [FuckGifManager downloadMedia:heifURL mediaType:MediaTypeHeic completion:^{
                    [FuckGifManager showToast:@"表情包已保存到相册"];
                }];
                return;
            }
        }
    }
    %orig;
}
%end

// 第二种方法：拦截CopyElement的点击，使用更通用的方法
%hook _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement

-(void)elementTapped {
    NSLog(@"[FuckGif] CopyElement 被点击");
    // 直接执行原始方法，不尝试获取commentPageContext
    %orig;
}
%end

// 第三种方法：尝试拦截所有表情包点击
%hook AWEIMStickerModel

// 当表情包被点击时自动保存傻逼GIF
- (void)didTap {
    %orig;
    
    NSLog(@"[FuckGif] 检测到表情包被点击");
    
    AWEURLModel *staticURLModel = [self staticURLModel];
    if (staticURLModel) {
        NSArray *originURLList = [staticURLModel originURLList];
        if (originURLList && originURLList.count > 0) {
            NSString *urlString = originURLList[0];
            NSURL *heifURL = [NSURL URLWithString:urlString];
            NSLog(@"[FuckGif] 自动下载表情包: %@", urlString);
            
            [FuckGifManager downloadMedia:heifURL mediaType:MediaTypeHeic completion:^{
                [FuckGifManager showToast:@"表情包已保存到相册"];
            }];
        }
    }
}

%end 