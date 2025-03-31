/* 
 * Tweak Name: FuckGif
 * Target App: com.ss.iphone.ugc.Aweme
 * Dev: @c00kiec00k 曲奇的坏品味🍻
 * iOS Version: 16.5
 */
#import "FuckGifManager.h"
#import <Photos/Photos.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <ImageIO/ImageIO.h>

// 为防止kUTTypeGIF未定义，提供一个后备定义
#ifndef kUTTypeGIF
#define kUTTypeGIF ((__bridge CFStringRef)@"com.compuserve.gif")
#endif

@implementation FuckGifManager

static FuckGifManager *_sharedInstance = nil;
static UILabel *_currentToastLabel = nil;
static BOOL _isProcessing = NO; // 处理状态标志，防止重复操作

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[FuckGifManager alloc] init];
    });
    return _sharedInstance;
}

+ (UIWindow *)getActiveWindow {
    UIWindow *window = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                // 优先使用前台窗口
                for (UIWindow *win in windowScene.windows) {
                    if (win.isKeyWindow) {
                        return win;
                    }
                }
                // 没有找到keyWindow时，选择任一可见窗口
                for (UIWindow *win in windowScene.windows) {
                    if (win.isUserInteractionEnabled && win.alpha > 0 && !win.hidden) {
                        window = win; break;
                    }
                }
                if (window) break;
            }
        }
    } else {
        // iOS 13以下使用已弃用的方法
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    
    return window;
}

// Toast消息
+ (void)showToast:(NSString *)text {
    if (!text || text.length == 0) return;
    
    // 使用抖音内置Toast
    Class toastClass = NSClassFromString(@"DUXToast");
    if (toastClass && [toastClass respondsToSelector:@selector(showText:)]) {
        [toastClass performSelector:@selector(showText:) withObject:text];
        return;
    }
    
    // Toast
    dispatch_async(dispatch_get_main_queue(), ^{
        // 如果当前已有Toast在显示，先移除它
        if (_currentToastLabel) {
            [_currentToastLabel removeFromSuperview];
            _currentToastLabel = nil;
        }
        
        UIWindow *window = [self getActiveWindow];
        if (!window) return;
        
        UILabel *toastLabel = [[UILabel alloc] init];
        toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
        toastLabel.textColor = [UIColor whiteColor];
        toastLabel.textAlignment = NSTextAlignmentCenter;
        toastLabel.font = [UIFont systemFontOfSize:14];
        toastLabel.text = text;
        toastLabel.alpha = 0;
        toastLabel.layer.cornerRadius = 8;
        toastLabel.clipsToBounds = YES;
        
        // 适配不同屏幕尺寸
        CGFloat safeAreaBottomInset = 0;
        if (@available(iOS 11.0, *)) {
            safeAreaBottomInset = window.safeAreaInsets.bottom;
        }
        
        [toastLabel sizeToFit];
        CGFloat width = MIN(280, MAX(120, toastLabel.frame.size.width + 40));
        CGFloat height = toastLabel.frame.size.height + 15;
        toastLabel.frame = CGRectMake((window.frame.size.width - width) / 2,
                                    window.frame.size.height - 120 - safeAreaBottomInset,
                                    width, height);
        
        toastLabel.isAccessibilityElement = YES;
        toastLabel.accessibilityLabel = text;
        toastLabel.accessibilityTraits = UIAccessibilityTraitStaticText;

        [window addSubview:toastLabel];
        _currentToastLabel = toastLabel;
        
        [UIView animateWithDuration:0.3 animations:^{
            toastLabel.alpha = 1;
        } completion:^(BOOL finished) {
            if (!finished) return;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (_currentToastLabel == toastLabel) {
                    [UIView animateWithDuration:0.3 animations:^{
                        toastLabel.alpha = 0;
                    } completion:^(BOOL finished) {
                        if (!finished) return;
                        [toastLabel removeFromSuperview];
                        if (_currentToastLabel == toastLabel) {
                            _currentToastLabel = nil;
                        }
                    }];
                }
            });
        }];
    });
}

