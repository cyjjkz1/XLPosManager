//
//  TransformNSString.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/10/31.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "TransformNSString.h"

@implementation TransformNSString

+(NSData*)hexToBytes:(NSString *)str {
    NSMutableData* data = [NSMutableData data];
    
    for (int idx = 0; idx+2 <= str.length; idx+=2) {
        NSRange range = NSMakeRange(idx, 2);
        NSString* hexStr = [str substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    return data;
}

+ (NSString *)hexStringFromData:(NSData *)data{
    NSMutableString *str = [NSMutableString string];
    Byte *byte = (Byte *)[data bytes];
    for (int i = 0; i<[data length]; i++) {
        // byte+i为指针
        [str appendString:[self stringFromByte:*(byte+i)]];
    }
    return str;
}

+ (NSString *)stringFromByte:(Byte)byteVal{
    NSMutableString *str = [NSMutableString string];
    //取高四位
    Byte byte1 = byteVal>>4;
    //取低四位
    Byte byte2 = byteVal & 0xf;
    //拼接16进制字符串
    [str appendFormat:@"%x",byte1];
    [str appendFormat:@"%x",byte2];
    return str;
}

/**
 *  hex字符串转为ASC码  00 --> 3030
 *
 *  @param hex hex字符串
 *
 *  @return 转码后的ASC字符串
 */
+ (NSString *)hexToAsc:(NSString *)hex{
    hex = hex.uppercaseString;
    char szData[1024]={0};
    const char *pBytes =  [hex UTF8String];
    if(NULL != pBytes) {
        for(int i=0; i<hex.length; i++) {
            char tmp[16];
            sprintf(tmp, "%0.2X",pBytes[i]);
            strcat(szData, tmp);
        }
        return [NSString stringWithFormat:@"%s",szData];
    }
    return nil;
}

/**
 *  ASC吗转为Hex字符串  3030 --> 00
 *
 *  @param asc ASC字符串
 *
 *  @return 转码后的Hex字符串
 */
+ (NSString *)ascToHex:(NSString *)asc{
    char szData[1024]={0};
    const char *ascBytes =  [asc UTF8String];
    if (NULL != ascBytes) {
        [self ascToHex:ascBytes len:asc.length outAscii:szData];
        
        return [NSString stringWithFormat:@"%s",szData];
    }
    return nil;
}

+ (void)ascToHex:(const char *)hex len:(NSUInteger)length outAscii:(char *)ascii {
    for (int i = 0; i < length; i += 2) {
        if (hex[i] >= '0' && hex[i] <= '9')
            ascii[i / 2] = (hex[i] - '0') << 4;
        else if (hex[i] >= 'a' && hex[i] <= 'z')
            ascii[i / 2] = (hex[i] - 'a' + 10) << 4;
        else if (hex[i] >= 'A' && hex[i] <= 'Z')
            ascii[i / 2] = (hex[i] - 'A' + 10) << 4;
        
        if (hex[i + 1] >= '0' && hex[i + 1] <= '9')
            ascii[i / 2] += hex[i + 1] - '0';
        else if (hex[i + 1] >= 'a' && hex[i + 1] <= 'z')
            ascii[i / 2] += hex[i + 1] - 'a' + 10;
        else if (hex[i + 1] >= 'A' && hex[i + 1] <= 'Z')
            ascii[i / 2] += hex[i + 1] - 'A' + 10;
    }
}

/**
 *  十六进制字符串转二进制字符串
 *
 *  @param hex 十六进制字符串
 *
 *  @return 二进制字符串
 */
+(NSString *)HexToBinary:(NSString *)hex {
    hex = hex.uppercaseString;
    NSMutableDictionary *hexDic = [[NSMutableDictionary alloc] init];
    hexDic = [[NSMutableDictionary alloc] initWithCapacity:16];
    [hexDic setObject:@"0000" forKey:@"0"];
    [hexDic setObject:@"0001" forKey:@"1"];
    [hexDic setObject:@"0010" forKey:@"2"];
    [hexDic setObject:@"0011" forKey:@"3"];
    [hexDic setObject:@"0100" forKey:@"4"];
    [hexDic setObject:@"0101" forKey:@"5"];
    [hexDic setObject:@"0110" forKey:@"6"];
    [hexDic setObject:@"0111" forKey:@"7"];
    [hexDic setObject:@"1000" forKey:@"8"];
    [hexDic setObject:@"1001" forKey:@"9"];
    [hexDic setObject:@"1010" forKey:@"A"];
    [hexDic setObject:@"1011" forKey:@"B"];
    [hexDic setObject:@"1100" forKey:@"C"];
    [hexDic setObject:@"1101" forKey:@"D"];
    [hexDic setObject:@"1110" forKey:@"E"];
    [hexDic setObject:@"1111" forKey:@"F"];
    NSMutableString *binaryString=[[NSMutableString alloc] init];
    for (int i=0; i<[hex length]; i++) {
        NSString *key = [hex substringWithRange:NSMakeRange(i, 1)];
        [binaryString appendString:[NSString stringWithFormat:@"%@",[hexDic objectForKey:key]]];
    }
    return binaryString;
}

/**
 *  2进制字符串转16进制字符串,如 11110011 -> F3
 *
 *  @param Binary 二进制字符串
 *
 *  @return 16进制字符串
 */
+(NSString *)BinaryToHex:(NSString *)Binary {
    if ([Binary length]%4 == 0) {
        NSMutableDictionary *hexDic = [[NSMutableDictionary alloc] init];
        hexDic = [[NSMutableDictionary alloc] initWithCapacity:16];
        [hexDic setObject:@"0" forKey: @"0000"];
        [hexDic setObject:@"1" forKey: @"0001"];
        [hexDic setObject:@"2" forKey: @"0010"];
        [hexDic setObject:@"3" forKey: @"0011"];
        [hexDic setObject:@"4" forKey: @"0100"];
        [hexDic setObject:@"5" forKey: @"0101"];
        [hexDic setObject:@"6" forKey: @"0110"];
        [hexDic setObject:@"7" forKey: @"0111"];
        [hexDic setObject:@"8" forKey: @"1000"];
        [hexDic setObject:@"9" forKey: @"1001"];
        [hexDic setObject:@"A" forKey: @"1010"];
        [hexDic setObject:@"B" forKey: @"1011"];
        [hexDic setObject:@"C" forKey: @"1100"];
        [hexDic setObject:@"D" forKey: @"1101"];
        [hexDic setObject:@"E" forKey: @"1110"];
        [hexDic setObject:@"F" forKey: @"1111"];
        NSMutableString *hexString=[[NSMutableString alloc] init];
        for (int i=0; i<[Binary length]/4; i++) {
            NSString *key = [Binary substringWithRange:NSMakeRange(4*i, 4)];
            //            hexString = [NSString stringWithFormat:@"%@%@",binaryString,[NSString stringWithFormat:@"%@",[hexDic objectForKey:key]]];
            [hexString appendString:[NSString stringWithFormat:@"%@",[hexDic objectForKey:key]]];
        }
        return hexString;
    }else
        return nil;
}
+(NSData *)encodeBCD:(NSString *) content{
    if (content.length % 2 != 0) {
        return nil;
    }
    NSMutableData *hexData = [NSMutableData data];
    uint8_t bytes[1] = {0};
    for (int i = 0; i < content.length; i = i+2) {
        uint8_t first = [[content substringWithRange:NSMakeRange(i, 1)] intValue];
        uint8_t second = [[content substringWithRange:NSMakeRange(i+1, 1)] intValue];
        uint8_t temp = 0;
        temp = temp | first;
        temp  = temp << 4;
        temp = temp | second;
        bytes[0] = temp;
        [hexData appendBytes:bytes length:1];
    }
    return hexData;
}
+ (NSUInteger)hexToUInteger:(NSString *)hexString
{
    
    NSDictionary *hexDic = @{
                             @"0": @(0),
                             @"1": @(1),
                             @"2": @(2),
                             @"3": @(3),
                             @"4": @(4),
                             @"5": @(5),
                             @"6": @(6),
                             @"7": @(7),
                             @"8": @(8),
                             @"9": @(9),
                             @"A": @(10),
                             @"B": @(11),
                             @"C": @(12),
                             @"D": @(13),
                             @"E": @(14),
                             @"F": @(15),
                             @"a": @(10),
                             @"b": @(11),
                             @"c": @(12),
                             @"d": @(13),
                             @"e": @(14),
                             @"f": @(15)
                             };
    
    if (!hexString || hexString.length <= 0) {
        return 0;
    }
    NSUInteger ret = 0;
    for (NSUInteger i = 0; i < hexString.length; i++) {
        NSString *hex = [hexString substringWithRange:NSMakeRange(i, 1)];
        NSUInteger cur = [hexDic[hex] integerValue];
        ret += (NSUInteger)(cur * pow(16, hexString.length - i - 1));
    }
    return ret;
    
    
}

+(NSString *)convertStringToGBKStr:(NSString *)str
{
    NSMutableArray * array=[[NSMutableArray alloc]init];
    //转换成UTF-8
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [str dataUsingEncoding: enc];
    Byte * bytes = (Byte *)[data bytes];
    for(NSUInteger i=0;i<data.length;i++)
    {
        [array addObject:[NSString stringWithFormat:@"%X",bytes[i]]];
    }
    return [array componentsJoinedByString:@""];
    
}
@end
