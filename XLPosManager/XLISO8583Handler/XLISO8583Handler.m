//
//  XLISO8583Handler.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/2.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLISO8583Handler.h"
#import "ISO8583BitMap.h"
#import "XLISO8583Field.h"
//#import "NSString+Transform.h"
#import "TransformNSString.h"
#import "XLError.h"

@interface XLISO8583Handler()
@property (nonatomic, strong) NSDictionary *iso8583FieldsAttributes;
@property (nonatomic, strong) ISO8583BitMap *iso8583Bitmap;
@property (nonatomic, strong) NSMutableArray *fieldsDataList;
@property (nonatomic, copy)   HandleResultBlock completionHandleBlock;
@end


@implementation XLISO8583Handler
#pragma mark - reset
- (void)resetHandler{
    [XLISO8583Handler shareInstance].iso8583Bitmap  = [[ISO8583BitMap alloc] init];
    [[XLISO8583Handler shareInstance].fieldsDataList removeAllObjects];
}
#pragma mark - 封包
- (void)packISO8583MessageWithFieldDict:(NSDictionary *) fieldDict completion:(HandleResultBlock) completionCallBack
{
    // TPDU+报文头+消息类型 + 位图 + iso8583
    XLResponseModel *model = nil;
    if (fieldDict && [fieldDict count] > 0) {
        // 遍历数据域 设置位图 处理数据
        // 对key排序，方便后面按照顺序设置位图
        NSArray *allFieldSortedKeys = [fieldDict.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSUInteger value1 = [obj1 integerValue];
            NSUInteger value2 = [obj2 integerValue];
            if (value1 > value2) {
                return NSOrderedDescending;
            }else if (value1 == value2){
                return NSOrderedSame;
            }else{
                return NSOrderedAscending;
            }
        }];
        [[XLISO8583Handler shareInstance] resetHandler];
        for (int i = 0; i < [allFieldSortedKeys count]; i++) {
            // 获取域的content
            NSString *key = allFieldSortedKeys[i];
            NSString *fieldValue = fieldDict[key];
            // 获取域的属性、并初始化
            NSDictionary *fieldDict = [XLISO8583Handler shareInstance].iso8583FieldsAttributes[key];
            
            XLISO8583Field *filedAttributes = [XLISO8583Field initWithFieldNum:[fieldDict[@"fieldID"] integerValue]
                                                                     maxLength:[fieldDict[@"maxLength"] integerValue]
                                                                    lengthType:fieldDict[@"lengthType"]
                                                                      dataType:fieldDict[@"dataType"]
                                                               bcdCompressType:fieldDict[@"bcdCompressType"]];
            // 创建域data
            XLResponseModel *createFieldDataModel = [filedAttributes createFieldDataWithContent:fieldValue];
            if ([createFieldDataModel.respCode isEqualToString:@"0000"]) { //处理数据成功
                NSString *hexStr = createFieldDataModel.data[@"hex_pack_str"];
                NSData *fieldData = [TransformNSString hexToBytes:hexStr];
                XLLog(@"封包结果 %@ 域 hex str = %@", key, [TransformNSString hexStringFromData:fieldData]);
                [[XLISO8583Handler shareInstance].fieldsDataList addObject:fieldData];
                // 设置bitmap中域对应的位，不处理0, 这个是消息类型和bitmap无关
                if (i != 0) {
                    [[XLISO8583Handler shareInstance].iso8583Bitmap setupBitOfBitmapWithFieldID:[key integerValue]];
                }
            }else{//处理数据失败了, 跳出去抛出错误消息
                model = createFieldDataModel;
                break;
            }
        }
        //只有当处理域数据数据中的个数和待处理域的个数相等，才是所有数据处理成功，不相等返回错误model
        if ([[XLISO8583Handler shareInstance].fieldsDataList count] == [fieldDict count]) {
            // 处理完各域的数据 获取bitmap
            NSString *bitMapContent = [[XLISO8583Handler shareInstance].iso8583Bitmap createCurrentBitmapContent];
            // 消息类型 + 位图 + 域数据 数组中0位是消息类型 所以位图插在1位
            NSData *hexBitmapData = [TransformNSString hexToBytes:bitMapContent];
            [self.fieldsDataList insertObject:hexBitmapData atIndex:1];
 
            // 拼接数据
            NSMutableData *iso8583AllData = [NSMutableData data];
            for (int m = 0; m < [self.fieldsDataList count]; m++) {
                [iso8583AllData appendData:self.fieldsDataList[m]];
            }
            
            // 拼接长度 (tpdu + header)长度为 + iso8583数据
            NSUInteger messageLength = [iso8583AllData length] + 11;
            if (messageLength <= 65535) {
                NSString *iso8583HexStr = [[TransformNSString hexStringFromData:iso8583AllData] uppercaseString];
                XLLog(@"封包结果 hex str = %@", iso8583HexStr);
                NSString *hexLenStr = [NSString stringWithFormat:@"%lx", messageLength];
                NSString *tpduHexStr = @"6001090000";
                NSString *headerHexStr = @"600100000000";
                if ([fieldDict[@"55"] description].length > 0) {
                    //IC卡交易
                    headerHexStr = @"610100000000";
                }
                NSMutableString *messageHexLength = [[NSMutableString alloc] initWithString:@"0000"];
                [messageHexLength replaceCharactersInRange:NSMakeRange(4 - hexLenStr.length, hexLenStr.length) withString:hexLenStr];
                NSMutableData *sockData = [NSMutableData dataWithData:[TransformNSString hexToBytes:messageHexLength]]; //报文长度
                [sockData appendData:[TransformNSString hexToBytes:tpduHexStr]];// 追加tpdu
                [sockData appendData:[TransformNSString hexToBytes:headerHexStr]];// 追加报文头
                NSString *messageHead = [[TransformNSString hexStringFromData:sockData] uppercaseString];
                [sockData appendData:iso8583AllData];// 追加iso8583报文
                NSString *socketDataHexStr = [[TransformNSString hexStringFromData:sockData] uppercaseString];
                XLLog(@"socket message = %@", socketDataHexStr);
                NSDictionary *retDict = @{@"socket_hex_data": socketDataHexStr,
                                          @"iso8583_hex_data": iso8583HexStr,
                                          @"msg_head_data": messageHead
                                          };
                model = [XLResponseModel createRespMsgWithCode:@"0000" respMsg:@"成功" respData:retDict];
                completionCallBack(model);
            }else{
                //封包长度异常
                model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"Pack length error" respData:@{}];
                completionCallBack(model);
            }
 
        }else{
            //在循环跳出的时候已经获取到了错误model 直接返回即可
            completionCallBack(model);
        }
        
    }else{
        model = [XLResponseModel createRespMsgWithCode:RESP_PACK_PARAM_ERROR respMsg:@"Pack param error" respData:@{}];
        completionCallBack(model);
    }
}

