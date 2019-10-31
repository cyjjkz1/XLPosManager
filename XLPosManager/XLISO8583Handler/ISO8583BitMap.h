//
//  ISO8583BitMap.h
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/3.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import <Foundation/Foundation.h>
/**
 * 生成bitmap
 * 1.初始化生成对应的64位全0二进制字符串
 * 2.通过field ID修改 ISO8583 数据域对应的位
 * 3.获取当前位图 8个BYTE 对应的字符串
 */
NS_ASSUME_NONNULL_BEGIN

@interface ISO8583BitMap : NSObject
/**
 * 根据filed ID 设置bitmap的BIT位
 *
 */
- (void)setupBitOfBitmapWithFieldID:(NSUInteger) fieldID;

/**
 * 生成当前的十六进制字符串
 */
- (NSString *)createCurrentBitmapContent;


//
//- (void)setUpFieldWithBitMap:(uint64_t *) bitmap fieldNumber:(int) fieldNumber;
//- (NSData *)byteFromUInt64:(uint64_t) val;
//- (NSArray *)filedsWithBitMap:(NSData *) iso8583MsgData;
@end

NS_ASSUME_NONNULL_END