// HEIC表情包保存为GIF的入口方法
+ (void)saveHeicToGif:(NSURL *)heicURL completion:(void (^)(void))completion {
    // 防止重复操作
    if (_isProcessing) {
        [self showToast:@"已有表情包正在处理中"];
        if (completion) completion();
        return;
    }
    
    _isProcessing = YES;
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            // 转换HEIC到GIF
            [self convertHeicToGif:heicURL completion:^(NSURL *gifURL, BOOL success) {
                if (success && gifURL) {
                    // 保存转换后的GIF文件
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        // 读取GIF数据
                        NSData *gifData = [NSData dataWithContentsOfURL:gifURL options:NSDataReadingMappedIfSafe error:nil];
                        
                        if (!gifData || gifData.length == 0) return;
                        
                        // 创建相册资源请求
                        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                        PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                        options.uniformTypeIdentifier = @"com.compuserve.gif"; 
                        [request addResourceWithType:PHAssetResourceTypePhoto data:gifData options:options];  
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        _isProcessing = NO; // 重置处理状态
                        
                        if (success) {
                            [self showToast:@"表情包已保存到相册"];
                            if (completion) completion();
                        } else {
                            NSString *errorMsg = error ? error.localizedDescription : @"未知错误";
                            [self showToast:[NSString stringWithFormat:@"保存失败: %@", errorMsg]];
                            if (completion) completion();
                        }
                        
                        // 清理临时文件
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                            [[NSFileManager defaultManager] removeItemAtPath:heicURL.path error:nil];
                            [[NSFileManager defaultManager] removeItemAtPath:gifURL.path error:nil];
                        });
                    }];
                } else {
                    _isProcessing = NO; // 重置处理状态
                    [self showToast:@"转换失败"];
                    [[NSFileManager defaultManager] removeItemAtPath:heicURL.path error:nil];
                    if (completion) completion();
                }
            }];
        } else {
            _isProcessing = NO; // 重置处理状态
            
            NSString *authMessage;
            if (status == PHAuthorizationStatusDenied) {
                authMessage = @"请在设置中允许访问相册";
            } else if (status == PHAuthorizationStatusRestricted) {
                authMessage = @"相册访问受到限制";
            } else {
                authMessage = @"无法访问相册，请检查权限设置";
            }
            
            [self showToast:authMessage];
            if (completion) completion();
        }
    }];
}