#pragma mark - 解包Socket报文
#pragma mark 验证socket报文的正确性
- (void)unpackISO8583MesssageWithFieldModel:(NSData *) socketMessageData completion:(HandleResultBlock) completionCallBack;
{
    //取前面连个字节为ISO8583的长度，剩下的就是TPDU+报文头+消息类型 + 位图 + iso8583
    //取两个字节为长度
    if (!socketMessageData || socketMessageData.length <= 2) {//前两个字节为长度
        completionCallBack([XLResponseModel createRespMsgWithCode:RESP_MESSAGE_LENGTH_ERROR respMsg:@"Socket message length error" respData:@{}]);
        return;
    }
    NSData *messageLengthData = [socketMessageData subdataWithRange:NSMakeRange(0, 2)];
    NSString *hexLength = [TransformNSString hexStringFromData:messageLengthData];
    NSUInteger isoMesDataLength = [TransformNSString hexToUInteger:hexLength];
    if (socketMessageData.length < 2 + isoMesDataLength) {
        completionCallBack([XLResponseModel createRespMsgWithCode:RESP_CAP_LENGTH_ERROR respMsg:@"CAP socket message length error" respData:@{}]);
        return;
    }
    
    //缓存回调
    self.completionHandleBlock = completionCallBack;
    // 获取CAP报文 TPDU+报文头+消息类型 + 位图 + iso8583
    NSData *capMsgData = [socketMessageData subdataWithRange:NSMakeRange(2, isoMesDataLength)];
    [self unpackCAPMessage:capMsgData];
    
}
#pragma mark 解析CAP报文
- (void)unpackCAPMessage:(NSData *) capMsgData{
    //过来的报文前面还有一个长度传过来的时候已经干掉了
    //TPDU+报文头+消息类型 + 位图 + iso8583
    NSMutableDictionary *respDict = [NSMutableDictionary dictionary];
    if (capMsgData.length > 21) {//大于26个字节 TPDU 5个字节 + 6个字节报文头 + 2个字节的消息类型 + 8个字节的位图
        NSData *TPDUData = [capMsgData subdataWithRange:NSMakeRange(0, 5)];
        NSString *hexTPDU = [TransformNSString hexStringFromData:TPDUData];
        XLLog(@"TPDU = %@", hexTPDU);
        [respDict setValue:hexTPDU forKey:@"tpdu"];
        
        
        NSData *headerData = [capMsgData subdataWithRange:NSMakeRange(5, 6)];
        NSString *hexHeader = [TransformNSString hexStringFromData:headerData];
        XLLog(@"Header = %@", hexHeader);
        [respDict setValue:hexHeader forKey:@"header"];
        
        // 开始ISO8583消息解析
        // 消息类型
        NSData *msgTypeData = [capMsgData subdataWithRange:NSMakeRange(11, 2)];//两个字节的消息类型
        NSString *messageType = [TransformNSString hexStringFromData:msgTypeData];
        XLLog(@"MsgType = %@", messageType);
        [respDict setValue:messageType forKey:@"msg_type"];
        
        
        // 位图
        NSData *bitmapData = [capMsgData subdataWithRange:NSMakeRange(13, 8)];//8个字节64位的位图
        NSString *bitmapHexString = [TransformNSString hexStringFromData:bitmapData];  //16位16进制字符串
        XLLog(@"BitMap hex = %@", bitmapHexString);
        NSString *bitmapBinaryString = [TransformNSString HexToBinary:bitmapHexString];//64位 二进制字符串01组合64位
        XLLog(@"BitMap binary = %@", bitmapBinaryString);
        [respDict setValue:bitmapBinaryString forKey:@"binary_bitmap"];
        
        NSData *fieldsData = [capMsgData subdataWithRange:NSMakeRange(21, capMsgData.length - 21)];
        XLLog(@"FieldData = %@", [TransformNSString hexStringFromData:fieldsData]);
        
        // 根据位图，获取各个域的数据
        NSDictionary *fieldDataDict = [self uppackFieldDataWithBinaryBitMap:bitmapBinaryString iso8583FieldsData:fieldsData];
        [respDict setValue:fieldDataDict forKey:@"fields_data"];
        
        self.completionHandleBlock([XLResponseModel createRespMsgWithCode:@"0000" respMsg:@"Unpack success" respData:respDict]);
    }else{
        //长度不够，但上一步获取CAP的时候已经验证了长度，这个地方不用处理
    }
}
#pragma mark 解析ISO8583 各域数据
- (NSDictionary *)uppackFieldDataWithBinaryBitMap:(NSString *)bitmapBinaryString iso8583FieldsData:(NSData *)fieldsData
{
    // 有效域的数据，先截取出来，再按位图标识域分开，开始切肉
    // 这个里面有定长的和边长的，定长的直接取，变长的先取长度，再取数据
    /**
     *    @{
     *         @"len":@(2), //十进制表示
     *         @"data":@"04335634563456"  //十六进制字符串
     *     }
     */
    NSMutableData *iso8583FieldsData = [NSMutableData dataWithData:fieldsData];
    NSMutableDictionary *fieldDataDict = [NSMutableDictionary dictionary];
    XLLog(@"uppackFieldDataWithBinaryBitMap: iso8583FieldsData:");
    for (int i = 1; i <= [bitmapBinaryString length]; i++) { //从第1域开始，取位的时候减1，以免报错
        NSString *fieldNum = [NSString stringWithFormat:@"%d", i];
        NSString *bitString = [bitmapBinaryString substringWithRange:NSMakeRange(i-1, 1)];
        if ([bitString isEqualToString:@"1"]) {// 说明该域有数据
            NSDictionary *fieldDict = [XLISO8583Handler shareInstance].iso8583FieldsAttributes[fieldNum];
            XLISO8583Field *filedAttributes = [XLISO8583Field initWithFieldNum:[fieldDict[@"fieldID"] integerValue]
                                                                     maxLength:[fieldDict[@"maxLength"] integerValue]
                                                                    lengthType:fieldDict[@"lengthType"]
                                                                      dataType:fieldDict[@"dataType"]
                                                               bcdCompressType:fieldDict[@"bcdCompressType"]];
            if ([filedAttributes.lengthType isEqualToString:@"FIXED_LENTTH"]) {
                if ([filedAttributes.dataType isEqualToString:@"BCD"]) {
                    //是BCD的他妈是压缩了的，取一半
                    NSUInteger len = (filedAttributes.maxLength % 2 == 0) ? filedAttributes.maxLength : (filedAttributes.maxLength + 1);
                    NSData *fieldData = [iso8583FieldsData subdataWithRange:NSMakeRange(0, len / 2)];
                    NSString *fieldHexData = [[TransformNSString hexStringFromData:fieldData] uppercaseString];
                    XLLog(@"第 %d 域: %@", i, fieldHexData);
                    [iso8583FieldsData replaceBytesInRange:NSMakeRange(0, len / 2) withBytes:NULL length:0];
                    [fieldDataDict setValue:fieldHexData forKey:fieldNum];
                }else{
                    NSData *fieldData = [iso8583FieldsData subdataWithRange:NSMakeRange(0, filedAttributes.maxLength)];
                    NSString *fieldHexData = [[TransformNSString hexStringFromData:fieldData] uppercaseString];
                    XLLog(@"第 %d 域: %@", i, fieldHexData);
                    [iso8583FieldsData replaceBytesInRange:NSMakeRange(0, filedAttributes.maxLength) withBytes:NULL length:0];
                    [fieldDataDict setValue:fieldHexData forKey:fieldNum];
                }
            }else if([filedAttributes.lengthType isEqualToString:@"VARIABLE_2_LENGTH"] || [filedAttributes.lengthType isEqualToString:@"VARIABLE_3_LENGTH"]){
                //两位、三位变长、先取长度，再取数据
                NSUInteger lenLength = 1;// 默认两位变长，长度取1个字节
                if([filedAttributes.lengthType isEqualToString:@"VARIABLE_3_LENGTH"]){
                    lenLength = 2; // 三位变长，长度取2个字节
                }
                NSData *lenData = [iso8583FieldsData subdataWithRange:NSMakeRange(0, lenLength)];
                [iso8583FieldsData replaceBytesInRange:NSMakeRange(0, lenLength) withBytes:NULL length:0];//先把长度这块肉切了
                NSString *fieldDataLenString = [TransformNSString hexStringFromData:lenData];
                XLLog(@"第 %d 域, 长度 %@:", i, fieldDataLenString);
                
                // 先判断数据是否经过BCD压缩，BCD压缩过的长度折半取
                // 如果BCD压缩的，要看是左靠还是右靠，左靠切右边，右靠切左边
                NSUInteger dataOriginLength = [fieldDataLenString integerValue];
                if ([filedAttributes.dataType isEqualToString:@"BCD"]) {
                    NSUInteger dataRealLegth = dataOriginLength;
                    if (dataRealLegth % 2 == 1) {
                        dataRealLegth = dataRealLegth + 1;
                    }
                    dataRealLegth = dataRealLegth / 2;
                    NSData *fieldData = [iso8583FieldsData subdataWithRange:NSMakeRange(0, dataRealLegth)];
                    [iso8583FieldsData replaceBytesInRange:NSMakeRange(0, dataRealLegth) withBytes:NULL length:0];
                    NSString *fieldDataHexString = [TransformNSString hexStringFromData:fieldData];
                    if ([filedAttributes.bcdCompressType isEqualToString:@"L"]) {
                        // 左靠切右边
                        fieldDataHexString = [fieldDataHexString substringWithRange:NSMakeRange(0, dataOriginLength)];
                    }else{
                        // 右靠切左边
                        fieldDataHexString = [fieldDataHexString substringWithRange:NSMakeRange(fieldDataHexString.length - dataOriginLength, dataOriginLength)];
                    }
                    XLLog(@"Field %d data: %@", i, fieldDataHexString);
                    [fieldDataDict setValue:[fieldDataHexString uppercaseString] forKey:fieldNum];
                }else{
                    NSUInteger dataRealLegth = dataOriginLength;
                    NSData *fieldData = [iso8583FieldsData subdataWithRange:NSMakeRange(0, dataRealLegth)];
                    [iso8583FieldsData replaceBytesInRange:NSMakeRange(0, dataRealLegth) withBytes:NULL length:0];
                    NSString *fieldDataHexString = [[TransformNSString hexStringFromData:fieldData] uppercaseString];
                    XLLog(@"Field %d data: %@", i, fieldDataHexString);
                    [fieldDataDict setValue:fieldDataHexString forKey:fieldNum];
                }
            }
            
            // 下一步是获取原始数据
            if ([filedAttributes.dataType isEqualToString:@"BCD"]) {
                //是BCD就不用转了
            }else if([filedAttributes.dataType isEqualToString:@"ASCII"]){
                if (i == 62) { //62域有不同的用法
                    //如果是终端密钥下载，类型为二进制，是其他的话是ASCII
                    NSString *field60 = [fieldDataDict valueForKey:@"60"];
                    if ([field60 hasSuffix:@"352"]) {
                        // 是二进制不用转
                    }else if([field60 hasSuffix:@"350"]){
                        // 是ASCII 需要转
//                        NSString *tempFieldDataHexString = [fieldDataDict valueForKey:fieldNum];
//                        tempFieldDataHexString = [[NSString alloc] initWithData:[TransformNSString hexToBytes:tempFieldDataHexString] encoding:NSASCIIStringEncoding];
//                        [fieldDataDict setValue:tempFieldDataHexString forKey:fieldNum];
                    }
                }else{
                    NSString *tempFieldDataHexString = [fieldDataDict valueForKey:fieldNum];
                    tempFieldDataHexString = [[NSString alloc] initWithData:[TransformNSString hexToBytes:tempFieldDataHexString] encoding:NSASCIIStringEncoding];
                    [fieldDataDict setValue:[tempFieldDataHexString uppercaseString] forKey:fieldNum];
                }
            }else if([filedAttributes.dataType isEqualToString:@"BINARY"]){
                //是二进制也不用转
            }
        }
    }
    XLLog(@"Unpack data %@", fieldDataDict);
    return fieldDataDict;
    
}
#pragma mark - 单例方法
/**
 * 数据域编号
 */
