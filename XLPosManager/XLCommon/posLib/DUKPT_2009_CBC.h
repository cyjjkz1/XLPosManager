//
//  DUKPT_2009_CBC.h
//  DUKPT_2009_CBC_OC
//
//  Created by zengqingfu on 15/3/12.
//  Copyright (c) 2015年 zengqingfu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
@interface DUKPT_2009_CBC : NSObject
+ (NSData *)GetPinKeyVariantKsn:(NSData *) ksn ipek: (NSData *)ipek;
+ (NSData *) GenerateIPEKksn:(NSData *) ksn bdk: (NSData *)bdk;
+ (NSData *) GetDataKeyKsn:(NSData *) ksn ipek: (NSData *)ipek;
+ (NSData *)GetDataKeyVariantKsn:(NSData *) ksn ipek: (NSData *)ipek;
// 3DES encryption and decryption
+ (NSData*)DESOperation:(CCOperation)operation algorithm:(CCAlgorithm)algorithm keySize:(size_t)keySize data:(NSData*)data key:(NSData*)key;
// 3DESdecryption CBC
+ (NSData*)DESOperationCBCdata:(NSData*)data key:(NSData*)key;
// Hexadecimal string to byte array
+(NSData *)parseHexStr2Byte: (NSString*)hexString;
//Byte array to hex string
+ (NSString*)parseByte2HexStr: (NSData *)data;
+ (NSString *)dataFill:(NSString *)dataStr;
/*
 mData:pinblock
 cardNum: cardNumber
 */
//pin decrypt function
+(NSString*)decryptionPinblock:(NSString*)ksn BDK:(NSString*)mBDK data:(NSString*)mData andCardNum:(NSString *)cardNum;
//cardNumber decrypt function
+(NSString*)decryptionTrackDataCBC:(NSString*)ksn BDK:(NSString*)mBDK data:(NSString*)mData;

@end
