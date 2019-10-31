//
//  XLPayManager.m
//  xuanlian_pay_sdk
//
//  Created by heting on 2019/9/8.
//  Copyright © 2019年 ccd. All rights reserved.
//

#import "XLPayManager.h"
#import "BerTlvUmbrella.h"
#import "XLSocketHandler.h"
#import "XLISO8583Handler.h"
#import "TransformNSString.h"
#import "NSData+AESAdditions.h"
#import "XLKit.h"
#include "xlenc.h"
#import "XLError.h"

#import "XLAuthPublicModel.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <Security/Security.h>
#import "XLPOSManager.h"
#import <UIKit/UIKit.h>



@interface XLPayManager ()<XLSocketHandlerDelegate>
@property (nonatomic, strong) XLAuthPublicModel *authPubKeyParam;
@property (nonatomic, strong) XLEncTMKModel *encTMKModel;
@property (nonatomic, copy) NSString *currentTerminalId;
@property (nonatomic, copy) NSString *currentMerchatId;
@property (nonatomic, copy) NSString *currentMerchatName;
@property (nonatomic, copy) NSString *clientKey;
@property (nonatomic, copy) NSString *posOriginTmk;
@property (nonatomic, copy) HandleResultBlock successBlock;
@property (nonatomic, copy) HandleResultBlock failedBlock;
@property (nonatomic, assign) XLPayBusinessType currentBusinessType;
@property (nonatomic, strong) NSData *waitScriptRespSendData; //脚本先于交易发送

@property (nonatomic, strong) NSArray *imageHexArray;
@property (nonatomic, copy) NSDictionary *signatureMessageHead;
@property (nonatomic, copy) NSDictionary *originCapRespParams;
@property (nonatomic, assign) NSUInteger imagePackCount;

@end

@implementation XLPayManager
#pragma mark - 初始化
+ (instancetype)shareInstance
{
    static XLPayManager *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[XLPayManager alloc] init];
        handler.clientKey = [XLKit getRandomClientKey:@"xunlian.pos.sdk"];
        XLLog(@"随机密钥 = %@", handler.clientKey);
        [[XLSocketHandler shareInstance] addDelegate:handler delegateQueue:dispatch_get_main_queue()];
//        handler.currentTerminalId = kTERMINALID;
//        handler.currentMerchatId = kMERCHANTID;
        handler.posOriginTmk = kPOSORIGINTMK;
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        handler.currentTerminalId = [userDefaults valueForKey:kTERMINALID_USERDEFAULT_KEY];
        handler.currentMerchatId = [userDefaults valueForKey:kMERCHANTID_USERDEFAULT_KEY];
        handler.currentMerchatName = [userDefaults valueForKey:kMERCHANT_NAME_USERDEFAULT_KEY];
    });
    return handler;
}

- (BOOL)setupDeviceId:(NSString *)deviceId merchantId:(NSString *)merchantId merchantName:(NSString *) merchantName
{
    if (!deviceId || !merchantId || !merchantName || deviceId.length <= 0 || merchantId.length <= 0 || merchantName.length <= 0) {
        return NO;
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:deviceId forKey:kTERMINALID_USERDEFAULT_KEY];
    [userDefaults setValue:merchantId forKey:kMERCHANTID_USERDEFAULT_KEY];
    [userDefaults setValue:merchantName forKey:kMERCHANT_NAME_USERDEFAULT_KEY];
    [XLPayManager shareInstance].currentTerminalId = deviceId;
    [XLPayManager shareInstance].currentMerchatId = merchantId;
    [XLPayManager shareInstance].currentMerchatName = merchantName;
    return [userDefaults synchronize];
}
/**
 *    @brief   获取设备id
 */
- (NSString *)getDeviceId
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults valueForKey:kTERMINALID_USERDEFAULT_KEY];
}

/**
 *    @brief   获取商户id
 */
- (NSString *)getMerchantId
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults valueForKey:kMERCHANTID_USERDEFAULT_KEY];
}

/**
 *    @brief   获取商户id
 */
- (NSString *)getMerchantName
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults valueForKey:kMERCHANT_NAME_USERDEFAULT_KEY];
}

- (HandleResultBlock)getPayManagerFailedCB
{
    return [XLPayManager shareInstance].failedBlock;
}
#pragma mark 重置
- (void)resetPayManager
{
    [XLPayManager shareInstance].authPubKeyParam = nil;
    [XLPayManager shareInstance].encTMKModel = nil;
    [XLPayManager shareInstance].successBlock = nil;
    [XLPayManager shareInstance].failedBlock = nil;
    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeDefault;
    [XLPayManager shareInstance].successBlock = nil;
    [XLPayManager shareInstance].failedBlock = nil;
    [XLPayManager shareInstance].waitScriptRespSendData = nil;
    [XLPayManager shareInstance].imageHexArray = nil;
    [XLPayManager shareInstance].signatureMessageHead = nil;
    [XLPayManager shareInstance].originCapRespParams = nil;
    [XLPayManager shareInstance].imagePackCount = 0;
}
/**
 *  @brief 设置终端编号和商户编号
 *  @param terminalIdHexStr 终端编号
 *  @param merchantIdHex    商户编号
 */
- (void)setupWithTerminalId:(NSString *) terminalIdHexStr merchantId:(NSString *) merchantIdHex
{
    [XLPayManager shareInstance].currentTerminalId = terminalIdHexStr;
    [XLPayManager shareInstance].currentMerchatId = merchantIdHex;
}
#pragma mark - 发送公钥下载报文
/**
 *  @brief POS 下载终端主秘钥
 *  @param successCB 下载终端主秘钥成功的回调
 *  @param failedCB 下载终端主秘钥失败的回调
 */
- (void)downloadTerminalMasterKeyWithSuccessCB:(HandleResultBlock) successCB
                                   failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    if (![[XLPayManager shareInstance] checkMerchantIdAndDeviceIdValiable]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
        failedCB(model);
    }
    [[XLPayManager shareInstance] resetPayManager];
    [XLPayManager shareInstance].successBlock = [successCB copy];
    [XLPayManager shareInstance].failedBlock = [failedCB copy];
    [[XLPayManager shareInstance] sendRequestPublicKeyMessage];
}

