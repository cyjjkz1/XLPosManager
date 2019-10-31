//
//  XLSocketHandler.h
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/1.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XLSocketDefine.h"
#import "XLResponseModel.h"

@protocol XLSocketHandlerDelegate <NSObject>

@optional

@required
/**
 *
 */
- (void)didReceivedXunLianResponseMessageWithHexString:(NSString *) hexString;

- (void)socketHandlerErrorWithModel:(XLResponseModel *)errorModel;
@end

NS_ASSUME_NONNULL_BEGIN

@interface XLSocketHandler : NSObject
/**
 * socket连接状态
 */
@property (nonatomic, assign) XLSocketConnectStatus connectStatus;

/**
 * 长连接通信单例
 */
+ (instancetype)shareInstance;

/**
 * 连接服务器端口
 */
- (void)connectServerHostWithSuccessBlock:(HandleResultBlock) successCB
                              failedBlock:(HandleResultBlock) failedCB;
/**
 * 主动断开连接
 */
- (void)executeDisconnectServer;

/**
 * 添加代理
 */
- (void)addDelegate:(id<XLSocketHandlerDelegate>)delegate delegateQueue:(dispatch_queue_t)queue;
/**
 * 移除代理
 */
- (void)removeDelegate:(id<XLSocketHandlerDelegate>)delegate;
/**
 * 发送管理类消息
 */
/**
 * 发送交易类消息
 */
- (void)sendMessageWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
