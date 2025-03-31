/* 
 * Tweak Name: FuckGif
 * Target App: com.ss.iphone.ugc.Aweme
 * Dev: @c00kiec00k 曲奇的坏品味🍻
 * iOS Version: 16.5
 */
#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"

@interface FuckGifManager : NSObject
  
+ (instancetype)shared;
+ (void)showToast:(NSString *)text;
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion;
+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion;

@end 