//@property (nonatomic, assign) NSUInteger filedNum;

/**
 * 最大长度
 */
//@property (nonatomic, assign) NSUInteger maxLength;
/**
 * 数据空间大小类型 固定长度/2位变长/3位变长(FIXED_LENTTH/VARIABLE_2_LENGTH/VARIABLE_3_LENGTH)
 */
//@property (nonatomic, copy) NSString *lengthType;
/**
 * 数据类型 BCD/BINARY/ASCII
 */
//@property (nonatomic, copy) NSString *dataType;
/**
 * 数据类型 BCD压缩 左靠/右靠(L/R)
 */
//@property (nonatomic, copy) NSString *bcdCompressType;

+ (instancetype)shareInstance
{
    static XLISO8583Handler *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[XLISO8583Handler alloc] init];
        handler.iso8583Bitmap = [[ISO8583BitMap alloc] init];
        // 通过域的编号查找该域的属性
        // 变长的时候表示长度，同右靠BCD码
        // 数据用左靠BCD码？
        handler.fieldsDataList = [NSMutableArray array];
        handler.iso8583FieldsAttributes = @{
                                           @"0":@{@"fieldID":@(0), @"maxLength":@(4), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},//标识消息类型
                                           @"1":@{@"fieldID":@(1)},//标识是否使用扩展位图
                                           @"2":@{@"fieldID":@(2), @"maxLength":@(19), @"lengthType":@"VARIABLE_2_LENGTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"3":@{@"fieldID":@(3), @"maxLength":@(6), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"4":@{@"fieldID":@(4), @"maxLength":@(12), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"5":@{@"fieldID":@(5)},
                                           @"6":@{@"fieldID":@(6), @"maxLength":@(12), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"7":@{@"fieldID":@(7)},
                                           @"8":@{@"fieldID":@(8)},
                                           @"9":@{@"fieldID":@(9)},
                                           
                                           @"10":@{@"fieldID":@(10), @"maxLength":@(8), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"11":@{@"fieldID":@(11), @"maxLength":@(6), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"12":@{@"fieldID":@(12), @"maxLength":@(6), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"13":@{@"fieldID":@(13), @"maxLength":@(4), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"14":@{@"fieldID":@(14), @"maxLength":@(4), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"15":@{@"fieldID":@(15), @"maxLength":@(4), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"16":@{@"fieldID":@(16)},
                                           @"17":@{@"fieldID":@(17)},
                                           @"18":@{@"fieldID":@(18)},
                                           @"19":@{@"fieldID":@(19)},
                                           
                                           @"20":@{@"fieldID":@(20)},
                                           @"21":@{@"fieldID":@(21)},
                                           @"22":@{@"fieldID":@(22), @"maxLength":@(3), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"23":@{@"fieldID":@(23), @"maxLength":@(3), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"R"},
                                           @"24":@{@"fieldID":@(24)},
                                           @"25":@{@"fieldID":@(25), @"maxLength":@(2), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"26":@{@"fieldID":@(26), @"maxLength":@(2), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"27":@{@"fieldID":@(27)},
                                           @"28":@{@"fieldID":@(28)},
                                           @"29":@{@"fieldID":@(29)},
                                           
                                           @"30":@{@"fieldID":@(30)},
                                           @"31":@{@"fieldID":@(31)},
                                           @"32":@{@"fieldID":@(32), @"maxLength":@(11), @"lengthType":@"VARIABLE_2_LENGTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"33":@{@"fieldID":@(33)},
                                           @"34":@{@"fieldID":@(34), },
                                           @"35":@{@"fieldID":@(35), @"maxLength":@(99), @"lengthType":@"VARIABLE_2_LENGTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"36":@{@"fieldID":@(36), @"maxLength":@(104), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"37":@{@"fieldID":@(37), @"maxLength":@(12), @"lengthType":@"FIXED_LENTTH", @"dataType":@"ASCII"},
                                           @"38":@{@"fieldID":@(38), @"maxLength":@(6), @"lengthType":@"FIXED_LENTTH", @"dataType":@"ASCII"},
                                           @"39":@{@"fieldID":@(39), @"maxLength":@(2), @"lengthType":@"FIXED_LENTTH", @"dataType":@"ASCII"},
                                           
                                           @"40":@{@"fieldID":@(40), },
                                           @"41":@{@"fieldID":@(41), @"maxLength":@(8), @"lengthType":@"FIXED_LENTTH", @"dataType":@"ASCII"},
                                           @"42":@{@"fieldID":@(42), @"maxLength":@(15), @"lengthType":@"FIXED_LENTTH", @"dataType":@"ASCII"},
                                           @"43":@{@"fieldID":@(43)},
                                           @"44":@{@"fieldID":@(44), @"maxLength":@(25), @"lengthType":@"VARIABLE_2_LENGTH", @"dataType":@"ASCII"},
                                           @"45":@{@"fieldID":@(45)},
                                           @"46":@{@"fieldID":@(46), @"maxLength":@(128), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"ASCII"},
                                           @"47":@{@"fieldID":@(47), @"maxLength":@(999), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"BINARY"},
                                           @"48":@{@"fieldID":@(48), @"maxLength":@(322), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"ASCII"},
                                           @"49":@{@"fieldID":@(49), @"maxLength":@(3), @"lengthType":@"FIXED_LENTTH", @"dataType":@"ASCII"},
                                           
                                           @"50":@{@"fieldID":@(50)},
                                           @"51":@{@"fieldID":@(51), @"maxLength":@(3), @"lengthType":@"FIXED_LENTTH", @"dataType":@"ASCII"},
                                           @"52":@{@"fieldID":@(52), @"maxLength":@(8), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BINARY"},
                                           @"53":@{@"fieldID":@(53), @"maxLength":@(16), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"54":@{@"fieldID":@(54), @"maxLength":@(40), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"ASCII"},
                                           @"55":@{@"fieldID":@(55), @"maxLength":@(999), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"BINARY"},
                                           @"56":@{@"fieldID":@(56)},
                                           @"57":@{@"fieldID":@(57), @"maxLength":@(512), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"BINARY"},
                                           @"58":@{@"fieldID":@(58)},
                                           @"59":@{@"fieldID":@(59), @"maxLength":@(29), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"ASCII"},
                                           
                                           @"60":@{@"fieldID":@(60), @"maxLength":@(15), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"BCD", @"bcdCompressType":@"L"},
                                           @"61":@{@"fieldID":@(61), @"maxLength":@(29), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"ASCII", @"bcdCompressType":@"L"},
                                           @"62":@{@"fieldID":@(62), @"maxLength":@(999), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"BINARY"},
                                           @"63":@{@"fieldID":@(63), @"maxLength":@(63), @"lengthType":@"VARIABLE_3_LENGTH", @"dataType":@"ASCII"},
                                           @"64":@{@"fieldID":@(64), @"maxLength":@(8), @"lengthType":@"FIXED_LENTTH", @"dataType":@"BINARY"}
                                           };
                                  
    });
    return handler;
}
@end
