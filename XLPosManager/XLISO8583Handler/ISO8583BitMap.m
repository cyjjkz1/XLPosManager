//
//  ISO8583BitMap.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/3.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "ISO8583BitMap.h"
#import "XLError.h"
//#import "NSString+Transform.h"
#import "TransformNSString.h"

#define kBitmap_Length 64
@interface ISO8583BitMap ()
/**
 * 二进制字符串
 */
@property (nonatomic, strong) NSMutableString *bin_bitMapconent;

@end


@implementation ISO8583BitMap
- (instancetype)init{
    self = [super init];
    if (self) {
        NSMutableString *tempMutableStr = [[NSMutableString alloc] init];
        //初始化 64全部为0 没有数据，后面根绝业务的要求，填充对应的位
        for (int i = 0; i < kBitmap_Length; i++) {
            [tempMutableStr appendString:@"0"];
        }
        self.bin_bitMapconent = tempMutableStr;
        XLLog(@"bit map binary str = %@", self.bin_bitMapconent);
    }
    return self;
}
- (void)setupBitOfBitmapWithFieldID:(NSUInteger) fieldID
{
    int maxField = kBitmap_Length;
    // 迅联采用64位位图
    if (fieldID > 1 && fieldID <= maxField) {// 主位图的第一位是标识是否使用扩展位图的，迅联不用，要用再说
        [self.bin_bitMapconent replaceCharactersInRange:NSMakeRange(fieldID-1, 1) withString:@"1"];
        XLLog(@"bit map binary str = %@", self.bin_bitMapconent);
    }else{
        XLLog(@"位图设置错误, fieldID超出了主位图的大小");
        return;
    }
}
- (NSString *)createCurrentBitmapContent
{
    NSString *hexBitmap = [TransformNSString BinaryToHex:self.bin_bitMapconent];
    XLLog(@"hexBitmap = %@", hexBitmap);
    return hexBitmap;
}




#pragma mark - 解析、创建位图
- (void)setUpFieldWithBitMap:(uint64_t *) bitmap fieldNumber:(int) fieldNumber{
    uint64_t temp = 1;
    *bitmap = *bitmap | (temp << (fieldNumber -1));
}
//- (NSArray *)filedsWithBitMap:(NSData *) iso8583MsgData
//{
//    //取前64位 位图
//    NSInteger len = iso8583MsgData.length;
//    NSData *bitmapData = [iso8583MsgData subdataWithRange:NSMakeRange(0, 8)];
//    const char *byte = [bitmapData bytes];
//    return nil;
//}
- (NSData *)byteFromUInt64:(uint64_t) val{
    unsigned char valChar[8];
    valChar[0] = 0xff & val;
    valChar[1] = (0xff00 & val) >> 8;
    valChar[2] = (0xff0000 & val) >> 16;
    valChar[3] = (0xff000000 & val) >> 24;
    valChar[4] = (0xff00000000 & val) >> 32;
    valChar[5] = (0xff0000000000 & val) >> 40;
    valChar[6] = (0xff000000000000 & val) >> 48;
    valChar[7] = (0xff00000000000000 & val) >> 56;
    
    return [NSData dataWithBytes:valChar length:8];
}
- (uint64_t)uint64FromNSData:(NSData *) fdata
{
    //    NSAssert(fData.length == 4, @"uint32FromBytes: (data length != 4)");
    //    NSData *data = [self dataWithReverse:fData];
    //
    //    uint32_t val0 = 0;
    //    uint32_t val1 = 0;
    //    uint32_t val2 = 0;
    //    uint32_t val3 = 0;
    //    [data getBytes:&val0 range:NSMakeRange(0, 1)];
    //    [data getBytes:&val1 range:NSMakeRange(1, 1)];
    //    [data getBytes:&val2 range:NSMakeRange(2, 1)];
    //    [data getBytes:&val3 range:NSMakeRange(3, 1)];
    //
    //    uint32_t dstVal = (val0 & 0xff) + ((val1 << 8) & 0xff00) + ((val2 << 16) & 0xff0000) + ((val3 << 24) & 0xff000000);
    return 1;
}

@end