- (void)sendRequestPublicKeyMessage{
    XLLog(@"开始下载公钥");
    if (![[XLPayManager shareInstance] checkMerchantIdAndDeviceIdValiable]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
        startCallBack([XLPayManager shareInstance].failedBlock, model);
    }
    NSDictionary *tempDict = @{
                               @"0": @"0800",
                               @"41": [XLPayManager shareInstance].currentTerminalId,
                               @"42": [XLPayManager shareInstance].currentMerchatId,
                               @"60": @"00000001352"
                               };
    
    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeDownloadPublicKey;
    // 对数据封包
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:tempDict completion:^(XLResponseModel *respModel) {
        // 封包成功后发送数据
        if ([respModel.respCode isEqualToString:RESP_SUCCESS]) {
            NSString *socket_hex_data = [respModel.data[@"socket_hex_data"] uppercaseString];
            NSData *requestData = [TransformNSString hexToBytes:socket_hex_data];
            [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
            } failedBlock:^(XLResponseModel *respModel) {
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                }
            }];
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, respModel);
            }
        }
    }];
}

#pragma mark - XLSocketHandlerDelegate
#pragma mark 收到返回报文
- (void)didReceivedXunLianResponseMessageWithHexString:(NSString *)hexString
{
    // 收到响应报文后 解包
    [[XLSocketHandler shareInstance] executeDisconnectServer];
    NSData *uppackData = [TransformNSString hexToBytes:hexString];
    [[XLISO8583Handler shareInstance] unpackISO8583MesssageWithFieldModel:uppackData completion:^(XLResponseModel *respModel) {
        if ([respModel.respCode isEqualToString:RESP_SUCCESS]) {
            // 根据消息类型区分，这个地方都是响应消息
            NSDictionary *fieldsData = respModel.data[@"fields_data"];
            XLLog(@"unpacked fieldsData = %@", fieldsData);
            switch ([XLPayManager shareInstance].currentBusinessType) {
                case XLPayBusinessTypeDownloadPublicKey:
                {
                    // 解析tlv 公钥下载
                    if ([fieldsData[@"39"] isEqualToString:@"00"]) {
                        [[XLPayManager shareInstance] parseTLVWithHexString:fieldsData[@"62"]];
                    }else{
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_FIELD_39_RESP_ERROR respMsg:@"下载公钥报文应答错误" respData:fieldsData];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }
                }
                    break;
                case XLPayBusinessTypeDownloadTMK:
                {
                    // 解析tlv TMK(主密钥)下载
                    if ([fieldsData[@"39"] isEqualToString:@"00"]) {
                        [[XLPayManager shareInstance] parseTLVWithHexString:fieldsData[@"62"]];
                    }else{
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_FIELD_39_RESP_ERROR respMsg:@"下载主密钥报文应答错误" respData:fieldsData];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }
                }
                    break;
                case XLPayBusinessTypeEnableTMK:
                {
                    NSString *respCode = fieldsData[@"39"];
                    if ([respCode isEqualToString:@"00"]) {
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"启用主密钥成功" respData:@{}];
                        if ([XLPayManager shareInstance].successBlock) {
                            startCallBack([XLPayManager shareInstance].successBlock, model);
                        }
                    }else{
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_FIELD_39_RESP_ERROR respMsg:@"启用主密钥报文应答错误" respData:fieldsData];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }
                }
                    break;
                case XLPayBusinessTypeSignIn:
                {
                    //获取工作密钥
                    NSString *respCode = fieldsData[@"39"];
                    if ([respCode isEqualToString:@"00"]) {
                        NSDictionary *fieldsData = respModel.data[@"fields_data"];
                        NSLog(@"%@", fieldsData);
                        [[XLPayManager shareInstance] parseWorkKeyWithHexString:fieldsData[@"62"]];
                    }else{
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_FIELD_39_RESP_ERROR respMsg:@"签到报文应答错误" respData:fieldsData];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }

                }
                    break;
                case XLPayBusinessTypeLogout:
                {
                    // 签退报文返回
                    NSString *respCode = fieldsData[@"39"];
                    if ([respCode isEqualToString:@"00"]) {
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"POS签退成功" respData:@{}];
                        if ([XLPayManager shareInstance].successBlock) {
                            startCallBack([XLPayManager shareInstance].successBlock, model);
                        }
                    }else{
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_FIELD_39_RESP_ERROR respMsg:@"POS签退失败" respData:@{}];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }
                }
                    break;
                case XLPayBusinessTypeHandleScript:
                {
                    NSString *respCode = fieldsData[@"39"];
                    if ([respCode isEqualToString:@"00"]) {
                        XLLog(@"上送脚本通知成功");
                    }else{
                        XLLog(@"上送脚本通知失败");
                    }
                }
                    break;
                case XLPayBusinessTypeReturnGoods:
                {
                    NSDictionary *uppackFieldsData = [fieldsData copy];
                    [[XLPOSManager shareInstance] checkMacWithResponseMessage:hexString successBlock:^(XLResponseModel *respModel) {
                        NSString *respCode = uppackFieldsData[@"39"];
                        if ([respCode isEqualToString:@"00"]) {
                            XLLog(@"退货成功");
                            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"退货成功"];
                            model.data = fieldsData;
                            model.tradeSignatureCode = [[XLPayManager shareInstance] calcuateTradeSignatureCodeWithField15:fieldsData[@"15"] field37:fieldsData[@"37"]];
                            if ([XLPayManager shareInstance].successBlock) {
                                startCallBack([XLPayManager shareInstance].successBlock, model);
                            }
                        }else{
                            XLLog(@"退货失败");
                            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_FIELD_39_RESP_ERROR respMsg:@"退货失败" respData:@{}];
                            if ([XLPayManager shareInstance].failedBlock) {
                                startCallBack([XLPayManager shareInstance].failedBlock, model);
                            }
                        }
                    } failedBlock:^(XLResponseModel *respModel) {
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_CAP_MSG_MAC_ERROR respMsg:@"CAP返回报文校验MAC错误" respData:fieldsData];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }];

                }
                    break;
                case XLPayBusinessTypeUploadSignature:
                {
                    NSString *respCode = fieldsData[@"39"];
                    if ([respCode isEqualToString:@"00"]) {
                        XLLog(@"上送签名图片数据成功");
                        if ([XLPayManager shareInstance].imagePackCount < [[XLPayManager shareInstance].imageHexArray count]) {
                            // 还有图片信息要上送
                            [XLPayManager shareInstance].imagePackCount = [XLPayManager shareInstance].imagePackCount + 1;
                            [[XLPayManager shareInstance] sendAnotherImageData];
                        }else{
                            // 上送签名图片已经完成
                            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:@"上送签名图片成功"];
                            if ([XLPayManager shareInstance].successBlock) {
                                startCallBack([XLPayManager shareInstance].successBlock, model);
                            }
                        }
                    }else{
                        XLLog(@"上送签名图片数据失败");
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_FIELD_39_RESP_ERROR respMsg:@"上送签名图片失败" respData:@{}];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }
                }
                    break;
                case XLPayBusinessTypeConsume:
                case XLPayBusinessTypeConsumeCancel:
                case XLPayBusinessTypeConsumeReverse:
                case XLPayBusinessTypeConsumeCancelReverse:
                {
                    NSString *tpduMsgHeadStr = [hexString substringWithRange:NSMakeRange(4, 22)];
//                    NSString *tpduHexStr = @"6001090000610100000000";
                    NSDictionary *uppackFieldsData = [fieldsData copy];
                    [[XLPOSManager shareInstance] checkMacWithResponseMessage:hexString successBlock:^(XLResponseModel *respModel) {
                        // 校验mac成功
                        NSString *respCode = uppackFieldsData[@"39"];
                        NSString *busTypeStr = @"";
                        NSString *tradeSignatureCode = nil; //只有消费、和消费撤销才返回交易特征码
                        switch ([XLPayManager shareInstance].currentBusinessType) {
                            case XLPayBusinessTypeConsume:
                            {
                                tradeSignatureCode = [[XLPayManager shareInstance] calcuateTradeSignatureCodeWithField15:fieldsData[@"15"] field37:fieldsData[@"37"]];
                                busTypeStr = @"消费";
                            }
                                break;
                            case XLPayBusinessTypeConsumeCancel:
                            {
                                tradeSignatureCode = [[XLPayManager shareInstance] calcuateTradeSignatureCodeWithField15:fieldsData[@"15"] field37:fieldsData[@"37"]];
                                busTypeStr = @"消费撤销";
                            }
                                break;
                            case XLPayBusinessTypeConsumeReverse:
                            {
                                busTypeStr = @"消费冲正";
                            }
                                break;
                            case XLPayBusinessTypeConsumeCancelReverse:
                            {
                                busTypeStr = @"消费撤销冲正";
                            }
                                break;
                            default:
                                break;
                        }
                        if ([respCode isEqualToString:@"00"]) {
                            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_SUCCESS respMsg:[NSString stringWithFormat:@"%@成功", busTypeStr] respData:fieldsData];
                            // 返回交易特征码 只有消费和消费撤销使用
                            model.tradeSignatureCode = tradeSignatureCode;
                            if ([tpduMsgHeadStr hasSuffix:@"610100000000"] == YES) {
                                // 芯片卡 返回55域的数据
                                NSString *field60 = [uppackFieldsData[@"60"] description];
                                if ([field60 hasSuffix:@"600"] || [field60 hasSuffix:@"601"]) {
                                    //挥卡不回写iccdata
                                }else{
                                    model.iccdata = uppackFieldsData[@"55"];
                                    model.respCode = RESP_SUCCESS_WAITTING;
                                }
                                
                            }
                            //   构建好返回的model后，上送脚本
                            if ([XLPayManager shareInstance].waitScriptRespSendData) {
                                XLLog(@"发送脚本报文...");
                                [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                                    XLLog(@"发送脚本报文建立连接成功");
                                    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeHandleScript;
                                    [[XLSocketHandler shareInstance] sendMessageWithData:[XLPayManager shareInstance].waitScriptRespSendData];
                                } failedBlock:^(XLResponseModel *respModel) {
                                    XLLog(@"发送脚本报文建立连接失败");
                                }];
                            }
                            
                            if ([XLPayManager shareInstance].successBlock) {
                                startCallBack([XLPayManager shareInstance].successBlock, model);
                            }
                        }else{
                            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_CAP_MSG_BUSINESS_ERROR respMsg:[NSString stringWithFormat:@"%@失败", busTypeStr] respData:fieldsData];
                            // 构建好返回的model后，上送脚本
                            if ([XLPayManager shareInstance].failedBlock) {
                                startCallBack([XLPayManager shareInstance].failedBlock, model);
                            }
                        }
                    } failedBlock:^(XLResponseModel *respModel) {
                        // 校验mac失败
                        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_CAP_MSG_MAC_ERROR respMsg:@"CAP返回报文校验MAC错误" respData:fieldsData];
                        if ([XLPayManager shareInstance].failedBlock) {
                            startCallBack([XLPayManager shareInstance].failedBlock, model);
                        }
                    }];
                }
                    break;
                default:
                    break;
            }
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                [XLPayManager shareInstance].failedBlock(respModel);
            }
        }
    }];
    
}
#pragma mark socket错误回调
- (void)socketHandlerErrorWithModel:(XLResponseModel *)errorModel
{
    if ([XLPayManager shareInstance].failedBlock) {
        startCallBack([XLPayManager shareInstance].failedBlock, errorModel);
    }
}

