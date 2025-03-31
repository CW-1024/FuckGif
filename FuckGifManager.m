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
        NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
        for (UIScene *scene in scenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *win in windowScene.windows) {
                    // 避免使用isKeyWindow，它在iOS13+已废弃
                    if (win.isUserInteractionEnabled && win.alpha > 0 && !win.hidden) {
                        window = win;
                        break;
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

+ (void)showToast:(NSString *)text {
    Class toastClass = NSClassFromString(@"DUXToast");
    if (toastClass && [toastClass respondsToSelector:@selector(showText:)]) {
        [toastClass performSelector:@selector(showText:) withObject:text];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = [self getActiveWindow];
            
            UILabel *toastLabel = [[UILabel alloc] init];
            toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
            toastLabel.textColor = [UIColor whiteColor];
            toastLabel.textAlignment = NSTextAlignmentCenter;
            toastLabel.font = [UIFont systemFontOfSize:14];
            toastLabel.text = text;
            toastLabel.alpha = 0;
            toastLabel.layer.cornerRadius = 8;
            toastLabel.clipsToBounds = YES;
            
            [toastLabel sizeToFit];
            CGFloat width = MIN(280, MAX(120, toastLabel.frame.size.width + 20));
            
            toastLabel.frame = CGRectMake((window.frame.size.width - width) / 2,
                                         window.frame.size.height - 100,
                                         width, toastLabel.frame.size.height + 15);
            
            [window addSubview:toastLabel];
            
            [UIView animateWithDuration:0.3 animations:^{
                toastLabel.alpha = 1;
            } completion:^(BOOL finished) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.3 animations:^{
                        toastLabel.alpha = 0;
                    } completion:^(BOOL finished) {
                        [toastLabel removeFromSuperview];
                    }];
                });
            }];
        });
    }
}

+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    if (mediaType == MediaTypeAudio) {
        return;
    }

    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            // 如果是HEIC类型，先转换为GIF
            if (mediaType == MediaTypeHeic) {
                [self convertHeicToGif:mediaURL completion:^(NSURL *gifURL, BOOL success) {
                    if (success && gifURL) {
                        // 保存转换后的GIF文件
                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                            //获取表情包的数据
                            NSData *gifData = [NSData dataWithContentsOfURL:gifURL];
                            //创建相册资源
                            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                            //实例相册类资源参数
                            PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                            //定义表情包参数
                            options.uniformTypeIdentifier = @"com.compuserve.gif"; 
                            //保存表情包图片/gif动图
                            [request addResourceWithType:PHAssetResourceTypePhoto data:gifData options:options];  
                        } completionHandler:^(BOOL success, NSError * _Nullable error) {
                            if (success) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self showToast:@"表情包已保存到相册"];
                                });
                                
                                if (completion) {
                                    completion();
                                }
                            } else {
                                [self showToast:@"保存失败"];
                            }
                            // 清理临时文件
                            [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                            [[NSFileManager defaultManager] removeItemAtPath:gifURL.path error:nil];
                        }];
                    } else {
                        [self showToast:@"转换失败"];
                        [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                        if (completion) {
                            completion();
                        }
                    }
                }];
            } else {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    if (mediaType == MediaTypeVideo) {
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:mediaURL];
                    } else {
                        UIImage *image = [UIImage imageWithContentsOfFile:mediaURL.path];
                        if (image) {
                            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                        }
                    }
                } completionHandler:^(BOOL success, NSError * _Nullable error) {
                    if (success) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (mediaType == MediaTypeImage) {
                                [self showToast:@"图片已保存到相册"];
                            } else if (mediaType == MediaTypeVideo) {
                                [self showToast:@"视频已保存到相册"];
                            }
                        });
                        
                        if (completion) {
                            completion();
                        }
                    } else {
                        [self showToast:@"保存失败"];
                    }
                    [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path error:nil];
                }];
            }
        } else {
            [self showToast:@"请在设置中允许访问相册"];
        }
    }];
}

+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 创建HEIC图像源
        CGImageSourceRef heicSource = CGImageSourceCreateWithURL((__bridge CFURLRef)heicURL, NULL);
        if (!heicSource) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, NO);
                }
            });
            return;
        }
        
        // 获取HEIC图像数量
        size_t count = CGImageSourceGetCount(heicSource);
        BOOL isAnimated = (count > 1);
        
        // 创建他妈逼的GIF文件路径
        NSString *gifFileName = [[heicURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
        NSURL *gifURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:gifFileName]];
        
        // 设置傻逼GIF属性
        NSDictionary *gifProperties = @{
            (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                (__bridge NSString *)kCGImagePropertyGIFLoopCount: @0, // 0表示无限循环
            }
        };
        
        // 创建傻逼GIF图像目标
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, isAnimated ? count : 1, NULL);
        if (!destination) {
            CFRelease(heicSource);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, NO);
                }
            });
            return;
        }
        
        // 设置傻逼GIF属性
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
        
        if (isAnimated) {
            // 处理动画HEIC，提取所有帧并添加到GIF
            for (size_t i = 0; i < count; i++) {
                // 获取当前帧
                CGImageRef imageRef = CGImageSourceCreateImageAtIndex(heicSource, i, NULL);
                if (!imageRef) {
                    continue;
                }
                
                // 获取帧属性
                CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(heicSource, i, NULL);
                
                // 获取延迟时间
                float delayTime = 0.1f; // 默认延迟时间
                
                // 创建帧属性
                NSDictionary *frameProperties = @{
                    (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                        (__bridge NSString *)kCGImagePropertyGIFDelayTime: @(delayTime),
                    }
                };
                
                // 添加帧到GIF
                CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProperties);
                
                // 释放资源
                CGImageRelease(imageRef);
                if (properties) {
                    CFRelease(properties);
                }
            }
        } else {
            // 处理静态HEIC，创建单帧GIF
            CGImageRef imageRef = CGImageSourceCreateImageAtIndex(heicSource, 0, NULL);
            if (imageRef) {
                // 创建帧属性
                NSDictionary *frameProperties = @{
                    (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                        (__bridge NSString *)kCGImagePropertyGIFDelayTime: @0.1f,
                    }
                };
                
                // 添加帧到GIF
                CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProperties);
                
                // 释放资源
                CGImageRelease(imageRef);
            }
        }
        
        // 完成傻逼GIF生成 操他妈逼的！！！！
        BOOL success = CGImageDestinationFinalize(destination);
        
        // 释放资源
        CFRelease(heicSource);
        CFRelease(destination);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(gifURL, success);
            }
        });
    });
}

+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    // 下载到临时目录
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"下载失败"];
                if (completion) {
                    completion();
                }
            });
            return;
        }
        
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"下载数据为空"];
                if (completion) {
                    completion();
                }
            });
            return;
        }
        
        // 创建临时文件
        NSString *fileName = [NSString stringWithFormat:@"%@.heic", [[NSUUID UUID] UUIDString]];
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
        
        // 写入文件
        if ([data writeToURL:fileURL atomically:YES]) {
            [self saveMedia:fileURL mediaType:mediaType completion:completion];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"保存文件失败"];
                if (completion) {
                    completion();
                }
            });
        }
    }];
    
    [dataTask resume];
}

@end 