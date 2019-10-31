//
//  XLISO8583FieldConstant.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/2.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLISO8583Field.h"
#import "XLError.h"
//#import "NSString+Transform.h"
#import "TransformNSString.h"
@implementation XLISO8583Field

+ (instancetype)initWithFieldNum:(NSUInteger) filedNum
                       maxLength:(NSUInteger) maxLength
                      lengthType:(NSString *) lengthType
                        dataType:(NSString *) dataType
                 bcdCompressType:(NSString *)bcdCompressType
{
    XLISO8583Field *filed = [[XLISO8583Field alloc] init];
    if (filed) {
        filed.filedNum = filedNum;
        filed.maxLength = maxLength;
        if (lengthType == nil) {
            XLLog(@"没有设置该数据域的长度类型，请按照要求设置");
        }else{
            filed.lengthType = lengthType;
            filed.dataType = dataType;
            filed.bcdCompressType = bcdCompressType;
        }
    }
    return filed;
}

- (XLResponseModel*) createFieldDataWithContent:(NSString*) filedContent;
{
    //第一步: 校验数据
    XLResponseModel *model = nil;

    if ([self.dataType isEqualToString:@"BCD"]) {
        if (filedContent.length <= 0 || filedContent.length > self.maxLength) {
            model = [[XLResponseModel alloc] init];
            model.respCode = RESP_PACK_FIELD_LENGTH_ERROR;
            model.respMsg = [NSString stringWithFormat:@"Field %ld, BCD %ld %@, length = %ld",self.filedNum, self.maxLength, self.lengthType, [filedContent length]];
            return model;
        }
    }else if([self.dataType isEqualToString:@"ASCII"]){
        if (filedContent.length <= 0 || filedContent.length > self.maxLength) {
            model = [[XLResponseModel alloc] init];
            model.respCode = RESP_PACK_FIELD_LENGTH_ERROR;
            model.respMsg = [NSString stringWithFormat:@"Field %ld, var ASCII %ld %@, length = %ld",self.filedNum, self.maxLength, self.lengthType, [filedContent length]];
            return model;
        }
    }else{ //BINARY
        if (filedContent.length <= 0 || filedContent.length/2 > self.maxLength) {
            model = [[XLResponseModel alloc] init];
            model.respCode = RESP_PACK_FIELD_LENGTH_ERROR;
            model.respMsg = [NSString stringWithFormat:@"Field %ld, var BINARY %ld %@, length = %ld",self.filedNum, self.maxLength, self.lengthType, [filedContent length]];
            return model;
        }
    }
    
    //第二步: 根据当前的域属性封装数据
    NSString *tempfieldContent = [filedContent copy];
    if ([self.lengthType isEqualToString:@"FIXED_LENTTH"]) {// 定长
        if ([self.dataType isEqualToString:@"BCD"]) {
            //先补位，再BCD编码
            NSMutableString *srcString = [[NSMutableString alloc] init];
            NSUInteger bcdLength = self.maxLength % 2 == 0 ? self.maxLength : self.maxLength + 1;
            for (int i = 0; i < bcdLength; i++) {
                [srcString appendString:@"0"];
            }
            if ([self.bcdCompressType isEqualToString:@"L"]) {
                [srcString replaceCharactersInRange:NSMakeRange(0, [tempfieldContent length]) withString:tempfieldContent];
            }else{
                [srcString replaceCharactersInRange:NSMakeRange([srcString length]-[tempfieldContent length], [tempfieldContent length]) withString:tempfieldContent];
            }
            NSDictionary *retDict = @{@"hex_pack_str": srcString};
            model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Success" respData:retDict];
        }else if([self.dataType isEqualToString:@"ASCII"]){
            NSData *handleData = [tempfieldContent dataUsingEncoding:NSASCIIStringEncoding];
            NSDictionary *retDict = @{@"hex_pack_str": [TransformNSString hexStringFromData:handleData]};
            model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Success" respData:retDict];
        }else if([self.dataType isEqualToString:@"BINARY"]){
            //处理二进制
            NSDictionary *retDict = @{@"hex_pack_str": tempfieldContent};
            model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Success" respData:retDict];
        }
    }else if([self.lengthType isEqualToString:@"VARIABLE_2_LENGTH"] || [self.lengthType isEqualToString:@"VARIABLE_3_LENGTH"]){ // 两位变长和三位变长
        //长度两位 两位边长 1个字节表示长度  三位变长 2个字节表示长度
        NSString *dataLengthString = [NSString stringWithFormat:@"%lu", [filedContent length]];
        if ([self.dataType isEqualToString:@"BINARY"]) {
            dataLengthString = [NSString stringWithFormat:@"%lu", [filedContent length]/2];
        }
        NSData *lenData = nil;
        if ([self.lengthType isEqualToString:@"VARIABLE_2_LENGTH"]) {
            NSMutableString *lenPrefix = [[NSMutableString alloc] initWithString:@"00"];//右靠BCD后就一个字节
            [lenPrefix replaceCharactersInRange:NSMakeRange(2-[dataLengthString length], [dataLengthString length]) withString:dataLengthString];
            lenData = [TransformNSString hexToBytes:lenPrefix];
        }else{
            NSMutableString *lenPrefix = [NSMutableString stringWithFormat:@"0000"];//右靠BCD后就两个字节
            [lenPrefix replaceCharactersInRange:NSMakeRange(4-[dataLengthString length], [dataLengthString length]) withString:dataLengthString];
            lenData = [TransformNSString hexToBytes:lenPrefix];
        }
        
        //数据处理
        NSMutableData *retData = [NSMutableData dataWithData:lenData];
        if ([self.dataType isEqualToString:@"BCD"]) {
            if(tempfieldContent.length % 2 == 0){//不用补位
                
            }else{//需要补位
                if([self.bcdCompressType isEqualToString:@"L"]){//左靠右边补位
                    tempfieldContent = [tempfieldContent stringByAppendingString:@"0"];
                }else{//右靠左边补位
                    tempfieldContent = [@"0" stringByAppendingString:tempfieldContent];
                }
            }
            [retData appendData:[TransformNSString hexToBytes:tempfieldContent]];
            
            NSDictionary *retDict = @{@"hex_pack_str": [TransformNSString hexStringFromData:retData]};
            model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Success" respData:retDict];
            
        }else if([self.dataType isEqualToString:@"ASCII"]){
//            NSData *handleData = [tempfieldContent dataUsingEncoding:NSASCIIStringEncoding];
            if (self.filedNum == 63) {
                NSData *handleData = [tempfieldContent dataUsingEncoding:NSASCIIStringEncoding];
                [retData appendData:handleData];
                NSDictionary *retDict = @{@"hex_pack_str": [TransformNSString hexStringFromData:retData]};
                model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Success" respData:retDict];
            }else{
                NSData *handleData = [TransformNSString hexToBytes:tempfieldContent];
                [retData appendData:handleData];
                NSDictionary *retDict = @{@"hex_pack_str": [TransformNSString hexStringFromData:retData]};
                model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Success" respData:retDict];
            }
        } if([self.dataType isEqualToString:@"BINARY"]){
            //处理二进制
            [retData appendData:[TransformNSString hexToBytes:tempfieldContent]];
            NSDictionary *retDict = @{@"hex_pack_str": [TransformNSString hexStringFromData:retData]};
            model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Success" respData:retDict];
        }
    }
    return model;
}

@end