#pragma mark 计算交易特征码
- (NSString *)calcuateTradeSignatureCodeWithField15:(NSString *) field15 field37:(NSString *) field37{
    if (field15 == nil || field15.length <= 0) {
        field15 = @"0000";
    }
    NSString *block = [NSString stringWithFormat:@"%@%@", field15, field37];
    if (block.length == 16) {
        NSString *blockHead = [block substringWithRange:NSMakeRange(0, 8)];
        NSString *blockTail = [block substringWithRange:NSMakeRange(8, 8)];
        char *p1 = (char *)[blockHead UTF8String];
        char *p2 = (char *)[blockTail UTF8String];
        char tmp1[2] = {0};
        char tmp2[2] = {0};
        char tmp3[9] = {0};
        int item1 = 0, item2 = 0;
        int res = 0; // 每字节异或结果
        //char check[20] = {0};
        int xorlen = 8;
        for (int i = 0; i < xorlen; i++, p1++, p2++) {
            sprintf(tmp1, "%c", *p1);
            sprintf(tmp2, "%c", *p2);
            item1 = (int)strtoul(tmp1, 0, 16);
            item2 = (int)strtoul(tmp2, 0, 16);
            res = item1 ^ item2;
            sprintf(tmp1, "%X", res);
            tmp3[i] = tmp1[0];
        }
        NSString *tradeSNCode = [NSString stringWithFormat:@"%s", tmp3];
        XLLog(@"TradeSignatureCode = %@", tradeSNCode);
        return tradeSNCode;
    }
    return nil;
}
#pragma mark 下载主密钥和公钥解析TLV
- (void)parseTLVWithHexString:(NSString *)hexString
{
    NSError *error = nil;
    NSData * data = [HexUtil parse:hexString error:&error];
    BerTlvParser * parser = [[BerTlvParser alloc] init];
    if (!error) {
        BerTlv *tlv = (BerTlv *)[parser parseTlvs:data error:&error];
        if (!error) {
            NSLog(@"%@", [tlv dump:@"  "]);
            NSArray *tlvArray = tlv.list;
            if ([tlvArray count] > 0) {
                switch ([XLPayManager shareInstance].currentBusinessType) {
                    case XLPayBusinessTypeDownloadPublicKey:
                    {
                        // 获取到公钥参数 准备下载主密钥
                        XLAuthPublicModel *model = [[XLAuthPublicModel alloc] init];
                        for (BerTlv *objTlv in tlvArray) {
                            NSString *tag = [objTlv.tag.hex uppercaseString];
                            if ([tag isEqualToString:@"9F06"]) {
                                model.rid = objTlv.hexValue;
                            }else if([tag isEqualToString:@"9F22"]){
                                model.pubKeyIndex = objTlv.hexValue;
                            }else if([tag isEqualToString:@"DF02"]){
                                model.pubKeyModelValue = objTlv.hexValue;
                            }else if([tag isEqualToString:@"DF04"]){
                                model.pubkeyExponent = objTlv.hexValue;
                            }else{
                                
                            }
                        }
                        // 缓存公钥
                        [XLPayManager shareInstance].authPubKeyParam = model;
                        [self requestMasterKey];
                    }
                        break;
                    case XLPayBusinessTypeDownloadTMK:
                    {
                        //获取tlv 解析 后的随机密钥加密的tmk 和 校验值
                        XLEncTMKModel *model = [[XLEncTMKModel alloc] init];
                        for (BerTlv *objTlv in tlvArray) {
                            NSString *tag = [objTlv.tag.hex uppercaseString];
                            if ([tag isEqualToString:@"DF21"]) {
                                model.encTMK = objTlv.hexValue;
                            }else if([tag isEqualToString:@"DF22"]){
                                model.encTMKCheckValue = objTlv.hexValue;
                            }else{
                            }
                        }
                        [XLPayManager shareInstance].encTMKModel = model;
                        //解密tmk 并校验tmk
                        NSString *tmk = [[XLPayManager shareInstance] decryptTMKWithTMKModel:model];
                        if (tmk) {
                            // 解密主密钥成功 判断主密钥是否可用
                            BOOL available = [[XLPayManager shareInstance] checkAvailableWithTMK:tmk TMKModel:model];
                            if (available) {
                                // 使用POS原始的tmk加密
                                NSString *cipherTmk = [XLKit calculateCiphertextWithTmk:tmk];
                                XLTMKModel *tmkModel = [[XLTMKModel alloc] init];
                                tmkModel.cipherTextTmk = cipherTmk;
                                tmkModel.checkValue = [model.encTMKCheckValue stringByAppendingString:@"00000000"];
                                XLResponseModel *model = [XLResponseModel createWithMasterKeyModel:tmkModel respMsgWithCode:RESP_SUCCESS respMsg:@"下载主密钥成功"];
                                if ([XLPayManager shareInstance].successBlock) {
                                    startCallBack([XLPayManager shareInstance].successBlock, model);
                                }
                            }else{
                                XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_MASTER_KEY_CHECKVALUE_ERROR respMsg:@"主密钥校验值错误" respData:@{}];
                                if ([XLPayManager shareInstance].failedBlock) {
                                    startCallBack([XLPayManager shareInstance].failedBlock, model);
                                }
                            }
                        }else{
                            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_DECRYPT_MASTER_KEY_ERROR respMsg:@"解密主密钥失败" respData:@{}];
                            if ([XLPayManager shareInstance].failedBlock) {
                                startCallBack([XLPayManager shareInstance].failedBlock, model);
                            }
                        }
                    }
                        break;
                    case XLPayBusinessTypeSignIn:
                    {
                
                    }
                        break;
                    case XLPayBusinessTypeLogout:
                    {
                
                    }
                        break;
                    default:
                        break;
                }
            }else{
                XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_TLV_DATA_ERROR
                                                                        respMsg:@"解析结果数据异常"
                                                                       respData:@{}];
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, model);
                }
            }
            
        }else{
            XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARSE_TLV_ERROR
                                                                    respMsg:@"解析tlv错误"
                                                                   respData:@{@"error": [error description]}];
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, model);
            }
        }
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARSE_TLV_ERROR respMsg:@"tlv hex 转二进制错误" respData:@{}];
        if ([XLPayManager shareInstance].failedBlock) {
            startCallBack([XLPayManager shareInstance].failedBlock, model);
        }
    }
}
#pragma mark 解析工作密钥
- (void)parseWorkKeyWithHexString:(NSString *) hexString
{
    if ([hexString length] == 120) {
        NSString *pinKey   = [hexString substringWithRange:NSMakeRange(0, 32)];
        NSString *pinKeyCV = [hexString substringWithRange:NSMakeRange(32, 8)];
        NSString *macKey   = [hexString substringWithRange:NSMakeRange(40, 32)];
        NSString *macKeyCV = [hexString substringWithRange:NSMakeRange(72, 8)];
        NSString *tdKey    = [hexString substringWithRange:NSMakeRange(80, 32)];
        NSString *tdKeyCV  = [hexString substringWithRange:NSMakeRange(112, 8)];
        XLWorkKeyModel *workKeyModel = [[XLWorkKeyModel alloc] init];
        workKeyModel.encPinKey = pinKey;
        if (pinKeyCV && pinKeyCV.length == 8) {
            workKeyModel.encPinKeyCV = [pinKeyCV stringByAppendingString:@"00000000"];
        }
        workKeyModel.encMacKey = macKey;
        if (macKeyCV && macKeyCV.length == 8) {
            workKeyModel.encMacKeyCV = [macKeyCV stringByAppendingString:@"00000000"];
        }
        workKeyModel.encTdkKey = tdKey;
        if (tdKeyCV && tdKeyCV.length == 8) {
            workKeyModel.encTdkKeyCV = [tdKeyCV stringByAppendingString:@"00000000"];
        }
        XLResponseModel *model = [XLResponseModel createWithWorkKeyModel:workKeyModel respMsgWithCode:RESP_SUCCESS respMsg:@"获取工作密钥成功"];
        [XLPayManager shareInstance].successBlock(model);
    }else{
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_WORK_KEY_FORMAT_ERROR respMsg:@"工作密钥格式错误" respData:@{}];
        if ([XLPayManager shareInstance].failedBlock) {
            startCallBack([XLPayManager shareInstance].failedBlock, model);
        }
    }
}
#pragma mark - 下载主密钥
#pragma mark 发送下载主密钥报文
- (void)requestMasterKey{
    XLLog(@"开始下载主密钥");
    // 先判断是否已经拿到公钥
    if (![XLPayManager shareInstance].authPubKeyParam) {
        return;
    }
    // 加密随机密钥
    NSString *encAESKey = [XLKit encryptWithContent:[XLPayManager shareInstance].clientKey
                                          publicKey:[XLPayManager shareInstance].authPubKeyParam.pubKeyModelValue
                                        keyExponent:[XLPayManager shareInstance].authPubKeyParam.pubkeyExponent];
    // 获取随机密钥校验值
    NSString *checkValue = [XLKit createCheckValueWithRandomKey:[XLPayManager shareInstance].clientKey];
    
    BerTlvBuilder *builder = [[BerTlvBuilder alloc] init];
    [builder addHex:[XLPayManager shareInstance].authPubKeyParam.rid tag:[BerTag parse:@"9F06"]];
    [builder addHex:[XLPayManager shareInstance].authPubKeyParam.pubKeyIndex tag:[BerTag parse:@"9F22"]];
    [builder addHex:encAESKey tag:[BerTag parse:@"DF23"]];
    [builder addHex:checkValue tag:[BerTag parse:@"DF24"]];
    NSError *dataError;
    NSData *expectedData = [builder buildDataWithError:&dataError];
    if (dataError) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PACK_TLV_ERROR
                                                                respMsg:@"下载主密钥，TLV打包错误"
                                                               respData:@{@"error": [dataError description]}];
        if ([XLPayManager shareInstance].failedBlock) {
            startCallBack([XLPayManager shareInstance].failedBlock, model);
        }
        return;
    }
    NSString *hexStr = [HexUtil format:expectedData];
    NSDictionary *requestTMKParam = @{
                                        @"0": @"0800",
                                        @"41": [XLPayManager shareInstance].currentTerminalId,
                                        @"42": [XLPayManager shareInstance].currentMerchatId,
                                        @"60": @"00000001350",
                                        @"62": hexStr,
                                    };
    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeDownloadTMK;
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:requestTMKParam completion:^(XLResponseModel *respModel) {
        //封包成功后发送数据
        if ([respModel.respCode isEqualToString:RESP_SUCCESS]) {
            NSString *socket_hex_data = [respModel.data[@"socket_hex_data"] uppercaseString];
            XLLog(@"TMK message = %@", socket_hex_data);
            NSData *requestData = [TransformNSString hexToBytes:socket_hex_data];
            [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
            } failedBlock:^(XLResponseModel *respModel) {
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                }
            }];
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, respModel);
            }
        }
    }];
}
- (NSString *)decryptTMKWithTMKModel:(XLEncTMKModel *)tmkModel
{
    char *encTMK = (char *)[tmkModel.encTMK UTF8String];
    char *randomKey = (char *)[[XLPayManager  shareInstance].clientKey UTF8String];
    char decTMKTemp[256] = {0};
    int result = xdec(decTMKTemp, randomKey, encTMK);
    if (result == 0) {
        //解密成功
        NSString *hexTmk = [NSString stringWithUTF8String:decTMKTemp];
        XLLog(@"解密成功的tmk = %@", hexTmk);
        return hexTmk;
    }
    return nil;
}
- (BOOL)checkAvailableWithTMK:(NSString *)hexTmk TMKModel:(XLEncTMKModel *)tmkModel
{
    char *charTMK = (char *)[hexTmk UTF8String];
    char checkVaueTemp[256] = {0};
    int calCVResult = genchcv_x(charTMK, checkVaueTemp);
    if (calCVResult == 0) {
        NSString *cvStr = [NSString stringWithUTF8String:checkVaueTemp];
        XLLog(@"tmk check value = %@", cvStr);
        //            NSString *subCV = [cvStr substringWithRange:NSMakeRange(0, 8)]; 取8个字符，也就是16个字节就是校验值
        if ([cvStr hasPrefix:tmkModel.encTMKCheckValue] == YES) {
            //相等 把tmk给上层
            return YES;
        }
        return NO;
    }else{
        // 计算校验值失败了
        return NO;
    }
    return NO;
}
- (BOOL)checkMerchantIdAndDeviceIdValiable{
    NSString *deviceId = [XLPayManager shareInstance].currentTerminalId;
    NSString *merchantId = [XLPayManager shareInstance].currentMerchatId;
    NSString *merchantName = [XLPayManager shareInstance].currentMerchatName;
    if (!deviceId || !merchantId || !merchantName || deviceId.length <= 0 || merchantId.length <= 0 || merchantName.length <= 0) {
        return NO;
    }
    return YES;
}
#pragma mark - 启用主密钥
- (void)enableTerminalMasterKeyWithSuccessCB:(HandleResultBlock) successCB
                                 failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    XLLog(@"开始启用终端密钥");
    if (![[XLPayManager shareInstance] checkMerchantIdAndDeviceIdValiable]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
        failedCB(model);
    }
    
    if (![XLPayManager shareInstance].currentTerminalId) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"设备终端标识不能为空" respData:@{}];
        failedCB(model);
        return;
    }
    if (![XLPayManager shareInstance].currentMerchatId) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"商户编号不能为空" respData:@{}];
        failedCB(model);
        return;
    }
    // 先校验公钥和tmk是否下载
    if (![XLPayManager shareInstance].authPubKeyParam) {
        // 回调失败
        failedCB([XLResponseModel createRespMsgWithCode:RESP_PROCESS_PUBLIC_KEY_ERROR respMsg:@"请先下载公钥" respData:@{}]);
        return;
    }
    if (![XLPayManager shareInstance].encTMKModel) {
        failedCB([XLResponseModel createRespMsgWithCode:RESP_PROCESS_MASTER_KEY_ERROR respMsg:@"请先下载主密钥" respData:@{}]);
        return;
    }
    [[XLPayManager shareInstance] resetPayManager];
    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeEnableTMK;
    [XLPayManager shareInstance].successBlock = [successCB copy];
    [XLPayManager shareInstance].failedBlock = [failedCB copy];
    NSDictionary *requestTMKParam = @{
                                      @"0": @"0800",
                                      @"41": [XLPayManager shareInstance].currentTerminalId,
                                      @"42": [XLPayManager shareInstance].currentMerchatId,
                                      @"60": @"00000001351",
                                      };
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:requestTMKParam completion:^(XLResponseModel *respModel) {
        //封包成功后发送数据
        if ([respModel.respCode isEqualToString:RESP_SUCCESS]) {
            NSString *socket_hex_data = [respModel.data[@"socket_hex_data"] uppercaseString];
            XLLog(@"Enable TMK message = %@", socket_hex_data);
            NSData *requestData = [TransformNSString hexToBytes:socket_hex_data];
            [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
            } failedBlock:^(XLResponseModel *respModel) {
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                }
            }];
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, respModel);
            }
        }
    }];
    
}
#pragma mark - 签到
/**
 *  @brief POS 签到
 *  @param successCB 签到成功的回调
 *  @param failedCB 签到失败的回调
 */