// 转换HEIC到GIF的核心方法
+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // 创建HEIC图像源
        CGImageSourceRef heicSource = CGImageSourceCreateWithURL((__bridge CFURLRef)heicURL, NULL);
        if (!heicSource) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, NO);
            });
            return;
        }
        
        // 获取HEIC图像数量
        size_t count = CGImageSourceGetCount(heicSource);
        if (count == 0) {
            CFRelease(heicSource);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, NO);
            });
            return;
        }
        
        BOOL isAnimated = (count > 1);
        
        // 创建GIF文件路径
        NSString *gifFileName = [[heicURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
        NSURL *gifURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:gifFileName]];
        
        // 基本GIF属性
        NSDictionary *gifProperties = @{
            (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                (__bridge NSString *)kCGImagePropertyGIFLoopCount: @0, // 无限循环
                (__bridge NSString *)kCGImagePropertyGIFHasGlobalColorMap: @YES
            }
        };
        
        // 创建GIF图像目标
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, isAnimated ? count : 1, NULL);
        if (!destination) {
            CFRelease(heicSource);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, NO);
            });
            return;
        }
        
        // 设置GIF属性
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
        
        // 基本图像选项
        NSDictionary *options = @{
            (__bridge NSString *)kCGImageSourceShouldCache: @YES
        };
        
        BOOL conversionSuccess = YES;
        
        if (isAnimated) {
            // 处理动图
            for (size_t i = 0; i < count && conversionSuccess; i++) {
                @autoreleasepool {
                    // 获取原始图像
                    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(heicSource, i, (__bridge CFDictionaryRef)options);
                    if (!imageRef) {
                        conversionSuccess = NO;
                        continue;
                    }
                    
                    // 获取原始帧延迟
                    float delayTime = 0.1f; // 默认延迟
                    CFDictionaryRef propsDict = CGImageSourceCopyPropertiesAtIndex(heicSource, i, NULL);
                    if (propsDict) {
                        CFDictionaryRef heicDict = CFDictionaryGetValue(propsDict, kCGImagePropertyHEICSDictionary);
                        if (heicDict) {
                            CFNumberRef delayTimeRef = CFDictionaryGetValue(heicDict, kCGImagePropertyHEICSDelayTime);
                            if (delayTimeRef && !CFNumberGetValue(delayTimeRef, kCFNumberFloatType, &delayTime)) {
                                delayTime = 0.1f; // 读取失败时使用默认值
                            }
                        }
                        CFRelease(propsDict);
                    }
                    
                    // 确保延时合理
                    if (delayTime < 0.02f) delayTime = 0.1f; // 避免过快动画
                    
                    // 帧属性设置
                    NSDictionary *frameProperties = @{
                        (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                            (__bridge NSString *)kCGImagePropertyGIFDelayTime: @(delayTime),
                            (__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime: @(delayTime)
                        }
                    };
                    
                    // 添加帧到GIF
                    CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProperties);
                    CGImageRelease(imageRef);
                }
            }
        } else {
            // 处理静态图片
            @autoreleasepool {
                CGImageRef imageRef = CGImageSourceCreateImageAtIndex(heicSource, 0, (__bridge CFDictionaryRef)options);
                if (!imageRef) {
                    conversionSuccess = NO;
                } else {
                    // 静态图像帧属性
                    NSDictionary *frameProperties = @{
                        (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                            (__bridge NSString *)kCGImagePropertyGIFDelayTime: @0.1f
                        }
                    };
                    
                    CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProperties);
                    CGImageRelease(imageRef);
                }
            }
        }
        
        // 完成GIF生成
        BOOL finalizeSuccess = conversionSuccess ? CGImageDestinationFinalize(destination) : NO;
        
        // 释放资源
        CFRelease(heicSource);
        CFRelease(destination);
        
        // 验证生成的GIF文件
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:gifURL.path];
        BOOL isValid = fileExists && finalizeSuccess;
        
        if (isValid) {
            // 检查文件大小
            NSError *attributesError = nil;
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:gifURL.path error:&attributesError];
            if (!attributesError) {
                unsigned long long fileSize = [attributes fileSize];
                if (fileSize == 0) isValid = NO;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(isValid ? gifURL : nil, isValid);
        });
    });
}

// 从URL下载并保存表情包
+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    if (!url) {
        [self showToast:@"无效的表情包URL"];
        if (completion) completion();
        return;
    }
    
    // 仅处理傻逼抖音的HEIC类型表情包
    if (mediaType != MediaTypeHeic) {
        [self showToast:@"仅支持表情包格式"];
        if (completion) completion();
        return;
    }
    
    [self showToast:@"开始获取表情包..."];
    
    // 直接加载本地数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSError *error = nil;
        NSData *data = nil;
        
        // 如果URL是文件URL，直接读取文件
        if ([url isFileURL]) {
            data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&error];
        } 
        // 否则尝试从文件名获取数据
        else {
            // 获取URL的最后部分作为文件名
            NSString *fileName = url.lastPathComponent;
            if (fileName.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showToast:@"无效的表情包数据"];
                    if (completion) completion();
                });
                return;
            }
            
            // 在Documents和Caches目录中查找匹配的文件
            NSArray *searchPaths = @[
                NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
                NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject,
                NSTemporaryDirectory()
            ];
            
            for (NSString *directory in searchPaths) {
                if (!directory) continue;
                
                NSString *filePath = [directory stringByAppendingPathComponent:fileName];
                if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                    data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
                    if (data && !error) break;
                }
            }
        }
        
        // 处理错误
        if (error || !data || data.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"获取表情包数据失败"];
                if (completion) completion();
            });
            return;
        }
        
        // 创建临时文件
        NSString *fileName = [NSString stringWithFormat:@"%@.heic", [[NSUUID UUID] UUIDString]];
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
        
        // 写入文件并保存
        if ([data writeToURL:fileURL options:NSDataWritingAtomic error:nil]) {
            [self saveHeicToGif:fileURL completion:completion];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"保存文件失败"];
                if (completion) completion();
            });
        }
    });
}

// 兼容旧代码 - 保留saveMedia方法作为桥接
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    if (mediaType == MediaTypeHeic) {
        [self saveHeicToGif:mediaURL completion:completion];
    } else {
        [self showToast:@"仅支持表情包"];
        if (completion) completion();
    }
}

@end 
