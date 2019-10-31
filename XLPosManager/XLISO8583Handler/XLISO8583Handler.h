//
//  XLISO8583Handler.h
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/2.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XLResponseModel.h"

NS_ASSUME_NONNULL_BEGIN
@interface XLISO8583Handler : NSObject
/**
 * 单例
 */
+ (instancetype)shareInstance;
/**
 * 封包
 * param: fieldModel
 */
- (void)packISO8583MessageWithFieldDict:(NSDictionary *) fieldDict completion:(HandleResultBlock) completionCallBack;
/**
 * 解包
 * param: iso8583Msg socket返回的应用数据
 */
- (void)unpackISO8583MesssageWithFieldModel:(NSData *) socketMessageData completion:(HandleResultBlock) completionCallBack;
@end

NS_ASSUME_NONNULL_END