- (void)posSignInWithSuccessBlock:(HandleResultBlock) successCB
                      failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    XLLog(@"开始POS签到");
    if (![[XLPayManager shareInstance] checkMerchantIdAndDeviceIdValiable]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
        failedCB(model);
        return;
    }

    [[XLPayManager shareInstance] resetPayManager];
    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeSignIn;
    [XLPayManager shareInstance].successBlock = [successCB copy];
    [XLPayManager shareInstance].failedBlock = [failedCB copy];
    
    NSDictionary *requestSignInParam = @{
                                           @"0": @"0800",
                                           @"11": [XLKit genClientSn],
                                           @"41": [XLPayManager shareInstance].currentTerminalId,
                                           @"42": [XLPayManager shareInstance].currentMerchatId,
                                           @"60": @"00000001003",
                                           @"63": @"010"
                                        };
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:requestSignInParam completion:^(XLResponseModel *respModel) {
        //封包成功后发送数据
        if ([respModel.respCode isEqualToString:RESP_SUCCESS]) {
            NSString *socket_hex_data = [respModel.data[@"socket_hex_data"] uppercaseString];
            XLLog(@"SignIn message = %@", socket_hex_data);
            NSData *requestData = [TransformNSString hexToBytes:socket_hex_data];
            [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
            } failedBlock:^(XLResponseModel *respModel) {
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                }
            }];
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, respModel);
            }
        }
    }];
    
}
#pragma mark - 签退
/**
 *  @brief POS 签退
 *  @param successCB 签退成功的回调
 *  @param failedCB 签退失败的回调
 */
