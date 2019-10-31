//
//  XLConfig.h
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/12.
//  Copyright © 2019年 ccd. All rights reserved.
//

#ifndef XLConfig_h
#define XLConfig_h

#define kHOST                                      @"116.236.215.18"                    // IP
#define kPORT                                      5711                                 // socket端口
#define kSOCKET_READ_WRITE_TIMEOUT                 60                                   // 读写超时时间
#define DEBUG_LOG_MODE                             @"1"                                 // @"1" 开启日志 @"0" 关闭日志
#define kTERMINALID                                @"30131988"                          // 终端编号
#define kMERCHANTID                                @"013102258120001"                   // 商户编号
#define kPOSORIGINTMK                              @"0123456789ABCDEFFEDCBA9876543210"
#define kTERMINALID_USERDEFAULT_KEY                @"kTERMINALID_USERDEFAULT_KEY"       // 终端编号存userdefault      key
#define kMERCHANTID_USERDEFAULT_KEY                @"kMERCHANTID_USERDEFAULT_KEY"       // 商户编号存userdefault      key
#define kMERCHANT_NAME_USERDEFAULT_KEY             @"kMERCHANT_NAME_USERDEFAULT_KEY"    // 商户名称存userdefault      key
#define kDEFAULT_DEVICE_NAME                       @"kDEFAULT_DEVICE_NAME"              // 默认的设备名称存userdefault key

#define kCONFIG_MANAGER_HOST                       @"kCONFIG_MANAGER_HOST"              // userdefault中 IP地址        key
#define kCONFIG_MANAGER_PORT                       @"kCONFIG_MANAGER_PORT"              // userdefault中 端口          key
#define kCONFIG_MANAGER_TIMEOUT                    @"kCONFIG_MANAGER_TIMEOUT"           // userdefault中 超时时间       key
#define kCONFIG_CURRENT_CURRENCY                   @"kCONFIG_CURRENT_CURRENCY"          // userdefault中 币种          key
#define kCONFIG_MANAGER_DEBUG_MODE                 @"kCONFIG_MANAGER_DEBUG_MODE"        // userdefault中 是否调试模式  // @"1" 开启日志 @"0" 关闭日志
#endif /* XLConfig_h */
