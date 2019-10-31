//
//  XLConfigManager.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/10/16.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLConfigManager.h"
#import "XLConfig.h"
#define kHaveNewConfig @"kHaveNewConfig_684C75F252182051F7BA6BCE1E914CFB"
#define kHaveNewCurrency @"kHaveNewCurrency_D1A3F844B269F9B94EE16890B8839D92"
@interface XLConfigManager ()
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, assign) NSUInteger timeout;
@property (nonatomic, copy) NSString *debugMode;
@property (nonatomic, copy) NSString *currency;
@end

@implementation XLConfigManager
+ (instancetype)share
{
    static XLConfigManager *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[XLConfigManager alloc] init];
        NSUserDefaults *userDefalut = [NSUserDefaults standardUserDefaults];
        NSString *newConfig = [userDefalut valueForKey:kHaveNewConfig];
        if ([newConfig isEqualToString:@"YES"] == YES) {
            handler.host = [userDefalut valueForKey:kCONFIG_MANAGER_HOST];
            handler.port = [[userDefalut valueForKey:kCONFIG_MANAGER_PORT] integerValue];
            handler.timeout = [[userDefalut valueForKey:kCONFIG_MANAGER_TIMEOUT] integerValue];
            handler.debugMode = [userDefalut valueForKey:kCONFIG_MANAGER_DEBUG_MODE];
        }else{
            handler.host = kHOST;
            handler.port = kPORT;
            handler.timeout = kSOCKET_READ_WRITE_TIMEOUT;
            handler.debugMode = DEBUG_LOG_MODE;
        }
        NSString *newCurrency = [userDefalut valueForKey:kHaveNewCurrency];
        if ([newCurrency isEqualToString:@"YES"] == YES) {
            handler.currency = [userDefalut valueForKey:kCONFIG_CURRENT_CURRENCY];
        }else{
            handler.currency = @"978";
        }
        
        
    });
    return handler;
}
/**
 *    @brief    设置默认的设备名称
 *
 *    @param     host     CAP 后端服务地址
 *    @param     port     CAP 后端服务端口
 *    @param     timeout  socket 通信读写超时时间
 *    @param     deubgModel     是否调试模式，// 1 开启日志 0 关闭日志
 */
- (BOOL)setConfigManagerHost:(nonnull NSString *) host
                        port:(NSUInteger) port
                     timeout:(NSInteger) timeout
                  debugModel:(NSString *)deubgModel
{
    NSUserDefaults *userDefalut = [NSUserDefaults standardUserDefaults];
    if (!host || host.length <= 0) {
        return NO;
    }else{
        [XLConfigManager share].host = host;
        [userDefalut setValue:host forKey:kCONFIG_MANAGER_HOST];
    }
    if (port <= 0) {
        return NO;
    }else{
        [XLConfigManager share].port = port ;
        [userDefalut setValue:@(port) forKey:kCONFIG_MANAGER_PORT];
    }
    if (timeout < 20) {
        [XLConfigManager share].timeout = 20;
        [userDefalut setValue:@(20) forKey:kCONFIG_MANAGER_TIMEOUT];
    }else{
        [XLConfigManager share].timeout = timeout;
        [userDefalut setValue:@(timeout) forKey:kCONFIG_MANAGER_TIMEOUT];
    }
    if (!deubgModel || deubgModel.length <= 0) {
        [userDefalut setValue:@"1" forKey:kCONFIG_MANAGER_DEBUG_MODE];
        [XLConfigManager share].debugMode = @"1";
    }else{
        [XLConfigManager share].debugMode = deubgModel;
        [userDefalut setValue:deubgModel forKey:kCONFIG_MANAGER_DEBUG_MODE];
    }
    [userDefalut setValue:@"YES" forKey:kHaveNewConfig];
    return [userDefalut synchronize];
}

/**
 *    @brief    设置当前交易的货币代码
 *
 *    @param     currency     货币代码  如：978
 */
- (BOOL)setCurrentCurrency:(nonnull NSString *)currency
{
    NSUserDefaults *userDefalut = [NSUserDefaults standardUserDefaults];
    if (!currency || currency.length <= 0) {
        [userDefalut setValue:@"978" forKey:kCONFIG_CURRENT_CURRENCY];
        [XLConfigManager share].currency = @"978";
    }else{
        [XLConfigManager share].currency = currency;
        [userDefalut setValue:currency forKey:kCONFIG_CURRENT_CURRENCY];
    }
    [userDefalut setValue:@"YES" forKey:kHaveNewCurrency];
    return [userDefalut synchronize];
}
/**
 *    @brief   获取 CAP 后端服务IP地址
 */
- (NSString *)getHost
{
    return [XLConfigManager share].host;
}

/**
 *    @brief   获取 CAP 后端服务端口
 */
- (NSUInteger)getPort
{
   
    return [XLConfigManager share].port;
}

/**
 *    @brief   获取 socket 通信读写超时时间
 */
- (NSUInteger)getTimeout
{
    return [XLConfigManager share].timeout;
}

/**
 *    @brief   获取当前模式
 */
- (NSString *)getDebugModel
{
    return [XLConfigManager share].debugMode;
}
/**
 *    @brief   获取当前货币代码
 */
- (NSString *)getCurrency
{
    return [XLConfigManager share].currency;
}
@end