- (void)posLogoutWithSuccessBlock:(HandleResultBlock) successCB
                      failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    XLLog(@"开始POS签退");
    if (![[XLPayManager shareInstance] checkMerchantIdAndDeviceIdValiable]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
        failedCB(model);
        return;
    }

    [[XLPayManager shareInstance] resetPayManager];
    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeLogout;
    [XLPayManager shareInstance].successBlock = [successCB copy];
    [XLPayManager shareInstance].failedBlock = [failedCB copy];
    
    NSDictionary *requestSignInParam = @{
                                         @"0": @"0820",
                                         @"11": [XLKit genClientSn],
                                         @"41": [XLPayManager shareInstance].currentTerminalId,
                                         @"42": [XLPayManager shareInstance].currentMerchatId,
                                         @"60": @"00000001002"
                                         };
   
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:requestSignInParam completion:^(XLResponseModel *respModel) {
        //封包成功后发送数据
        if ([respModel.respCode isEqualToString:RESP_SUCCESS]) {
            NSString *socket_hex_data = [respModel.data[@"socket_hex_data"] uppercaseString];
            XLLog(@"Logout message = %@", socket_hex_data);
            NSData *requestData = [TransformNSString hexToBytes:socket_hex_data];
            [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
            } failedBlock:^(XLResponseModel *respModel) {
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                }
            }];
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, respModel);
            }
        }
    }];
    
}



