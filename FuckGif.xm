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
// 添加防重复下载标记
static NSMutableSet *downloadingURLs;
// 添加下载队列管理
static dispatch_queue_t downloadQueue;
// 添加活动下载计数
static NSUInteger activeDownloads = 0;
// 最大并行下载数
static const NSUInteger MAX_CONCURRENT_DOWNLOADS = 3;
// 下载计数器锁
static NSLock *downloadCountLock;

// 初始化钩子，确保功能自动启用
%ctor {
    // 设置默认启用表情包下载功能
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYFourceDownloadEmotion"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 初始化防重复下载集合
    downloadingURLs = [NSMutableSet new];
    
    // 创建专用的串行下载队列
    downloadQueue = dispatch_queue_create("com.c00kiec00k.fuckgif.download_queue", DISPATCH_QUEUE_SERIAL);
    
    // 创建下载计数锁
    downloadCountLock = [[NSLock alloc] init];
}

// 辅助函数：管理下载计数
static void incrementActiveDownloads(void) {
    [downloadCountLock lock];
    activeDownloads++;
    [downloadCountLock unlock];
}

static void decrementActiveDownloads(void) {
    [downloadCountLock lock];
    if (activeDownloads > 0) {
        activeDownloads--;
    }
    [downloadCountLock unlock];
}

static NSUInteger getActiveDownloads(void) {
    [downloadCountLock lock];
    NSUInteger count = activeDownloads;
    [downloadCountLock unlock];
    return count;
}

// 辅助函数：下载表情包并防止重复下载
static void downloadStickerIfNeeded(AWEIMStickerModel *sticker) {
    if (!sticker) return;
    
    @autoreleasepool {
        AWEURLModel *staticURLModel = [sticker staticURLModel];
        if (!staticURLModel) return;
        
        NSArray *originURLList = [staticURLModel originURLList];
        if (!originURLList || originURLList.count == 0) return;
        
        NSString *urlString = originURLList[0];
        
        // 检查是否正在下载此URL
        @synchronized(downloadingURLs) {
            if ([downloadingURLs containsObject:urlString]) {
                return;
            }
            
            // 添加到正在下载集合
            [downloadingURLs addObject:urlString];
        }
        
        // 入队下载任务
        dispatch_async(downloadQueue, ^{
            // 检查活动下载数量，如超过限制则等待
            while (getActiveDownloads() >= MAX_CONCURRENT_DOWNLOADS) {
                [NSThread sleepForTimeInterval:0.1];
            }
            
            // 增加活动下载计数
            incrementActiveDownloads();
            
            NSURL *heifURL = [NSURL URLWithString:urlString];
            
            [FuckGifManager downloadMedia:heifURL mediaType:MediaTypeHeic completion:^{
                // 完成后从集合中移除
                @synchronized(downloadingURLs) {
                    [downloadingURLs removeObject:urlString];
                }
                
                // 减少活动下载计数
                decrementActiveDownloads();
            }];
        });
    }
}

// 第一种方法：拦截SaveImageElement的方法
%hook _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement

// 确保表情包保存选项可见
-(BOOL)elementShouldShow {
    @autoreleasepool {
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        if (!commentPageContext) {
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
            return %orig;
        }
        
        AWEIMStickerModel *sticker = [selectdComment sticker];
        if(sticker) {
            AWEURLModel *staticURLModel = [sticker staticURLModel];
            if (staticURLModel) {
                NSArray *originURLList = [staticURLModel originURLList];
                if (originURLList && originURLList.count > 0) {
                    return YES;
                }
            }
        }
        return %orig;
    }
}

-(void)elementTapped {
    @autoreleasepool {
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
            // 使用辅助函数下载表情包
            downloadStickerIfNeeded(sticker);
            return;
        }
        %orig;
    }
}
%end

// 第二种方法：拦截CopyElement的点击，使用更通用的方法
%hook _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement

-(void)elementTapped {
    // 直接执行原始方法，不尝试获取commentPageContext
    %orig;
}
%end

// 第三种方法：尝试拦截所有表情包点击
%hook AWEIMStickerModel

// 当表情包被点击时自动保存
- (void)didTap {
    %orig;
    
    // 使用辅助函数下载表情包
    @autoreleasepool {
        downloadStickerIfNeeded(self);
    }
}

%end 
