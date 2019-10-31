//
//  XLISO8583Field.h
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/2.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XLResponseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface XLISO8583Field : NSObject
/**
 * 数据域编号
 */
@property (nonatomic, assign) NSUInteger filedNum;

/**
 * 最大长度
 */
@property (nonatomic, assign) NSUInteger maxLength;

/**
 * 数据空间大小类型 固定长度/2位变长/3位变长(FIXED_LENTTH/VARIABLE_2_LENGTH/VARIABLE_3_LENGTH)
 */
@property (nonatomic, copy) NSString *lengthType;

/**
 * 数据类型 BCD/BINARY/ASCII
 */
@property (nonatomic, copy) NSString *dataType;
/**
 * 数据类型 BCD压缩 左靠/右靠(L/R)
 */
@property (nonatomic, copy) NSString *bcdCompressType;

/**
 * 初始化数据域的属性
 *
 *
 */
+ (instancetype)initWithFieldNum:(NSUInteger) filedNum
                       maxLength:(NSUInteger) maxLength
                      lengthType:(NSString *) lengthType
                        dataType:(NSString *) dataType
                 bcdCompressType:(NSString *)bcdCompressType;


/**
 *  根据域名定义描述，填装ISO8583单个域内容
 *
 *  @param filedContent 单个元素内的报文内容
 *  @return 处理后的内容
 */
- (XLResponseModel*) createFieldDataWithContent:(NSString*) filedContent;
@end

NS_ASSUME_NONNULL_END