- (void)sendMessageWithBusinessType:(XLPayBusinessType) usinessType
                   requestHexString:(NSString *) hexString
                       successBlock:(HandleResultBlock) successCB
                        failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    if (!hexString || hexString.length <= 0) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"缺少待发送报文的16进制串" respData:@{}];
        failedCB(model);
        return;
    }
    [[XLPayManager shareInstance] resetPayManager];
    XLLog(@"交易报文 = %@", hexString);
    [XLPayManager shareInstance].waitScriptRespSendData = nil;
    [XLPayManager shareInstance].successBlock = [successCB copy];
    [XLPayManager shareInstance].failedBlock = [failedCB copy];
    [XLPayManager shareInstance].currentBusinessType = usinessType;
    
    NSData *requestData = [TransformNSString hexToBytes:hexString];
    
    [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
        if (usinessType == XLPayBusinessTypeConsume ||
            usinessType == XLPayBusinessTypeConsumeCancel) {
            NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
            NSString *scriptHex = [userDefault valueForKey:@"LAST_SCRIPT_NOTIFICATION"];
            if (scriptHex && scriptHex.length > 0) {
                NSData *scriptData = [TransformNSString hexToBytes:scriptHex];
                [XLPayManager shareInstance].waitScriptRespSendData = scriptData;
                [userDefault removeObjectForKey:@"LAST_SCRIPT_NOTIFICATION"];
                [userDefault synchronize];
            }
        }
        [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
    } failedBlock:^(XLResponseModel *respModel) {
        if ([XLPayManager shareInstance].failedBlock) {
            startCallBack([XLPayManager shareInstance].failedBlock, respModel);
        }
    }];
}


