//
//  NSData+AESAdditions.h
//  Apps
//
//  Created by Alex on 12-9-13.
//  Copyright (c) 2012年 QFPay. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (AESAdditions)
- (NSData *)AES256EncryptWithKey:(NSString *)key;
- (NSData *)AES256DecryptWithKey:(NSString *)key;
@end
