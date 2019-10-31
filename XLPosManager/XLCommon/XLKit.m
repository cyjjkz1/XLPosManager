//
//  XLKit.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/9.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLKit.h"
#include "xlenc.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSData+AESAdditions.h"
#import "NSString+Transform.h"
#import "TransformNSString.h"

@implementation XLKit
/**
 *  @brief 加密tmk
 *  @param hexTmk  16进制tmk
 *  @return  随机密钥校验值
 */
+ (NSString *)calculateCiphertextWithTmk:(NSString *) hexTmk
{
    char *in_c = (char *)[hexTmk UTF8String];
    char *key = "0123456789ABCDEFFEDCBA9876543210";
    char result[256] = {0};
    
    int ret = genencTmk(key, result, in_c);
    if (ret == 0) {
        NSString *cipherTmk = [[NSString stringWithUTF8String:result] uppercaseString];
        return cipherTmk;
    }
    return nil;
}
/**
 *  @brief 获取随机密钥校验值
 *  @param hexStringKey    随机密钥
 *  @return  随机密钥校验值
 */
+ (NSString *)createCheckValueWithRandomKey:(NSString *)hexStringKey {
    char *key = (char *)[hexStringKey UTF8String];
    char resultPackData[256] = { 0 };
    genchcv_x(key, resultPackData);
    NSString *des3Content = [NSString stringWithUTF8String:resultPackData];
    NSString *checkValue = [des3Content substringWithRange:NSMakeRange(0, 8)];
    return checkValue;
}

/**
 *  @brief 获取公钥加密的对称密钥
 *  @param content     加密类容
 *  @param publicKey   加密公钥
 *  @param keyExponent 加密指数
 */
+ (NSString *)encryptWithContent:(NSString *)content publicKey:(NSString *) publicKey keyExponent:(NSString *)keyExponent {
    char resultPackData[256] = { 0 };
    int resultPackDataLen = 0;
    
    NSData *clientKeyData = [TransformNSString hexToBytes:content];
    
    // 获取公钥
    NSUInteger exponent = [TransformNSString hexToUInteger:keyExponent];
    const char *pubKeyChar = [publicKey UTF8String];
    qfsdk_enc_with_pub_key((char *)[clientKeyData bytes],
                           (int)[clientKeyData length],
                           pubKeyChar,
                           exponent,
                           resultPackData,
                           &resultPackDataLen);
    NSData *adata = [NSData dataWithBytes:resultPackData length:resultPackDataLen];
    return [[TransformNSString hexStringFromData:adata] uppercaseString];
}

/**
 *  @brief 获取随机密钥
 *  @param key 参与随机密钥计算
 *  @return 返回32位随机密钥
 */
+ (NSString *)getRandomClientKey:(NSString *)key;
{
//    NSString *aesStr = nil;
//    NSData *aesData = [[NSData alloc] init];
//    srand([[NSDate date] timeIntervalSinceNow]);
//    NSString *strSeed = [NSString stringWithFormat:@"%dalex%@", arc4random(), [[NSDate date] description]];
//    aesData = [aesData AES256DecryptWithKey:strSeed];
//    aesStr = [TransformNSString hexStringFromData:aesData];
    NSString *retStr1 = [XLKit MD5:[NSString stringWithFormat:@"%dalex%@%d", arc4random(), [[NSDate date] description], arc4random() % 255 - 12]];
    NSData *retDat = [TransformNSString hexToBytes:retStr1];
    //这是我AES private key的明文,不过是hex2string过的,所以使用的时候需要string2hex一下
    NSString *randomStr = [[TransformNSString hexStringFromData:retDat] uppercaseString];
    return randomStr;
}

+ (NSString *)MD5:(NSString *) content; {
    if (!content) {
        return @"1";
    }
    
    const char *cStr = [content UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    return [[NSString stringWithFormat:
             @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
             result[0], result[1], result[2], result[3],
             result[4], result[5], result[6], result[7],
             result[8], result[9], result[10], result[11],
             result[12], result[13], result[14], result[15]
             ] lowercaseString];
}
+ (NSString *)genClientSn {
    NSDate *datenow = [NSDate date];
    NSString *HHmmssCurrentTime = [[XLKit HHmmssFormatter] stringFromDate:datenow];
    return HHmmssCurrentTime;
}
+ (NSDateFormatter *)yyyyMMddhhmmssFormatter{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    [formatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
    return formatter;
}
+ (NSDateFormatter *)HHmmssFormatter{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    [formatter setDateFormat:@"HHmmss"];
    return formatter;
}
+ (NSDateFormatter *)yMdHmsFormatter{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    return formatter;
}
+ (NSDateFormatter *)yyyyFormatter{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    [formatter setDateFormat:@"yyyy"];
    return formatter;
}
+ (BOOL)isIntegerValue:(NSString *)str{
    NSString * regex        = @"[0-9]*";;
    NSPredicate * pred      = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    BOOL isMatch            = [pred evaluateWithObject:str];
    if (isMatch) {
        return YES;
    }else{
        return NO;
    }
}
@end