- (void)uploadSignatureImageWithPath:(NSString *) imagePath
                 originCapRespParams:(NSDictionary *) originCapRespParams
                        successBlock:(HandleResultBlock) successCB
                         failedBlock:(HandleResultBlock) failedCB
{
    if (!successCB || !failedCB) {
        return;
    }
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    if (!image) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"签名图片原始数据获取异常"];
        startCallBack(failedCB, model);
        return;
    }
    NSData *imageData = UIImageJPEGRepresentation(image, 0.1);
    if ([imageData length] > 9000) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"上传签名图片大小应小于8.7KB"];
        startCallBack(failedCB, model);
        return;
    }

    if (![[XLPayManager shareInstance] checkMerchantIdAndDeviceIdValiable]) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"终端号或商户号异常，请先设置终端号和商户号"];
        failedCB(model);
        return;
    }
    
    // 检查originCapRespParams是否带有可用域
    if (!originCapRespParams[@"11"] ||
        !originCapRespParams[@"12"] ||
        !originCapRespParams[@"13"] ||
        !originCapRespParams[@"15"] ||
        !originCapRespParams[@"37"] ||
        !originCapRespParams[@"60"] ||
        !originCapRespParams[@"4"] ||
        [originCapRespParams[@"11"] description].length <= 0 ||
        [originCapRespParams[@"12"] description].length <= 0 ||
        [originCapRespParams[@"13"] description].length <= 0 ||
        [originCapRespParams[@"15"] description].length <= 0 ||
        [originCapRespParams[@"37"] description].length <= 0 ||
        [originCapRespParams[@"60"] description].length <= 0 ||
        [originCapRespParams[@"4"] description].length <= 0) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"CAP返回的交易参数异常，请重试"];
        startCallBack(failedCB, model);
        return;
    }
    [[XLPayManager shareInstance] resetPayManager];
    
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    [XLPayManager shareInstance].originCapRespParams = originCapRespParams;
    [XLPayManager shareInstance].currentBusinessType = XLPayBusinessTypeUploadSignature;
    [XLPayManager shareInstance].successBlock = successCB;
    [XLPayManager shareInstance].failedBlock = failedCB;
    
    // 上传签名图片公共域
    NSDictionary *fixedParam = @{
                                 @"0": @"0820",
                                 @"41":  [XLPayManager shareInstance].currentTerminalId,
                                 @"42":  [XLPayManager shareInstance].currentMerchatId,
                                 @"64": @"FFFFFFFFFFFFFFFF"
                                 };
    [paramDict setDictionary:fixedParam];
    [paramDict setObject:originCapRespParams[@"4"] forKey:@"4"];
    [paramDict setObject:originCapRespParams[@"11"] forKey:@"11"];
    
    NSString *field55 = [[XLPayManager shareInstance] signatureTradeTypeWithField11:originCapRespParams[@"11"]
                                                                            field12:originCapRespParams[@"12"]
                                                                            field13:originCapRespParams[@"13"]
                                                                            field15:originCapRespParams[@"15"]
                                                                            field37:originCapRespParams[@"37"]];
    [XLPayManager shareInstance].signatureMessageHead = paramDict;
    // 签名图片分包
    NSArray *imgHexArray = [[XLPayManager shareInstance] segmentImageWithOriginImageData:imageData];
    if (!imgHexArray || [imgHexArray count] == 0) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PARAM_ERROR respMsg:@"签名图片原始数据异常"];
        startCallBack(failedCB, model);
        return;
    }
    // 缓存分包数据
    [XLPayManager shareInstance].imageHexArray = imgHexArray;
    // 第一个包的序号
    [XLPayManager shareInstance].imagePackCount = 1;
    // 上传签名第一个包特有
    [paramDict setObject:field55 forKey:@"55"];
    NSString *originField60 = [originCapRespParams[@"60"] description];
    NSString *originBatchNum = [originField60 substringWithRange:NSMakeRange(2, 6)];
    NSUInteger packNumber = 1;
    if ([imgHexArray count] == 1) {
        packNumber = 0;
    }
    NSString *field60 = [NSString stringWithFormat:@"07%@80%ld", originBatchNum, packNumber];
    [paramDict setObject:field60 forKey:@"60"];
    [paramDict setObject:imgHexArray[0] forKey:@"62"];
    XLLog(@"签名原始数据 %@", paramDict);
    //封包上传签名数据
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:paramDict completion:^(XLResponseModel *respModel) {
        XLPackModel *packModel = [[XLPackModel alloc] init];
        packModel.headHexStr = respModel.data[@"msg_head_data"];
        packModel.ISO8583HexStr = respModel.data[@"iso8583_hex_data"];
        packModel.socketAllHexStr = respModel.data[@"socket_hex_data"];
        [XLPOSManager shareInstance].mrcPackModel = packModel;
        XLLog(@"封包结果 = %@", respModel.data);
        if ([respModel.respCode isEqualToString:RESP_SUCCESS] == YES) {
            NSString *tempStr = [packModel.ISO8583HexStr substringWithRange:NSMakeRange(0, packModel.ISO8583HexStr.length - 16)];
            [[XLPOSManager shareInstance] calculateMacWithScoketMessage:tempStr successBlock:^(XLResponseModel *respModel) {
                NSData *requestData = [TransformNSString hexToBytes:respModel.packModel.socketAllHexStr];
                [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                    [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
                } failedBlock:^(XLResponseModel *respModel) {
                    if ([XLPayManager shareInstance].failedBlock) {
                        startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                    }
                }];
            } failedBlock:^(XLResponseModel *respModel) {
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                }
            }];
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, respModel);
            }
        }
    }];
}
// 图片分包
- (NSArray *)segmentImageWithOriginImageData:(NSData *)imageData{
    NSUInteger len = [imageData length];
    NSUInteger packCount = len / 900;
    NSMutableData *mutalbeImgData = [NSMutableData dataWithData:imageData];
    NSMutableArray *imgHexArray = [NSMutableArray array];
    for (int i = 1; i <= packCount; i++) {
        Byte *byteData = (Byte*)malloc(900);
        memcpy(byteData, [imageData bytes], 900);
        NSMutableData *bts2Data = [NSMutableData dataWithLength:900];
        NSData *sendData = [bts2Data initWithBytes:byteData length:900];
        NSString *hexStr = [[TransformNSString hexStringFromData:sendData] uppercaseString];
        [imgHexArray addObject:hexStr];
        [mutalbeImgData replaceBytesInRange:NSMakeRange(0, 900) withBytes:NULL length:0];
    }
    NSUInteger left = len - (packCount * 900);
    if (left > 0) {
        Byte *byteData = (Byte*)malloc(left);
        memcpy(byteData, [imageData bytes], left);
        NSMutableData *bts2Data = [NSMutableData dataWithLength:left];
        NSData *sendData = [bts2Data initWithBytes:byteData length:left];
        NSString *hexStr = [[TransformNSString hexStringFromData:sendData] uppercaseString];
        [imgHexArray addObject:hexStr];
    }
    return imgHexArray;
}
// 上传图片合成55域
- (NSString *)signatureTradeTypeWithField11:(NSString *) field11
                                    field12:(NSString *) field12
                                    field13:(NSString *) field13
                                    field15:(NSString *) field15
                                    field37:(NSString *) field37{
    if (field15 == nil || field15.length <= 0) {
        field15 = @"0000";
    }
    BerTlvBuilder *builder = [[BerTlvBuilder alloc] init];
    NSString *GBKMerchantName = [TransformNSString convertStringToGBKStr:[XLPayManager shareInstance].currentMerchatName];
    [builder addHex:GBKMerchantName tag:[BerTag parse:@"FF00"]];
    [builder addHex:[NSString stringWithFormat:@"%@%@", field15, field37] tag:[BerTag parse:@"FF01"]];
    [builder addHex:@"01" tag:[BerTag parse:@"FF02"]];
    NSString *yyyy = [[XLKit yyyyFormatter] stringFromDate:[NSDate date]];
    NSString *tagFF06 = [NSString stringWithFormat:@"%@%@ %@", yyyy, field13, field12];
    [builder addHex:tagFF06 tag:[BerTag parse:@"FF06"]];
    NSError *dataError;

    NSData *expectedData = [builder buildDataWithError:&dataError];
    if (dataError) {
        XLResponseModel *model = [XLResponseModel createRespMsgWithCode:RESP_PACK_TLV_ERROR
                                                                respMsg:@"下载主密钥，TLV打包错误"
                                                               respData:@{@"error": [dataError description]}];
        if ([XLPayManager shareInstance].failedBlock) {
            startCallBack([XLPayManager shareInstance].failedBlock, model);
        }
        return nil;
    }
    NSString *hexStr = [HexUtil format:expectedData];
    return hexStr;
}
- (void)sendAnotherImageData{
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionaryWithDictionary:[XLPayManager shareInstance].signatureMessageHead];
    NSString *originField60 = [[XLPayManager shareInstance].originCapRespParams[@"60"] description];
    NSString *originBatchNum = [originField60 substringWithRange:NSMakeRange(2, 6)];
    NSString *tailStr = ([XLPayManager shareInstance].imagePackCount == [[XLPayManager shareInstance].imageHexArray count]) ? @"9" : @"8";
    NSString *field60 = [NSString stringWithFormat:@"08%@80%ld%@", originBatchNum, [XLPayManager shareInstance].imagePackCount, tailStr];
    [paramDict setObject:field60 forKey:@"60"];
    [paramDict setObject:[XLPayManager shareInstance].imageHexArray[[XLPayManager shareInstance].imagePackCount - 1] forKey:@"62"];
    XLLog(@"签名图片上传其他数据上传 = %@", paramDict);
    [[XLISO8583Handler shareInstance] packISO8583MessageWithFieldDict:paramDict completion:^(XLResponseModel *respModel) {
        XLPackModel *packModel = [[XLPackModel alloc] init];
        packModel.headHexStr = respModel.data[@"msg_head_data"];
        packModel.ISO8583HexStr = respModel.data[@"iso8583_hex_data"];
        packModel.socketAllHexStr = respModel.data[@"socket_hex_data"];
        [XLPOSManager shareInstance].mrcPackModel = packModel;
        XLLog(@"封包结果 = %@", respModel.data);
        if ([respModel.respCode isEqualToString:RESP_SUCCESS] == YES) {
            NSString *tempStr = [packModel.ISO8583HexStr substringWithRange:NSMakeRange(0, packModel.ISO8583HexStr.length - 16)];
            [[XLPOSManager shareInstance] calculateMacWithScoketMessage:tempStr successBlock:^(XLResponseModel *respModel) {
                NSData *requestData = [TransformNSString hexToBytes:respModel.packModel.socketAllHexStr];
                [[XLSocketHandler shareInstance] connectServerHostWithSuccessBlock:^(XLResponseModel *respModel) {
                    [[XLSocketHandler shareInstance] sendMessageWithData:requestData];
                } failedBlock:^(XLResponseModel *respModel) {
                    if ([XLPayManager shareInstance].failedBlock) {
                        startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                    }
                }];
            } failedBlock:^(XLResponseModel *respModel) {
                if ([XLPayManager shareInstance].failedBlock) {
                    startCallBack([XLPayManager shareInstance].failedBlock, respModel);
                }
            }];
        }else{
            if ([XLPayManager shareInstance].failedBlock) {
                startCallBack([XLPayManager shareInstance].failedBlock, respModel);
            }
        }
    }];
}
@end
